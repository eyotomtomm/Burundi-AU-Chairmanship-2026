"""
Management command to send a weekly analytics digest email to all staff/superusers.

Queries key metrics from the database and sends a formatted HTML email
summarizing the past week's activity.

Run weekly via cron (e.g., every Monday at 8 AM):
  0 8 * * 1 cd /path/to/backend && python manage.py send_weekly_report

Or run manually:
  python manage.py send_weekly_report
  python manage.py send_weekly_report --dry-run       # preview without sending
  python manage.py send_weekly_report --to admin@example.com  # override recipients
"""
import logging
from datetime import timedelta

from django.conf import settings
from django.core.mail import send_mail
from django.core.management.base import BaseCommand
from django.db.models import Count, Q, Sum
from django.utils import timezone

logger = logging.getLogger(__name__)


class Command(BaseCommand):
    help = 'Send weekly analytics digest email to all staff and superuser accounts'

    def add_arguments(self, parser):
        parser.add_argument(
            '--dry-run',
            action='store_true',
            help='Print the report to stdout instead of sending email',
        )
        parser.add_argument(
            '--to',
            type=str,
            help='Override recipients with a single email address (for testing)',
        )

    def _gather_metrics(self):
        """Collect all metrics for the weekly report."""
        from core.models import (
            Article, Event, EventRegistration, EventSubmission,
            GalleryAlbum, LiveFeed, MagazineEdition, SupportTicket,
            User, UserProfile, Video,
        )

        now = timezone.now()
        week_ago = now - timedelta(days=7)
        two_weeks_ago = now - timedelta(days=14)
        month_ago = now - timedelta(days=30)

        # --- User Metrics ---
        total_users = User.objects.count()
        new_users_this_week = User.objects.filter(date_joined__gte=week_ago).count()
        new_users_prev_week = User.objects.filter(
            date_joined__gte=two_weeks_ago,
            date_joined__lt=week_ago,
        ).count()
        dau = User.objects.filter(last_login__date=now.date()).count()
        mau = User.objects.filter(last_login__gte=month_ago).count()
        active_this_week = User.objects.filter(last_login__gte=week_ago).count()

        # --- Verification ---
        verified_users = UserProfile.objects.filter(is_verified=True).count()
        new_verifications = UserProfile.objects.filter(
            is_verified=True,
            verified_at__gte=week_ago,
        ).count() if hasattr(UserProfile, 'verified_at') else 0

        # --- Content Metrics ---
        articles_published = Article.objects.filter(created_at__gte=week_ago).count()
        total_article_views = Article.objects.aggregate(s=Sum('view_count'))['s'] or 0
        total_article_likes = Article.objects.aggregate(s=Sum('like_count'))['s'] or 0
        magazines_published = MagazineEdition.objects.filter(created_at__gte=week_ago).count()
        videos_published = Video.objects.filter(created_at__gte=week_ago).count()

        # Top 5 articles by views
        top_articles = list(
            Article.objects.order_by('-view_count').values('title', 'view_count', 'like_count')[:5]
        )

        # --- Event Metrics ---
        total_events = Event.objects.count()
        upcoming_events = Event.objects.filter(event_date__gte=now).count()
        try:
            event_submissions_week = EventSubmission.objects.filter(submitted_at__gte=week_ago).count()
        except Exception:
            event_submissions_week = 0

        # --- Support Tickets ---
        try:
            open_tickets = SupportTicket.objects.filter(status='open').count()
            resolved_this_week = SupportTicket.objects.filter(
                status='resolved',
                updated_at__gte=week_ago,
            ).count()
            new_tickets_week = SupportTicket.objects.filter(created_at__gte=week_ago).count()
        except Exception:
            open_tickets = 0
            resolved_this_week = 0
            new_tickets_week = 0

        # --- Live Feeds ---
        try:
            active_feeds = LiveFeed.objects.filter(status='live').count()
        except Exception:
            active_feeds = 0

        return {
            'report_date': now.strftime('%B %d, %Y'),
            'week_start': week_ago.strftime('%B %d'),
            'week_end': now.strftime('%B %d, %Y'),
            # Users
            'total_users': total_users,
            'new_users_this_week': new_users_this_week,
            'new_users_prev_week': new_users_prev_week,
            'user_growth_change': new_users_this_week - new_users_prev_week,
            'dau': dau,
            'mau': mau,
            'active_this_week': active_this_week,
            'verified_users': verified_users,
            'new_verifications': new_verifications,
            # Content
            'articles_published': articles_published,
            'total_article_views': total_article_views,
            'total_article_likes': total_article_likes,
            'magazines_published': magazines_published,
            'videos_published': videos_published,
            'top_articles': top_articles,
            # Events
            'total_events': total_events,
            'upcoming_events': upcoming_events,
            'event_submissions_week': event_submissions_week,
            # Support
            'open_tickets': open_tickets,
            'resolved_this_week': resolved_this_week,
            'new_tickets_week': new_tickets_week,
            # Live
            'active_feeds': active_feeds,
        }

    def _build_html(self, m):
        """Build HTML email body from metrics dict."""
        growth_arrow = '&#9650;' if m['user_growth_change'] >= 0 else '&#9660;'
        growth_color = '#16a34a' if m['user_growth_change'] >= 0 else '#dc2626'

        # Top articles rows
        top_articles_rows = ''
        for i, art in enumerate(m['top_articles'], 1):
            top_articles_rows += (
                f'<tr><td style="padding:6px 12px;border-bottom:1px solid #f1f5f9;">{i}</td>'
                f'<td style="padding:6px 12px;border-bottom:1px solid #f1f5f9;">{art["title"][:60]}</td>'
                f'<td style="padding:6px 12px;border-bottom:1px solid #f1f5f9;text-align:right;">{art["view_count"]}</td>'
                f'<td style="padding:6px 12px;border-bottom:1px solid #f1f5f9;text-align:right;">{art["like_count"]}</td></tr>'
            )
        if not top_articles_rows:
            top_articles_rows = '<tr><td colspan="4" style="padding:12px;text-align:center;color:#94a3b8;">No articles yet</td></tr>'

        html = f"""
<!DOCTYPE html>
<html>
<head><meta charset="UTF-8"></head>
<body style="margin:0;padding:0;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;background-color:#f8fafc;">
  <div style="max-width:640px;margin:0 auto;padding:32px 16px;">
    <!-- Header -->
    <div style="background:linear-gradient(135deg,#1a1a1a 0%,#745B17 100%);border-radius:16px;padding:32px;margin-bottom:24px;">
      <h1 style="color:#ffffff;margin:0 0 8px 0;font-size:24px;">Weekly Analytics Digest</h1>
      <p style="color:#e5c374;margin:0;font-size:14px;">{m['week_start']} &mdash; {m['week_end']}</p>
      <p style="color:rgba(255,255,255,0.7);margin:8px 0 0 0;font-size:12px;">Be 4 Africa App</p>
    </div>

    <!-- KPI Cards -->
    <table style="width:100%;border-collapse:collapse;margin-bottom:24px;">
      <tr>
        <td style="width:25%;padding:8px;">
          <div style="background:#ffffff;border-radius:12px;padding:16px;text-align:center;box-shadow:0 1px 3px rgba(0,0,0,0.08);">
            <p style="margin:0;font-size:11px;color:#64748b;text-transform:uppercase;letter-spacing:1px;">Total Users</p>
            <p style="margin:8px 0 0 0;font-size:28px;font-weight:800;color:#1a1a1a;">{m['total_users']}</p>
          </div>
        </td>
        <td style="width:25%;padding:8px;">
          <div style="background:#ffffff;border-radius:12px;padding:16px;text-align:center;box-shadow:0 1px 3px rgba(0,0,0,0.08);">
            <p style="margin:0;font-size:11px;color:#64748b;text-transform:uppercase;letter-spacing:1px;">New This Week</p>
            <p style="margin:8px 0 0 0;font-size:28px;font-weight:800;color:#1a1a1a;">{m['new_users_this_week']}</p>
            <p style="margin:4px 0 0 0;font-size:11px;color:{growth_color};">{growth_arrow} {abs(m['user_growth_change'])} vs last week</p>
          </div>
        </td>
        <td style="width:25%;padding:8px;">
          <div style="background:#ffffff;border-radius:12px;padding:16px;text-align:center;box-shadow:0 1px 3px rgba(0,0,0,0.08);">
            <p style="margin:0;font-size:11px;color:#64748b;text-transform:uppercase;letter-spacing:1px;">DAU</p>
            <p style="margin:8px 0 0 0;font-size:28px;font-weight:800;color:#1a1a1a;">{m['dau']}</p>
          </div>
        </td>
        <td style="width:25%;padding:8px;">
          <div style="background:#ffffff;border-radius:12px;padding:16px;text-align:center;box-shadow:0 1px 3px rgba(0,0,0,0.08);">
            <p style="margin:0;font-size:11px;color:#64748b;text-transform:uppercase;letter-spacing:1px;">MAU</p>
            <p style="margin:8px 0 0 0;font-size:28px;font-weight:800;color:#1a1a1a;">{m['mau']}</p>
          </div>
        </td>
      </tr>
    </table>

    <!-- User Engagement -->
    <div style="background:#ffffff;border-radius:12px;padding:24px;margin-bottom:24px;box-shadow:0 1px 3px rgba(0,0,0,0.08);">
      <h2 style="margin:0 0 16px 0;font-size:16px;color:#1a1a1a;">User Engagement</h2>
      <table style="width:100%;border-collapse:collapse;">
        <tr style="border-bottom:1px solid #f1f5f9;">
          <td style="padding:10px 0;color:#64748b;font-size:13px;">Active users this week</td>
          <td style="padding:10px 0;text-align:right;font-weight:700;font-size:14px;">{m['active_this_week']}</td>
        </tr>
        <tr style="border-bottom:1px solid #f1f5f9;">
          <td style="padding:10px 0;color:#64748b;font-size:13px;">Verified users (total)</td>
          <td style="padding:10px 0;text-align:right;font-weight:700;font-size:14px;">{m['verified_users']}</td>
        </tr>
        <tr>
          <td style="padding:10px 0;color:#64748b;font-size:13px;">New verifications this week</td>
          <td style="padding:10px 0;text-align:right;font-weight:700;font-size:14px;">{m['new_verifications']}</td>
        </tr>
      </table>
    </div>

    <!-- Content Performance -->
    <div style="background:#ffffff;border-radius:12px;padding:24px;margin-bottom:24px;box-shadow:0 1px 3px rgba(0,0,0,0.08);">
      <h2 style="margin:0 0 16px 0;font-size:16px;color:#1a1a1a;">Content Performance</h2>
      <table style="width:100%;border-collapse:collapse;margin-bottom:16px;">
        <tr style="border-bottom:1px solid #f1f5f9;">
          <td style="padding:10px 0;color:#64748b;font-size:13px;">Articles published this week</td>
          <td style="padding:10px 0;text-align:right;font-weight:700;font-size:14px;">{m['articles_published']}</td>
        </tr>
        <tr style="border-bottom:1px solid #f1f5f9;">
          <td style="padding:10px 0;color:#64748b;font-size:13px;">Magazines published this week</td>
          <td style="padding:10px 0;text-align:right;font-weight:700;font-size:14px;">{m['magazines_published']}</td>
        </tr>
        <tr style="border-bottom:1px solid #f1f5f9;">
          <td style="padding:10px 0;color:#64748b;font-size:13px;">Videos published this week</td>
          <td style="padding:10px 0;text-align:right;font-weight:700;font-size:14px;">{m['videos_published']}</td>
        </tr>
        <tr style="border-bottom:1px solid #f1f5f9;">
          <td style="padding:10px 0;color:#64748b;font-size:13px;">Total article views (all time)</td>
          <td style="padding:10px 0;text-align:right;font-weight:700;font-size:14px;">{m['total_article_views']}</td>
        </tr>
        <tr>
          <td style="padding:10px 0;color:#64748b;font-size:13px;">Total article likes (all time)</td>
          <td style="padding:10px 0;text-align:right;font-weight:700;font-size:14px;">{m['total_article_likes']}</td>
        </tr>
      </table>

      <h3 style="margin:0 0 12px 0;font-size:14px;color:#475569;">Top 5 Articles (by views)</h3>
      <table style="width:100%;border-collapse:collapse;font-size:13px;">
        <tr style="background:#f8fafc;">
          <th style="padding:8px 12px;text-align:left;font-weight:600;color:#64748b;">#</th>
          <th style="padding:8px 12px;text-align:left;font-weight:600;color:#64748b;">Title</th>
          <th style="padding:8px 12px;text-align:right;font-weight:600;color:#64748b;">Views</th>
          <th style="padding:8px 12px;text-align:right;font-weight:600;color:#64748b;">Likes</th>
        </tr>
        {top_articles_rows}
      </table>
    </div>

    <!-- Events & Support -->
    <table style="width:100%;border-collapse:collapse;margin-bottom:24px;">
      <tr>
        <td style="width:50%;padding-right:12px;vertical-align:top;">
          <div style="background:#ffffff;border-radius:12px;padding:24px;box-shadow:0 1px 3px rgba(0,0,0,0.08);">
            <h2 style="margin:0 0 16px 0;font-size:16px;color:#1a1a1a;">Events</h2>
            <table style="width:100%;border-collapse:collapse;">
              <tr style="border-bottom:1px solid #f1f5f9;">
                <td style="padding:8px 0;color:#64748b;font-size:13px;">Total events</td>
                <td style="padding:8px 0;text-align:right;font-weight:700;">{m['total_events']}</td>
              </tr>
              <tr style="border-bottom:1px solid #f1f5f9;">
                <td style="padding:8px 0;color:#64748b;font-size:13px;">Upcoming</td>
                <td style="padding:8px 0;text-align:right;font-weight:700;">{m['upcoming_events']}</td>
              </tr>
              <tr>
                <td style="padding:8px 0;color:#64748b;font-size:13px;">Submissions this week</td>
                <td style="padding:8px 0;text-align:right;font-weight:700;">{m['event_submissions_week']}</td>
              </tr>
            </table>
          </div>
        </td>
        <td style="width:50%;padding-left:12px;vertical-align:top;">
          <div style="background:#ffffff;border-radius:12px;padding:24px;box-shadow:0 1px 3px rgba(0,0,0,0.08);">
            <h2 style="margin:0 0 16px 0;font-size:16px;color:#1a1a1a;">Support</h2>
            <table style="width:100%;border-collapse:collapse;">
              <tr style="border-bottom:1px solid #f1f5f9;">
                <td style="padding:8px 0;color:#64748b;font-size:13px;">Open tickets</td>
                <td style="padding:8px 0;text-align:right;font-weight:700;color:#f59e0b;">{m['open_tickets']}</td>
              </tr>
              <tr style="border-bottom:1px solid #f1f5f9;">
                <td style="padding:8px 0;color:#64748b;font-size:13px;">New this week</td>
                <td style="padding:8px 0;text-align:right;font-weight:700;">{m['new_tickets_week']}</td>
              </tr>
              <tr>
                <td style="padding:8px 0;color:#64748b;font-size:13px;">Resolved this week</td>
                <td style="padding:8px 0;text-align:right;font-weight:700;color:#16a34a;">{m['resolved_this_week']}</td>
              </tr>
            </table>
          </div>
        </td>
      </tr>
    </table>

    <!-- Footer -->
    <div style="text-align:center;padding:16px;color:#94a3b8;font-size:11px;">
      <p style="margin:0;">This is an automated report from the Be 4 Africa Admin Portal.</p>
      <p style="margin:4px 0 0 0;">Generated on {m['report_date']}. To unsubscribe, remove your staff status in the admin panel.</p>
    </div>
  </div>
</body>
</html>
"""
        return html

    def _build_plain_text(self, m):
        """Build plain text fallback for the email."""
        lines = [
            f"WEEKLY ANALYTICS DIGEST",
            f"{m['week_start']} - {m['week_end']}",
            f"Be 4 Africa App",
            f"",
            f"=== KEY METRICS ===",
            f"Total Users:        {m['total_users']}",
            f"New This Week:      {m['new_users_this_week']} ({'+' if m['user_growth_change'] >= 0 else ''}{m['user_growth_change']} vs last week)",
            f"DAU (today):        {m['dau']}",
            f"MAU (30 days):      {m['mau']}",
            f"Active This Week:   {m['active_this_week']}",
            f"",
            f"=== CONTENT ===",
            f"Articles Published: {m['articles_published']}",
            f"Magazines Published:{m['magazines_published']}",
            f"Videos Published:   {m['videos_published']}",
            f"Total Article Views:{m['total_article_views']}",
            f"Total Article Likes:{m['total_article_likes']}",
            f"",
            f"=== EVENTS ===",
            f"Total Events:       {m['total_events']}",
            f"Upcoming:           {m['upcoming_events']}",
            f"Submissions (week): {m['event_submissions_week']}",
            f"",
            f"=== SUPPORT ===",
            f"Open Tickets:       {m['open_tickets']}",
            f"New This Week:      {m['new_tickets_week']}",
            f"Resolved This Week: {m['resolved_this_week']}",
            f"",
            f"---",
            f"This is an automated report from the Be 4 Africa Admin Portal.",
        ]
        return '\n'.join(lines)

    def handle(self, *args, **options):
        from core.models import User

        dry_run = options['dry_run']
        override_to = options.get('to')

        # Gather metrics
        self.stdout.write('Gathering analytics metrics...')
        metrics = self._gather_metrics()

        # Build email content
        html_body = self._build_html(metrics)
        text_body = self._build_plain_text(metrics)

        # Determine recipients
        if override_to:
            recipients = [override_to]
        else:
            recipients = list(
                User.objects.filter(Q(is_staff=True) | Q(is_superuser=True))
                .exclude(email='')
                .values_list('email', flat=True)
            )

        if not recipients:
            self.stdout.write(self.style.WARNING(
                'No staff/superuser email addresses found. No report sent.'
            ))
            return

        subject = f"Weekly Analytics Digest - {metrics['week_end']}"

        if dry_run:
            self.stdout.write(self.style.WARNING('=== DRY RUN (not sending email) ==='))
            self.stdout.write(f'Subject: {subject}')
            self.stdout.write(f'Recipients: {", ".join(recipients)}')
            self.stdout.write('')
            self.stdout.write(text_body)
            return

        # Send email
        from_email = getattr(settings, 'DEFAULT_FROM_EMAIL', 'noreply@burundi4africa.com')

        try:
            from django.core.mail import EmailMultiAlternatives

            email = EmailMultiAlternatives(
                subject=subject,
                body=text_body,
                from_email=from_email,
                to=recipients,
            )
            email.attach_alternative(html_body, 'text/html')
            email.send(fail_silently=False)

            self.stdout.write(self.style.SUCCESS(
                f'Weekly report sent successfully to {len(recipients)} recipient(s): {", ".join(recipients)}'
            ))
            logger.info(
                'Weekly analytics report sent to %d recipients: %s',
                len(recipients), ', '.join(recipients),
            )
        except Exception as e:
            self.stdout.write(self.style.ERROR(f'Failed to send weekly report: {e}'))
            logger.error('Failed to send weekly analytics report: %s', e)
