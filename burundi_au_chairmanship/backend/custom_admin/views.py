import csv
import functools
import io
import json
import logging
import os
import re
import time
import urllib.parse
import urllib.request
from django.shortcuts import render, redirect, get_object_or_404
from django.conf import settings
from django.contrib.auth import authenticate, login, logout
from django.contrib.auth.decorators import login_required, user_passes_test
from django.contrib.auth.models import User as AuthUser
from django.contrib import messages
from django.db.models import Count, Q, Sum
from django.http import JsonResponse, HttpResponse
from axes.exceptions import AxesBackendRequestParameterRequired
from django.views.decorators.http import require_POST
from django.views.decorators.csrf import csrf_exempt
from django.core.paginator import Paginator
from django.utils import timezone
from django.core.exceptions import ValidationError
from django.core.files.storage import default_storage
from django.core.files.base import ContentFile

logger = logging.getLogger(__name__)


def _sanitize_csv_value(value):
    """Neutralize CSV formula injection.

    Any cell whose string representation starts with a formula-trigger
    character (= + - @ TAB CR LF) is prefixed with an apostrophe so
    spreadsheet applications treat it as a literal text value.
    """
    if isinstance(value, str) and value and value[0] in ('=', '+', '-', '@', '\t', '\r', '\n'):
        return "'" + value
    return value


def _sanitize_csv_row(row):
    """Apply formula-injection sanitization to every cell in a CSV row."""
    return [_sanitize_csv_value(v) for v in row]


from core.utils import log_admin_action, compute_model_diff
from core.models import (
    HeroSlide, FeatureCard, Article, MagazineEdition, Event,
    LiveFeed, Video, GalleryAlbum, GalleryPhoto, EmbassyLocation, Resource,
    Notification, Category, PriorityAgenda, SocialMediaLink,
    QuickAccessMenuItem, HeroTextContent, WeatherCity,
    EventCategory, EventRegistration, EventSubmission, RegistrationFormField, AppSettings, User,
    UserProfile, VerificationRequest,
    FeatureCardKeyPoint, FeatureCardImpactArea, FeatureCardMedia,
    AuditLogEntry, SupportTicket, TicketMessage,
    # New models
    Poll, PollOption, Discussion, ContactDirectory, AnnouncementBanner,
    EmailTemplate, EventSpeaker, OnboardingStep, Webhook, WebhookLog,
    ScheduledMaintenance, PromotionalSplash, LoginHistory, Bookmark, Reaction,
    TranslationEntry, RateLimitLog,
    AdminActivityLog, DatabaseBackup,
    UserSegment, UserSegmentMembership,
    AdminNotification,
    ABTest, ABTestParticipant,
    TranslationRequest, VideoChapter,
    ArticleComment, EventComment, MagazineComment, LiveFeedComment,
    VideoComment, GalleryComment, DiscussionReply,
    DeviceToken,
    AppRelease, AppReleaseHighlight,
    ArticleLike,
    NewsletterEdition,
    YouthDialogueEvent,
    YouthDialogueFormField,
    YouthDialogueApplication,
    YouthDialogueDocument,
    YouthDialogueActivityLog,
    YouthDialogueRole,
    YouthDialogueMedia,
    EventPhoto,
    DeviceBan,
)

# Email-related views live in custom_admin/email_views.py. Re-exported here so
# existing urls.py references like `views.email_campaigns_list` keep resolving.
from .email_views import (  # noqa: F401
    email_templates_list,
    email_template_edit,
    email_template_preview,
    email_template_send_test,
    email_campaigns_list,
    email_campaign_create,
    email_campaign_edit,
    email_campaign_send,
    email_campaign_send_confirm,
    email_campaign_delete,
    email_logs_list,
    email_inbox,
)


def is_staff(user):
    return user.is_staff or user.is_superuser


def _get_existing_or_uploaded(request, field_name):
    """Return uploaded file, or existing Spaces path, or None.

    Checks for an uploaded file first (request.FILES), then falls back to
    an ``existing_image_<field_name>`` POST value which is a relative path
    inside the storage backend (e.g. ``articles/IMG_1646.jpeg``).
    """
    uploaded = request.FILES.get(field_name)
    if uploaded:
        return uploaded
    existing_path = (request.POST.get(f'existing_image_{field_name}') or '').strip()
    if existing_path:
        return existing_path  # raw string path — assigned directly to the ImageField
    return None


def _extract_youtube_id(url):
    """Extract the video ID from a YouTube URL, or return None."""
    patterns = [
        r'(?:youtube\.com/watch\?.*v=|youtu\.be/|youtube\.com/embed/|youtube\.com/shorts/)([a-zA-Z0-9_-]{11})',
    ]
    for pat in patterns:
        m = re.search(pat, url or '')
        if m:
            return m.group(1)
    return None


def _fetch_youtube_thumbnail(video_url):
    """Download YouTube thumbnail and return a ContentFile, or None on failure."""
    yt_id = _extract_youtube_id(video_url)
    if not yt_id:
        return None
    # Try high-res first, fall back to default
    for quality in ('maxresdefault', 'hqdefault'):
        thumb_url = f'https://img.youtube.com/vi/{yt_id}/{quality}.jpg'
        try:
            req = urllib.request.Request(thumb_url, headers={'User-Agent': 'Mozilla/5.0'})
            resp = urllib.request.urlopen(req, timeout=10)
            if resp.status == 200:
                data = resp.read()
                # maxresdefault returns a tiny placeholder when unavailable
                if len(data) > 5000:
                    return ContentFile(data, name=f'yt_{yt_id}.jpg')
        except Exception:
            continue
    return None


def _catch_upload_errors(view_func):
    """Decorator: catch file-upload / S3 errors on POST and show a message instead of 500."""
    @functools.wraps(view_func)
    def wrapper(request, *args, **kwargs):
        try:
            return view_func(request, *args, **kwargs)
        except Exception as exc:
            if request.method != 'POST':
                raise
            err = str(exc)
            if 'InvalidAccessKeyId' in err or 'credential' in err.lower() or 'AccessDenied' in err:
                messages.error(
                    request,
                    'File upload failed — storage credentials are invalid or expired. '
                    'Please contact the administrator to update the DigitalOcean Spaces API keys.'
                )
            else:
                logger.exception('Error in %s', view_func.__name__)
                messages.error(request, f'Failed to save: {err}')
            return redirect(request.path)
    return wrapper


def admin_login(request):
    if request.user.is_authenticated and is_staff(request.user):
        return redirect('custom_admin:dashboard')

    is_locked = False
    if request.method == 'POST':
        username = request.POST.get('username')
        password = request.POST.get('password')

        try:
            user = authenticate(request, username=username, password=password)
        except AxesBackendRequestParameterRequired:
            user = None

        if user is None:
            # Check if this was a lockout (axes returns None for locked accounts)
            from axes.handlers.proxy import AxesProxyHandler
            if AxesProxyHandler.is_locked(request):
                is_locked = True
            else:
                messages.error(request, 'Invalid credentials or insufficient permissions')
        elif not is_staff(user):
            messages.error(request, 'Invalid credentials or insufficient permissions')
        else:
            # Password OK — complete login
            login(request, user, backend='django.contrib.auth.backends.ModelBackend')
            remember_me = bool(request.POST.get('remember_me'))
            request.session['_staff_session_created'] = time.time()
            if remember_me:
                request.session.set_expiry(settings.STAFF_SESSION_MAX_AGE)
            else:
                request.session.set_expiry(0)
            request.session.save()
            log_admin_action(request, 'login', 'Auth', object_repr=user.username)
            if hasattr(user, 'profile') and user.profile.force_password_change:
                return redirect('custom_admin:force_password_change')
            return redirect('custom_admin:dashboard')

    return render(request, 'custom_admin/login.html', {'is_locked': is_locked})


def axes_lockout_response(request, credentials, *args, **kwargs):
    """Custom lockout response for django-axes — renders the login page with a lockout warning."""
    return render(request, 'custom_admin/login.html', {'is_locked': True}, status=403)




@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def force_password_change(request):
    """Force a user to set a new password before accessing the admin panel."""
    if request.method == 'POST':
        new_password = request.POST.get('new_password', '')
        confirm_password = request.POST.get('confirm_password', '')
        if not new_password or len(new_password) < 10:
            messages.error(request, 'Password must be at least 10 characters.')
        elif new_password != confirm_password:
            messages.error(request, 'Passwords do not match.')
        elif request.user.check_password(new_password):
            messages.error(request, 'New password must be different from the temporary password.')
        else:
            request.user.set_password(new_password)
            request.user.save()
            request.user.profile.force_password_change = False
            request.user.profile.save(update_fields=['force_password_change'])
            # Re-authenticate so the session stays valid after password change
            from django.contrib.auth import update_session_auth_hash
            update_session_auth_hash(request, request.user)
            log_admin_action(request, 'password_change', 'Auth', object_repr=request.user.username)
            messages.success(request, 'Password changed successfully.')
            return redirect('custom_admin:dashboard')
    return render(request, 'custom_admin/force_password_change.html')


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def admin_logout(request):
    log_admin_action(request, 'logout', 'Auth', object_repr=request.user.username)
    logout(request)
    return redirect('custom_admin:login')


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def dashboard(request):
    import json
    from datetime import timedelta
    # Exclude staff/admin accounts — "App Users" should reflect real end users only
    users_count = User.objects.filter(is_staff=False).count()
    # Only count articles that are actually published (not drafts/archived)
    articles_count = Article.objects.filter(status='published').count()
    events_count = Event.objects.count()
    magazines_count = MagazineEdition.objects.count()
    hero_slides_count = HeroSlide.objects.filter(is_active=True).count()
    live_feeds_active = LiveFeed.objects.filter(status='live').count()
    total_content = articles_count + events_count + magazines_count + hero_slides_count
    # Use UserProfile.last_active (bumped by LastActiveMiddleware on every
    # authenticated API request, throttled to 60s) instead of last_login,
    # which only fires on credential re-entry and misses JWT refresh-token sessions.
    active_today = UserProfile.objects.filter(
        last_active__gte=timezone.now() - timedelta(days=1),
        user__is_staff=False,
    ).count()

    # Account alerts
    deletion_scheduled = UserProfile.objects.filter(
        is_scheduled_for_deletion=True
    ).select_related('user').order_by('-deletion_requested_at')
    deactivated_users = UserProfile.objects.filter(
        is_deactivated=True, is_scheduled_for_deletion=False
    ).select_related('user').order_by('-deactivated_at')

    # "Users online now" — presence signal updated by:
    #   * LastActiveMiddleware on every authenticated API hit (throttled 60s)
    #   * The /api/heartbeat/ endpoint every 60s from foregrounded Flutter apps
    # We union authenticated active profiles with anonymous device tokens
    # (refreshed by heartbeat via X-FCM-Token header) and deduplicate so a
    # single physical device can't inflate the count.
    from datetime import timedelta as td
    from core.models import DeviceToken
    live_window = timezone.now() - td(minutes=5)
    authed_user_ids = set(
        UserProfile.objects.filter(last_active__gte=live_window)
        .values_list('user_id', flat=True)
    )
    # Anonymous devices: tokens with no linked user, recently bumped.
    anon_device_count = DeviceToken.objects.filter(
        user__isnull=True,
        is_active=True,
        updated_at__gte=live_window,
    ).values('token').distinct().count()
    live_users = len(authed_user_ids) + anon_device_count

    # --- User growth + Event activity (last 30 days) ---
    now = timezone.now()
    growth_labels = []
    growth_data = []
    events_30d_data = []
    for i in range(29, -1, -1):
        day = (now - timedelta(days=i)).date()
        growth_labels.append(day.strftime('%b %d'))
        growth_data.append(
            User.objects.filter(date_joined__date=day, is_staff=False).count()
        )
        events_30d_data.append(
            Event.objects.filter(created_at__date=day).count()
        )

    # --- User growth trend: last 30 days vs previous 30 days ---
    growth_last_30 = sum(growth_data)
    growth_prev_30 = User.objects.filter(
        date_joined__gte=now - timedelta(days=60),
        date_joined__lt=now - timedelta(days=30),
        is_staff=False,
    ).count()
    if growth_prev_30 > 0:
        growth_trend_pct = round(
            ((growth_last_30 - growth_prev_30) / growth_prev_30) * 100
        )
    elif growth_last_30 > 0:
        # Previous window had 0 sign-ups but this one has some → brand-new growth
        growth_trend_pct = None  # render as "New" instead of a percentage
    else:
        growth_trend_pct = 0
    # direction: 'up' (>0), 'down' (<0), 'flat' (=0), 'new' (None)
    if growth_trend_pct is None:
        growth_trend_direction = 'new'
    elif growth_trend_pct > 0:
        growth_trend_direction = 'up'
    elif growth_trend_pct < 0:
        growth_trend_direction = 'down'
    else:
        growth_trend_direction = 'flat'

    # --- Content engagement (views + likes across all content types) ---
    article_views = Article.objects.aggregate(s=Sum('view_count'))['s'] or 0
    article_likes = Article.objects.aggregate(s=Sum('like_count'))['s'] or 0
    magazine_views = MagazineEdition.objects.aggregate(s=Sum('view_count'))['s'] or 0
    magazine_likes = MagazineEdition.objects.aggregate(s=Sum('like_count'))['s'] or 0
    gallery_views = GalleryAlbum.objects.aggregate(s=Sum('view_count'))['s'] or 0
    gallery_likes = GalleryAlbum.objects.aggregate(s=Sum('like_count'))['s'] or 0
    video_views = Video.objects.aggregate(s=Sum('view_count'))['s'] or 0
    video_likes = Video.objects.aggregate(s=Sum('like_count'))['s'] or 0
    video_count = Video.objects.count()

    engagement_labels = ['Articles', 'Magazines', 'Gallery', 'Videos']
    engagement_views = [article_views, magazine_views, gallery_views, video_views]
    engagement_likes = [article_likes, magazine_likes, gallery_likes, video_likes]

    # --- Top countries ---
    nationality_data = list(
        UserProfile.objects.exclude(nationality='')
        .values('nationality')
        .annotate(count=Count('id'))
        .order_by('-count')[:8]
    )
    country_labels = [d['nationality'] for d in nationality_data]
    country_counts = [d['count'] for d in nationality_data]

    # --- Verification status ---
    verified_count = UserProfile.objects.filter(is_verified=True).count()
    pending_verif = VerificationRequest.objects.filter(status='pending').count()
    unverified_count = users_count - verified_count

    # --- Language distribution (real app users only) ---
    lang_agg = (
        UserProfile.objects
        .filter(user__is_staff=False, user__is_active=True)
        .values('preferred_language')
        .annotate(count=Count('id'))
    )
    lang_map = {row['preferred_language']: row['count'] for row in lang_agg}
    language_en = lang_map.get('en', 0)
    language_fr = lang_map.get('fr', 0)
    language_total = language_en + language_fr

    # --- Push notification engagement (last 30 days) ---
    # We blend two data sources so the widget is useful immediately, even
    # before client-side event tracking rolls out to devices:
    #
    #   1. Legacy counters (push_recipient_count / opened_count) — already
    #      populated on every historical send via the Notification row itself.
    #      These are raw send/tap counts (not unique users).
    #   2. NotificationEvent rows — precise per-user events recorded by the
    #      new Flutter client. Gives us unique-user CTR once data accrues.
    #
    # The widget reports the maximum of (events, legacy) for each metric so
    # neither pipeline hides historical data from the other.
    from core.models import NotificationEvent
    notif_30d = Notification.objects.filter(
        push_sent=True,
        push_sent_at__gte=now - timedelta(days=30),
    )
    notif_sent_30d = notif_30d.aggregate(s=Sum('push_recipient_count'))['s'] or 0
    # Legacy per-notification open counter sum (raw taps, not unique users)
    legacy_opened_30d = notif_30d.aggregate(s=Sum('opened_count'))['s'] or 0

    event_delivered_30d = NotificationEvent.objects.filter(
        notification__in=notif_30d, event_type='delivered',
    ).count()
    event_opened_30d = NotificationEvent.objects.filter(
        notification__in=notif_30d, event_type='opened',
    ).values('user').distinct().count()

    # "Delivered" falls back to sent when no client telemetry exists yet.
    # Once client events start flowing they take precedence.
    notif_delivered_30d = event_delivered_30d or notif_sent_30d
    # "Opened" uses whichever source knows more — unique events or raw taps.
    notif_opened_30d = max(event_opened_30d, legacy_opened_30d)
    notif_ctr_30d = (
        round((notif_opened_30d / notif_delivered_30d) * 100, 1)
        if notif_delivered_30d else 0
    )
    notif_engagement_is_estimated = (
        event_delivered_30d == 0 and notif_sent_30d > 0
    )

    # Top 5 by open-rate — look at the 20 most recent sends. Per-notification
    # metrics use the same fallback rules (events first, legacy otherwise).
    def _delivered_for(n):
        d = n.delivered_count
        return d or n.push_recipient_count

    def _opened_for(n):
        return max(n.opened_users_count, n.opened_count)

    recent_sends = list(notif_30d.order_by('-push_sent_at')[:20])
    ranked = sorted(
        [
            (n.title[:24], _delivered_for(n), _opened_for(n))
            for n in recent_sends
        ],
        # sort by raw open-rate; ties and empties go to the bottom
        key=lambda t: (t[2] / t[1] if t[1] else 0, t[2]),
        reverse=True,
    )[:5]
    top_notif_labels = json.dumps([t[0] for t in ranked])
    top_notif_delivered = json.dumps([t[1] for t in ranked])
    top_notif_opened = json.dumps([t[2] for t in ranked])
    has_notif_engagement_data = bool(recent_sends)

    stats = {
        'users': users_count,
        'articles': articles_count,
        'events': events_count,
        'magazines': magazines_count,
        'hero_slides': hero_slides_count,
        'feature_cards': FeatureCard.objects.filter(is_active=True).count(),
        'live_feeds_active': live_feeds_active,
        'active_today': active_today,
        'total_content': total_content or 1,
        'recent_articles': Article.objects.order_by('-created_at')[:5],
        'recent_events': Event.objects.order_by('-event_date')[:5],
        'deletion_scheduled': deletion_scheduled,
        'deactivated_users': deactivated_users,
        'live_users': live_users,
        # Chart data (JSON-serialized)
        'growth_labels_json': json.dumps(growth_labels),
        'growth_data_json': json.dumps(growth_data),
        'events_30d_data_json': json.dumps(events_30d_data),
        'growth_trend_pct': growth_trend_pct,
        'growth_trend_direction': growth_trend_direction,
        'growth_last_30': growth_last_30,
        'growth_prev_30': growth_prev_30,
        'article_views': article_views,
        'article_likes': article_likes,
        'magazine_views': magazine_views,
        'magazine_likes': magazine_likes,
        'gallery_views': gallery_views,
        'gallery_likes': gallery_likes,
        'video_views': video_views,
        'video_likes': video_likes,
        'video_count': video_count,
        'engagement_labels_json': json.dumps(engagement_labels),
        'engagement_views_json': json.dumps(engagement_views),
        'engagement_likes_json': json.dumps(engagement_likes),
        'country_labels_json': json.dumps(country_labels),
        'country_counts_json': json.dumps(country_counts),
        'verified_count': verified_count,
        'pending_verif': pending_verif,
        'unverified_count': unverified_count,
        # Language distribution
        'language_en': language_en,
        'language_fr': language_fr,
        'language_total': language_total,
        # Notification engagement
        'notif_sent_30d': notif_sent_30d,
        'notif_delivered_30d': notif_delivered_30d,
        'notif_opened_30d': notif_opened_30d,
        'notif_ctr_30d': notif_ctr_30d,
        'notif_engagement_is_estimated': notif_engagement_is_estimated,
        'has_notif_engagement_data': has_notif_engagement_data,
        'top_notif_labels_json': top_notif_labels,
        'top_notif_delivered_json': top_notif_delivered,
        'top_notif_opened_json': top_notif_opened,
    }
    return render(request, 'custom_admin/dashboard.html', stats)


# ═══════════════════════════════════════════════════════════════
#  HERO SLIDES
# ═══════════════════════════════════════════════════════════════

@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def hero_slides_list(request):
    slides = HeroSlide.objects.all().order_by('order')
    return render(request, 'custom_admin/hero_slides/list.html', {'slides': slides})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def hero_slide_create(request):
    if request.method == 'POST':
        try:
            slide = HeroSlide(
                label=request.POST.get('label'),
                label_fr=request.POST.get('label_fr', ''),
                image=_get_existing_or_uploaded(request, 'image'),
                order=request.POST.get('order', 0),
                is_active=request.POST.get('is_active') == 'on'
            )
            slide.full_clean()
            slide.save()
            messages.success(request, 'Hero slide created successfully!')
            return redirect('custom_admin:hero_slides_list')
        except ValidationError as e:
            for field, errors in e.message_dict.items():
                for error in errors:
                    messages.error(request, f'{field}: {error}')
        except Exception as e:
            logger.exception('Hero slide create failed')
            messages.error(request, f'Failed to save hero slide: {e}')
    return render(request, 'custom_admin/hero_slides/form.html', {'action': 'Create'})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def hero_slide_edit(request, pk):
    slide = get_object_or_404(HeroSlide, pk=pk)
    if request.method == 'POST':
        try:
            slide.label = request.POST.get('label')
            slide.label_fr = request.POST.get('label_fr', '')
            _img = _get_existing_or_uploaded(request, 'image')
            if _img:
                slide.image = _img
            slide.order = request.POST.get('order', 0)
            slide.is_active = request.POST.get('is_active') == 'on'
            slide.full_clean()
            slide.save()
            messages.success(request, 'Hero slide updated successfully!')
            return redirect('custom_admin:hero_slides_list')
        except ValidationError as e:
            for field, errors in e.message_dict.items():
                for error in errors:
                    messages.error(request, f'{field}: {error}')
        except Exception as e:
            logger.exception('Hero slide edit failed')
            messages.error(request, f'Failed to save hero slide: {e}')
    return render(request, 'custom_admin/hero_slides/form.html', {'slide': slide, 'action': 'Edit'})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@require_POST
def hero_slide_delete(request, pk):
    slide = get_object_or_404(HeroSlide, pk=pk)
    slide.delete()
    messages.success(request, 'Hero slide deleted successfully!')
    return redirect('custom_admin:hero_slides_list')


# ═══════════════════════════════════════════════════════════════
#  HERO TEXT CONTENT
# ═══════════════════════════════════════════════════════════════

@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def hero_text_list(request):
    items = HeroTextContent.objects.all().order_by('order')
    return render(request, 'custom_admin/hero_text/list.html', {'items': items})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def hero_text_create(request):
    if request.method == 'POST':
        HeroTextContent.objects.create(
            key=request.POST.get('key'),
            text_en=request.POST.get('text_en'),
            text_fr=request.POST.get('text_fr', ''),
            order=request.POST.get('order', 0),
            is_active=request.POST.get('is_active') == 'on'
        )
        messages.success(request, 'Hero text created successfully!')
        return redirect('custom_admin:hero_text_list')
    return render(request, 'custom_admin/hero_text/form.html', {'action': 'Create'})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def hero_text_edit(request, pk):
    item = get_object_or_404(HeroTextContent, pk=pk)
    if request.method == 'POST':
        item.key = request.POST.get('key')
        item.text_en = request.POST.get('text_en')
        item.text_fr = request.POST.get('text_fr', '')
        item.order = request.POST.get('order', 0)
        item.is_active = request.POST.get('is_active') == 'on'
        item.save()
        messages.success(request, 'Hero text updated successfully!')
        return redirect('custom_admin:hero_text_list')
    return render(request, 'custom_admin/hero_text/form.html', {'item': item, 'action': 'Edit'})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@require_POST
def hero_text_delete(request, pk):
    item = get_object_or_404(HeroTextContent, pk=pk)
    item.delete()
    messages.success(request, 'Hero text deleted successfully!')
    return redirect('custom_admin:hero_text_list')


# ═══════════════════════════════════════════════════════════════
#  ARTICLES
# ═══════════════════════════════════════════════════════════════

@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def articles_list(request):
    articles = Article.objects.all().select_related('category').order_by('-created_at')
    search = request.GET.get('search')
    if search:
        articles = articles.filter(
            Q(title__icontains=search) | Q(title_fr__icontains=search) | Q(content__icontains=search)
        )
    content_type_filter = request.GET.get('content_type')
    if content_type_filter in ('article', 'news'):
        articles = articles.filter(content_type=content_type_filter)
    paginator = Paginator(articles, 20)
    page = request.GET.get('page')
    articles = paginator.get_page(page)
    return render(request, 'custom_admin/articles/list.html', {'articles': articles})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@_catch_upload_errors
def article_create(request):
    categories = Category.objects.all()
    if request.method == 'POST':
        is_draft = request.POST.get('save_as_draft') == 'on'
        content_status = request.POST.get('content_status', 'published')
        # Handle legacy "Save as Draft" button
        if is_draft:
            content_status = 'draft'
        scheduled_publish_at = request.POST.get('scheduled_publish_at') or None
        scheduled_publish_date = request.POST.get('scheduled_publish_date') or None
        expires_at = request.POST.get('expires_at') or None
        article = Article.objects.create(
            title=request.POST.get('title'),
            title_fr=request.POST.get('title_fr', ''),
            content=request.POST.get('content'),
            content_fr=request.POST.get('content_fr', ''),
            category_id=request.POST.get('category') if request.POST.get('category') else None,
            image=_get_existing_or_uploaded(request, 'image'),
            author=request.POST.get('author', 'Admin'),
            publish_date=request.POST.get('publish_date') or timezone.now(),
            content_type=request.POST.get('content_type', 'article'),
            is_featured=request.POST.get('is_featured') == 'on',
            is_draft=is_draft,
            status=content_status,
            scheduled_publish_at=scheduled_publish_at,
            scheduled_publish_date=scheduled_publish_date,
            expires_at=expires_at,
        )
        log_admin_action(request, 'create', 'Article', object_id=article.pk, object_repr=article.title)
        if content_status == 'draft':
            messages.success(request, 'Article saved as draft!')
        elif content_status == 'scheduled':
            messages.success(request, 'Article scheduled for publication!')
        else:
            messages.success(request, 'Article created successfully!')
        return redirect('custom_admin:articles_list')
    return render(request, 'custom_admin/articles/form.html', {
        'categories': categories, 'action': 'Create',
        'prefill_date': request.GET.get('date', ''),
    })


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@_catch_upload_errors
def article_edit(request, pk):
    article = get_object_or_404(Article, pk=pk)
    categories = Category.objects.all()
    if request.method == 'POST':
        # Auto-create a revision before saving changes (content versioning)
        from core.models import ArticleRevision
        from django.db.models import Max
        current_max = article.revisions.aggregate(
            max_num=Max('revision_number')
        )['max_num'] or 0
        ArticleRevision.objects.create(
            article=article,
            revision_number=current_max + 1,
            title=article.title,
            content=article.content,
            edited_by=request.user,
            change_summary=request.POST.get('change_summary', ''),
        )

        # Compute diff before applying changes
        new_values = {
            'title': request.POST.get('title'),
            'title_fr': request.POST.get('title_fr', ''),
            'content': request.POST.get('content'),
            'content_fr': request.POST.get('content_fr', ''),
            'author': request.POST.get('author', article.author),
            'is_featured': request.POST.get('is_featured') == 'on',
            'is_draft': request.POST.get('save_as_draft') == 'on',
        }
        changes = compute_model_diff(article, new_values)

        article.title = new_values['title']
        article.title_fr = new_values['title_fr']
        article.content = new_values['content']
        article.content_fr = new_values['content_fr']
        article.category_id = request.POST.get('category') if request.POST.get('category') else None
        article.author = new_values['author']
        _img = _get_existing_or_uploaded(request, 'image')
        if _img:
            article.image = _img
            changes['image'] = {'old': '', 'new': 'new image uploaded'}
        article.content_type = request.POST.get('content_type', article.content_type)
        article.is_featured = new_values['is_featured']
        article.is_draft = new_values['is_draft']
        content_status = request.POST.get('content_status', 'published')
        if article.is_draft:
            content_status = 'draft'
        article.status = content_status
        article.scheduled_publish_at = request.POST.get('scheduled_publish_at') or None
        article.scheduled_publish_date = request.POST.get('scheduled_publish_date') or None
        article.expires_at = request.POST.get('expires_at') or None
        article.save()
        log_admin_action(request, 'update', 'Article', object_id=article.pk, object_repr=article.title, changes=changes)
        if content_status == 'draft':
            messages.success(request, 'Article saved as draft!')
        else:
            messages.success(request, 'Article updated successfully!')
        return redirect('custom_admin:articles_list')
    return render(request, 'custom_admin/articles/form.html', {
        'article': article, 'categories': categories, 'action': 'Edit'
    })


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@require_POST
def article_delete(request, pk):
    article = get_object_or_404(Article, pk=pk)
    title = article.title
    log_admin_action(request, 'delete', 'Article', object_id=pk, object_repr=title)
    article.delete()
    messages.success(request, 'Article deleted successfully!')
    return redirect('custom_admin:articles_list')


# ═══════════════════════════════════════════════════════════════
#  CATEGORIES
# ═══════════════════════════════════════════════════════════════

@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def categories_list(request):
    categories = Category.objects.all().annotate(article_count=Count('articles'))
    return render(request, 'custom_admin/categories/list.html', {'categories': categories})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def category_create(request):
    if request.method == 'POST':
        Category.objects.create(
            name=request.POST.get('name'),
            name_fr=request.POST.get('name_fr', ''),
            color=request.POST.get('color', '#1EB53A'),
            order=request.POST.get('order', 0),
        )
        messages.success(request, 'Category created successfully!')
        return redirect('custom_admin:categories_list')
    return render(request, 'custom_admin/categories/form.html', {'action': 'Create'})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def category_edit(request, pk):
    category = get_object_or_404(Category, pk=pk)
    if request.method == 'POST':
        category.name = request.POST.get('name')
        category.name_fr = request.POST.get('name_fr', '')
        category.color = request.POST.get('color', '#1EB53A')
        category.order = request.POST.get('order', 0)
        category.save()
        messages.success(request, 'Category updated successfully!')
        return redirect('custom_admin:categories_list')
    return render(request, 'custom_admin/categories/form.html', {'category': category, 'action': 'Edit'})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@require_POST
def category_delete(request, pk):
    category = get_object_or_404(Category, pk=pk)
    if category.articles.exists():
        messages.error(request, 'Cannot delete category with articles. Reassign articles first.')
        return redirect('custom_admin:categories_list')
    category.delete()
    messages.success(request, 'Category deleted successfully!')
    return redirect('custom_admin:categories_list')


# ═══════════════════════════════════════════════════════════════
#  EVENTS
# ═══════════════════════════════════════════════════════════════

@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def events_list(request):
    events = Event.objects.all().order_by('-event_date')
    status_filter = request.GET.get('status')
    if status_filter == 'active':
        events = events.filter(is_active=True)
    elif status_filter == 'inactive':
        events = events.filter(is_active=False)

    total_count = Event.objects.count()
    active_count = Event.objects.filter(is_active=True).count()
    inactive_count = Event.objects.filter(is_active=False).count()

    paginator = Paginator(events, 20)
    page = request.GET.get('page')
    events = paginator.get_page(page)
    return render(request, 'custom_admin/events/list.html', {
        'events': events,
        'total_count': total_count,
        'active_count': active_count,
        'inactive_count': inactive_count,
        'current_filter': status_filter or 'all',
    })


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@_catch_upload_errors
def event_create(request):
    if request.method == 'POST':
        content_status = request.POST.get('content_status', 'published')
        scheduled_publish_date = request.POST.get('scheduled_publish_date') or None
        event = Event.objects.create(
            name=request.POST.get('name'),
            name_fr=request.POST.get('name_fr', ''),
            description=request.POST.get('description', ''),
            description_fr=request.POST.get('description_fr', ''),
            address=request.POST.get('address'),
            latitude=request.POST.get('latitude', 0),
            longitude=request.POST.get('longitude', 0),
            event_date=request.POST.get('event_date'),
            image=_get_existing_or_uploaded(request, 'image'),
            is_active=request.POST.get('is_active') == 'on',
            recurrence_type=request.POST.get('recurrence_type', 'none'),
            recurrence_end_date=request.POST.get('recurrence_end_date') or None,
            status=content_status,
            scheduled_publish_date=scheduled_publish_date,
        )
        log_admin_action(request, 'create', 'Event', object_id=event.pk, object_repr=event.name)
        messages.success(request, 'Event created successfully!')
        return redirect('custom_admin:events_list')
    return render(request, 'custom_admin/events/form.html', {
        'action': 'Create',
        'recurrence_choices': Event.RECURRENCE_CHOICES,
        'prefill_date': request.GET.get('date', ''),
    })


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@_catch_upload_errors
def event_edit(request, pk):
    event = get_object_or_404(Event, pk=pk)
    if request.method == 'POST':
        new_values = {
            'name': request.POST.get('name'),
            'name_fr': request.POST.get('name_fr', ''),
            'description': request.POST.get('description', ''),
            'address': request.POST.get('address'),
            'is_active': request.POST.get('is_active') == 'on',
        }
        changes = compute_model_diff(event, new_values)

        event.name = new_values['name']
        event.name_fr = new_values['name_fr']
        event.description = new_values['description']
        event.description_fr = request.POST.get('description_fr', '')
        event.address = new_values['address']
        event.latitude = request.POST.get('latitude', 0)
        event.longitude = request.POST.get('longitude', 0)
        event.event_date = request.POST.get('event_date')
        _img = _get_existing_or_uploaded(request, 'image')
        if _img:
            event.image = _img
            changes['image'] = {'old': '', 'new': 'new image uploaded'}
        event.is_active = new_values['is_active']
        event.recurrence_type = request.POST.get('recurrence_type', 'none')
        event.recurrence_end_date = request.POST.get('recurrence_end_date') or None
        event.status = request.POST.get('content_status', 'published')
        event.scheduled_publish_date = request.POST.get('scheduled_publish_date') or None
        event.save()
        log_admin_action(request, 'update', 'Event', object_id=event.pk, object_repr=event.name, changes=changes)
        messages.success(request, 'Event updated successfully!')
        return redirect('custom_admin:events_list')
    return render(request, 'custom_admin/events/form.html', {
        'event': event,
        'action': 'Edit',
        'recurrence_choices': Event.RECURRENCE_CHOICES,
    })


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@require_POST
def event_toggle_active(request, pk):
    event = get_object_or_404(Event, pk=pk)
    old_active = event.is_active
    event.is_active = not event.is_active
    event.save()
    status = 'visible in app' if event.is_active else 'hidden from app'
    log_admin_action(
        request, 'status_change', 'Event', object_id=pk, object_repr=event.name,
        changes={'is_active': {'old': str(old_active), 'new': str(event.is_active)}}
    )
    messages.success(request, f'Event "{event.name}" is now {status}.')
    return redirect('custom_admin:events_list')


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@require_POST
def event_delete(request, pk):
    event = get_object_or_404(Event, pk=pk)
    name = event.name
    log_admin_action(request, 'delete', 'Event', object_id=pk, object_repr=name)
    event.delete()
    messages.success(request, 'Event deleted successfully!')
    return redirect('custom_admin:events_list')


# ═══════════════════════════════════════════════════════════════
#  NOTIFICATIONS
# ═══════════════════════════════════════════════════════════════

@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def notifications_list(request):
    notifications = Notification.objects.all().order_by('-created_at')
    paginator = Paginator(notifications, 20)
    page = request.GET.get('page')
    notifications = paginator.get_page(page)
    return render(request, 'custom_admin/notifications/list.html', {'notifications': notifications})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def _validate_notification_language_fields(request):
    """Return an error message when language targeting is inconsistent with
    the bilingual fields provided, or ``None`` if the form is OK.

    Rules:
      * Title + message are required (basic sanity check).
      * When ``target_language='fr'`` → at least ``title_fr`` must be set,
        otherwise FR users would silently receive the English title.
      * When ``target_language='en'`` → at least ``title`` must be set
        (already covered by the sanity check but explicit for symmetry).
    """
    title = (request.POST.get('title') or '').strip()
    message = (request.POST.get('message') or '').strip()
    title_fr = (request.POST.get('title_fr') or '').strip()
    message_fr = (request.POST.get('message_fr') or '').strip()
    target_language = (request.POST.get('target_language') or '').strip()

    if not title or not message:
        return 'Title and message are required.'

    if target_language == 'fr' and not title_fr:
        return (
            'You targeted French users but the French title is empty. '
            'Please provide a French title so FR users don\'t receive the English version.'
        )

    if target_language == 'fr' and not message_fr:
        return (
            'You targeted French users but the French message is empty. '
            'Please provide a French message so FR users don\'t receive the English version.'
        )

    return None


@_catch_upload_errors
def notification_create(request):
    if request.method == 'POST':
        # Bilingual consistency validation
        validation_error = _validate_notification_language_fields(request)
        if validation_error:
            messages.error(request, validation_error)
            from core.models import NATIONALITY_CHOICES
            return render(request, 'custom_admin/notifications/form.html', {
                'action': 'Create',
                'nationality_choices': NATIONALITY_CHOICES,
                'form_data': request.POST,
            })

        # Parse scheduled_at datetime
        scheduled_at = None
        scheduled_at_str = request.POST.get('scheduled_at', '').strip()
        if scheduled_at_str:
            from django.utils.dateparse import parse_datetime
            scheduled_at = parse_datetime(scheduled_at_str)

        # Parse schedule_time
        schedule_time = None
        schedule_time_str = request.POST.get('schedule_time', '').strip()
        if schedule_time_str:
            from django.utils.dateparse import parse_time
            schedule_time = parse_time(schedule_time_str)

        notification = Notification.objects.create(
            title=request.POST.get('title'),
            title_fr=request.POST.get('title_fr', ''),
            message=request.POST.get('message'),
            message_fr=request.POST.get('message_fr', ''),
            notification_type=request.POST.get('notification_type', 'general'),
            action_type=request.POST.get('action_type', 'none'),
            action_value=request.POST.get('action_value', ''),
            is_global=request.POST.get('is_global') == 'on',
            is_active=request.POST.get('is_active') == 'on',
            image=_get_existing_or_uploaded(request, 'image'),
            target_gender=request.POST.get('target_gender', ''),
            target_nationalities=request.POST.getlist('target_nationalities'),
            target_age_min=int(request.POST['target_age_min']) if request.POST.get('target_age_min') else None,
            target_age_max=int(request.POST['target_age_max']) if request.POST.get('target_age_max') else None,
            target_verified_only=request.POST.get('target_verified_only') == 'on',
            target_badge_type=request.POST.get('target_badge_type', ''),
            target_language=request.POST.get('target_language', ''),
            scheduled_at=scheduled_at,
            # Recurring schedule fields
            is_scheduled=request.POST.get('is_scheduled') == 'on',
            schedule_type=request.POST.get('schedule_type', 'once'),
            schedule_day=int(request.POST['schedule_day']) if request.POST.get('schedule_day') else None,
            schedule_time=schedule_time,
        )
        log_admin_action(request, 'create', 'Notification', object_id=notification.pk, object_repr=notification.title)

        # If recurring schedule is set, don't send immediately
        if notification.is_scheduled and notification.schedule_type in ('daily', 'weekly'):
            messages.success(
                request,
                f'Recurring notification created ({notification.get_schedule_type_display()}).'
            )
            return redirect('custom_admin:notifications_list')

        # If scheduled for the future, don't send immediately
        if scheduled_at and scheduled_at > timezone.now():
            messages.success(
                request,
                f'Notification scheduled for {scheduled_at.strftime("%b %d, %Y %H:%M")}.'
            )
            return redirect('custom_admin:notifications_list')

        # Send push notification if requested
        send_push = request.POST.get('send_push') == 'on'
        if send_push and notification.is_active:
            from core.tasks import send_notification_push_async
            send_notification_push_async.delay(notification.pk)
            log_admin_action(
                request, 'send_notification', 'Notification',
                object_id=notification.pk, object_repr=notification.title,
                changes={'push_sent': {'old': '', 'new': 'queued'}}
            )
            messages.success(
                request,
                'Notification created and push queued for delivery.'
            )
        else:
            messages.success(request, 'Notification created successfully!')
        return redirect('custom_admin:notifications_list')
    from core.models import NATIONALITY_CHOICES
    return render(request, 'custom_admin/notifications/form.html', {
        'action': 'Create',
        'nationality_choices': NATIONALITY_CHOICES,
        'prefill_date': request.GET.get('date', ''),
    })


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@_catch_upload_errors
def notification_edit(request, pk):
    notification = get_object_or_404(Notification, pk=pk)
    if request.method == 'POST':
        # Bilingual consistency validation
        validation_error = _validate_notification_language_fields(request)
        if validation_error:
            messages.error(request, validation_error)
            from core.models import NATIONALITY_CHOICES
            return render(request, 'custom_admin/notifications/form.html', {
                'action': 'Edit',
                'notification': notification,
                'nationality_choices': NATIONALITY_CHOICES,
                'form_data': request.POST,
            })
        notification.title = request.POST.get('title')
        notification.title_fr = request.POST.get('title_fr', '')
        notification.message = request.POST.get('message')
        notification.message_fr = request.POST.get('message_fr', '')
        notification.notification_type = request.POST.get('notification_type', 'general')
        notification.action_type = request.POST.get('action_type', 'none')
        notification.action_value = request.POST.get('action_value', '')
        notification.is_global = request.POST.get('is_global') == 'on'
        notification.is_active = request.POST.get('is_active') == 'on'
        _img = _get_existing_or_uploaded(request, 'image')
        if _img:
            notification.image = _img
        notification.target_gender = request.POST.get('target_gender', '')
        notification.target_nationalities = request.POST.getlist('target_nationalities')
        notification.target_age_min = int(request.POST['target_age_min']) if request.POST.get('target_age_min') else None
        notification.target_age_max = int(request.POST['target_age_max']) if request.POST.get('target_age_max') else None
        notification.target_verified_only = request.POST.get('target_verified_only') == 'on'
        notification.target_badge_type = request.POST.get('target_badge_type', '')
        notification.target_language = request.POST.get('target_language', '')
        # Recurring schedule fields
        notification.is_scheduled = request.POST.get('is_scheduled') == 'on'
        notification.schedule_type = request.POST.get('schedule_type', 'once')
        notification.schedule_day = int(request.POST['schedule_day']) if request.POST.get('schedule_day') else None
        schedule_time_str = request.POST.get('schedule_time', '').strip()
        if schedule_time_str:
            from django.utils.dateparse import parse_time
            notification.schedule_time = parse_time(schedule_time_str)
        else:
            notification.schedule_time = None
        # Update scheduled_at
        scheduled_at_str = request.POST.get('scheduled_at', '').strip()
        if scheduled_at_str:
            from django.utils.dateparse import parse_datetime
            notification.scheduled_at = parse_datetime(scheduled_at_str)
        else:
            notification.scheduled_at = None
        notification.save()
        # Send push if explicitly requested on edit
        send_push = request.POST.get('send_push') == 'on'
        if send_push and notification.is_active:
            from core.tasks import send_notification_push_async
            send_notification_push_async.delay(notification.pk)
            messages.success(
                request,
                'Notification updated and push queued for delivery.'
            )
        else:
            messages.success(request, 'Notification updated successfully!')
        return redirect('custom_admin:notifications_list')
    from core.models import NATIONALITY_CHOICES
    return render(request, 'custom_admin/notifications/form.html', {
        'notification': notification,
        'action': 'Edit',
        'nationality_choices': NATIONALITY_CHOICES,
    })


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@require_POST
def notification_delete(request, pk):
    notification = get_object_or_404(Notification, pk=pk)
    title = notification.title
    log_admin_action(request, 'delete', 'Notification', object_id=pk, object_repr=title)
    notification.delete()
    messages.success(request, 'Notification deleted successfully!')
    return redirect('custom_admin:notifications_list')


# ══════════════════════════════════════════════════════════════
# What's New / App Releases
# ══════════════════════════════════════════════════════════════

# Curated list of Material icon names admins can pick from.
# Keep in sync with ``_backendIconMap`` in ``lib/widgets/whats_new_dialog.dart``.
APP_RELEASE_ICON_CHOICES = [
    ('forum_rounded', 'Comments / Chat'),
    ('notifications_active_rounded', 'Notifications'),
    ('translate_rounded', 'Languages'),
    ('people_alt_rounded', 'Users / Social'),
    ('shield_rounded', 'Privacy / Security'),
    ('speed_rounded', 'Performance'),
    ('bug_report_rounded', 'Bug Fixes'),
    ('event_available_rounded', 'Events'),
    ('verified_rounded', 'Verification'),
    ('auto_awesome_rounded', 'New Feature'),
    ('palette_rounded', 'Design / Theme'),
    ('article_rounded', 'Articles'),
    ('menu_book_rounded', 'Magazine'),
    ('play_circle_rounded', 'Videos'),
    ('live_tv_rounded', 'Live Feeds'),
    ('map_rounded', 'Locations'),
    ('support_agent_rounded', 'Support'),
    ('search_rounded', 'Search'),
    ('download_rounded', 'Downloads'),
    ('dark_mode_rounded', 'Dark Mode'),
    ('accessibility_rounded', 'Accessibility'),
    ('rocket_launch_rounded', 'Launch / Release'),
    ('star_rounded', 'General Highlight'),
]


def _parse_highlights_from_post(post_data):
    """Parse dynamic highlight rows from a submitted form.

    The form posts arrays via the naming convention
    ``highlight_icon[]``, ``highlight_title_en[]``, etc. We zip them together
    and drop any row missing a title or subtitle so empty rows don't
    persist junk data.
    """
    icons = post_data.getlist('highlight_icon[]')
    title_ens = post_data.getlist('highlight_title_en[]')
    title_frs = post_data.getlist('highlight_title_fr[]')
    subtitle_ens = post_data.getlist('highlight_subtitle_en[]')
    subtitle_frs = post_data.getlist('highlight_subtitle_fr[]')

    rows = []
    for i, title_en in enumerate(title_ens):
        icon = (icons[i] if i < len(icons) else '').strip() or 'star_rounded'
        t_en = (title_en or '').strip()
        t_fr = (title_frs[i] if i < len(title_frs) else '').strip()
        s_en = (subtitle_ens[i] if i < len(subtitle_ens) else '').strip()
        s_fr = (subtitle_frs[i] if i < len(subtitle_frs) else '').strip()
        if not t_en or not s_en:
            continue
        rows.append({
            'icon_name': icon,
            'title_en': t_en,
            'title_fr': t_fr,
            'subtitle_en': s_en,
            'subtitle_fr': s_fr,
        })
    return rows


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def app_releases_list(request):
    releases = AppRelease.objects.all().prefetch_related('highlights').order_by('-version_code')
    paginator = Paginator(releases, 20)
    page = request.GET.get('page')
    releases = paginator.get_page(page)
    return render(request, 'custom_admin/app_releases/list.html', {
        'releases': releases,
    })


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def app_release_create(request):
    if request.method == 'POST':
        version = (request.POST.get('version') or '').strip()
        version_code_str = (request.POST.get('version_code') or '').strip()
        title = (request.POST.get('title') or '').strip()

        if not version or not version_code_str or not title:
            messages.error(request, 'Version, version code, and title are required.')
            return render(request, 'custom_admin/app_releases/form.html', {
                'action': 'Create',
                'icon_choices': APP_RELEASE_ICON_CHOICES,
                'form_data': request.POST,
                'highlights': _parse_highlights_from_post(request.POST),
            })

        try:
            version_code = int(version_code_str)
        except ValueError:
            messages.error(request, 'Version code must be an integer.')
            return render(request, 'custom_admin/app_releases/form.html', {
                'action': 'Create',
                'icon_choices': APP_RELEASE_ICON_CHOICES,
                'form_data': request.POST,
                'highlights': _parse_highlights_from_post(request.POST),
            })

        released_at_str = (request.POST.get('released_at') or '').strip()
        released_at = timezone.now()
        if released_at_str:
            from django.utils.dateparse import parse_datetime
            parsed = parse_datetime(released_at_str)
            if parsed is not None:
                released_at = parsed

        popup_delay_str = (request.POST.get('popup_delay_seconds') or '2').strip()
        try:
            popup_delay = max(0, int(popup_delay_str))
        except ValueError:
            popup_delay = 2

        try:
            release = AppRelease.objects.create(
                version=version,
                version_code=version_code,
                title=title,
                title_fr=(request.POST.get('title_fr') or '').strip(),
                release_notes=(request.POST.get('release_notes') or '').strip(),
                release_notes_fr=(request.POST.get('release_notes_fr') or '').strip(),
                is_force_update=request.POST.get('is_force_update') == 'on',
                is_published=request.POST.get('is_published') == 'on',
                min_supported_version=(request.POST.get('min_supported_version') or '').strip(),
                android_url=(request.POST.get('android_url') or '').strip(),
                ios_url=(request.POST.get('ios_url') or '').strip(),
                popup_delay_seconds=popup_delay,
                released_at=released_at,
            )
        except Exception as exc:
            messages.error(request, f'Could not create release: {exc}')
            return render(request, 'custom_admin/app_releases/form.html', {
                'action': 'Create',
                'icon_choices': APP_RELEASE_ICON_CHOICES,
                'form_data': request.POST,
                'highlights': _parse_highlights_from_post(request.POST),
            })

        for order, row in enumerate(_parse_highlights_from_post(request.POST)):
            AppReleaseHighlight.objects.create(release=release, order=order, **row)

        log_admin_action(
            request, 'create', 'AppRelease',
            object_id=release.pk, object_repr=f'v{release.version}'
        )
        messages.success(request, f"Release v{release.version} created.")
        return redirect('custom_admin:app_releases_list')

    return render(request, 'custom_admin/app_releases/form.html', {
        'action': 'Create',
        'icon_choices': APP_RELEASE_ICON_CHOICES,
        'highlights': [],
    })


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def app_release_edit(request, pk):
    release = get_object_or_404(AppRelease, pk=pk)

    if request.method == 'POST':
        version = (request.POST.get('version') or '').strip()
        version_code_str = (request.POST.get('version_code') or '').strip()
        title = (request.POST.get('title') or '').strip()

        if not version or not version_code_str or not title:
            messages.error(request, 'Version, version code, and title are required.')
            return render(request, 'custom_admin/app_releases/form.html', {
                'action': 'Edit',
                'release': release,
                'icon_choices': APP_RELEASE_ICON_CHOICES,
                'highlights': _parse_highlights_from_post(request.POST),
                'form_data': request.POST,
            })

        try:
            version_code = int(version_code_str)
        except ValueError:
            messages.error(request, 'Version code must be an integer.')
            return render(request, 'custom_admin/app_releases/form.html', {
                'action': 'Edit',
                'release': release,
                'icon_choices': APP_RELEASE_ICON_CHOICES,
                'highlights': _parse_highlights_from_post(request.POST),
                'form_data': request.POST,
            })

        released_at_str = (request.POST.get('released_at') or '').strip()
        if released_at_str:
            from django.utils.dateparse import parse_datetime
            parsed = parse_datetime(released_at_str)
            if parsed is not None:
                release.released_at = parsed

        popup_delay_str = (request.POST.get('popup_delay_seconds') or '2').strip()
        try:
            popup_delay = max(0, int(popup_delay_str))
        except ValueError:
            popup_delay = 2

        release.version = version
        release.version_code = version_code
        release.title = title
        release.title_fr = (request.POST.get('title_fr') or '').strip()
        release.release_notes = (request.POST.get('release_notes') or '').strip()
        release.release_notes_fr = (request.POST.get('release_notes_fr') or '').strip()
        release.is_force_update = request.POST.get('is_force_update') == 'on'
        release.is_published = request.POST.get('is_published') == 'on'
        release.min_supported_version = (request.POST.get('min_supported_version') or '').strip()
        release.android_url = (request.POST.get('android_url') or '').strip()
        release.ios_url = (request.POST.get('ios_url') or '').strip()
        release.popup_delay_seconds = popup_delay

        try:
            release.save()
        except Exception as exc:
            messages.error(request, f'Could not save release: {exc}')
            return render(request, 'custom_admin/app_releases/form.html', {
                'action': 'Edit',
                'release': release,
                'icon_choices': APP_RELEASE_ICON_CHOICES,
                'highlights': _parse_highlights_from_post(request.POST),
                'form_data': request.POST,
            })

        # Replace highlights wholesale — simpler than diffing in a dynamic form.
        release.highlights.all().delete()
        for order, row in enumerate(_parse_highlights_from_post(request.POST)):
            AppReleaseHighlight.objects.create(release=release, order=order, **row)

        log_admin_action(
            request, 'update', 'AppRelease',
            object_id=release.pk, object_repr=f'v{release.version}'
        )
        messages.success(request, f"Release v{release.version} updated.")
        return redirect('custom_admin:app_releases_list')

    highlights = [
        {
            'icon_name': h.icon_name,
            'title_en': h.title_en,
            'title_fr': h.title_fr,
            'subtitle_en': h.subtitle_en,
            'subtitle_fr': h.subtitle_fr,
        }
        for h in release.highlights.all()
    ]
    return render(request, 'custom_admin/app_releases/form.html', {
        'action': 'Edit',
        'release': release,
        'icon_choices': APP_RELEASE_ICON_CHOICES,
        'highlights': highlights,
    })


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@require_POST
def app_release_delete(request, pk):
    release = get_object_or_404(AppRelease, pk=pk)
    version = release.version
    log_admin_action(
        request, 'delete', 'AppRelease',
        object_id=pk, object_repr=f'v{version}'
    )
    release.delete()
    messages.success(request, f"Release v{version} deleted.")
    return redirect('custom_admin:app_releases_list')


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@require_POST
def notification_send_push(request, pk):
    """Send (or resend) a push notification for an existing notification, with optional SMS."""
    notification = get_object_or_404(Notification, pk=pk)
    if not notification.is_active:
        messages.error(request, 'Cannot send push for an inactive notification. Activate it first.')
        return redirect('custom_admin:notifications_list')
    from core.tasks import send_notification_push_async
    send_notification_push_async.delay(notification.pk)
    push_msg = 'Push queued for delivery.'

    # Also send SMS if requested
    send_sms_flag = request.POST.get('send_sms') == 'on'
    sms_msg = ''
    if send_sms_flag:
        try:
            from core.utils import send_sms_to_enabled_users
            sms_success, sms_failure = send_sms_to_enabled_users(
                notification.title, notification.message
            )
            sms_msg = f' | SMS sent to {sms_success} user(s).'
            if sms_failure:
                sms_msg += f' ({sms_failure} SMS failed)'
        except Exception as e:
            sms_msg = f' | SMS failed: {e}'

    log_admin_action(
        request, 'send_notification', 'Notification',
        object_id=notification.pk, object_repr=notification.title,
        changes={'result': {'old': '', 'new': push_msg + sms_msg}}
    )
    messages.success(request, push_msg + sms_msg)
    return redirect('custom_admin:notifications_list')


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def notification_estimate_audience(request):
    """Return estimated audience count based on targeting filters.
    Includes anonymous device tokens for global notifications."""
    from core.models import UserProfile
    from django.db.models import Q

    # Include profiles with either a legacy fcm_token or active DeviceTokens
    profiles = UserProfile.objects.filter(
        Q(fcm_token__isnull=False) & ~Q(fcm_token='')
        | Q(user__device_tokens__is_active=True)
    ).distinct()

    is_global = request.GET.get('is_global') == 'true'
    if not is_global:
        gender = request.GET.get('target_gender', '')
        if gender:
            profiles = profiles.filter(gender=gender)

        language = request.GET.get('target_language', '')
        if language:
            profiles = profiles.filter(preferred_language=language)

        verified_only = request.GET.get('target_verified_only') == 'true'
        if verified_only:
            profiles = profiles.filter(is_verified=True)
            badge_type = request.GET.get('target_badge_type', '')
            if badge_type:
                profiles = profiles.filter(badge_type=badge_type)

    count = profiles.count()

    # Split by language (before anonymous devices, which have no language)
    en_count = profiles.filter(preferred_language='en').count()
    fr_count = profiles.filter(preferred_language='fr').count()

    # Include anonymous device tokens for global notifications
    if is_global:
        anonymous_count = DeviceToken.objects.filter(
            user__isnull=True,
            is_active=True,
        ).count()
        count += anonymous_count

    total = UserProfile.objects.filter(
        Q(fcm_token__isnull=False) & ~Q(fcm_token='')
        | Q(user__device_tokens__is_active=True)
    ).distinct().count()
    # Add anonymous device count to total as well
    total += DeviceToken.objects.filter(user__isnull=True, is_active=True).count()

    return JsonResponse({
        'count': count,
        'total': total,
        'by_language': {'en': en_count, 'fr': fr_count},
    })


# ═══════════════════════════════════════════════════════════════
#  USERS
# ═══════════════════════════════════════════════════════════════

@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def users_list(request):
    users = User.objects.all().select_related('profile').order_by('-date_joined')
    search = request.GET.get('search')
    if search:
        users = users.filter(
            Q(username__icontains=search) | Q(email__icontains=search) |
            Q(first_name__icontains=search) | Q(last_name__icontains=search)
        )
    # Filter by status
    status_filter = request.GET.get('status')
    if status_filter == 'active':
        users = users.filter(is_active=True)
    elif status_filter == 'blocked':
        users = users.filter(is_active=False)
    elif status_filter == 'staff':
        users = users.filter(is_staff=True)
    elif status_filter == 'verified':
        users = users.filter(profile__is_verified=True)
    elif status_filter == 'comment_banned':
        users = users.filter(profile__is_comment_banned=True)

    total_count = User.objects.count()
    active_count = User.objects.filter(is_active=True).count()
    blocked_count = User.objects.filter(is_active=False).count()
    staff_count = User.objects.filter(is_staff=True).count()
    verified_count = UserProfile.objects.filter(is_verified=True).count()
    comment_banned_count = UserProfile.objects.filter(is_comment_banned=True).count()
    pending_verifications = VerificationRequest.objects.filter(status='pending').count()

    paginator = Paginator(users, 20)
    page = request.GET.get('page')
    users = paginator.get_page(page)
    return render(request, 'custom_admin/users/list.html', {
        'users': users,
        'total_count': total_count,
        'active_count': active_count,
        'blocked_count': blocked_count,
        'staff_count': staff_count,
        'verified_count': verified_count,
        'comment_banned_count': comment_banned_count,
        'pending_verifications': pending_verifications,
        'current_filter': status_filter or 'all',
    })


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def user_create(request):
    from core.models import NATIONALITY_CHOICES
    if request.method == 'POST':
        username = request.POST.get('username')
        email = request.POST.get('email')
        password = request.POST.get('password')
        first_name = request.POST.get('first_name', '')
        last_name = request.POST.get('last_name', '')

        if User.objects.filter(username=username).exists():
            messages.error(request, f'Username "{username}" already exists.')
            return render(request, 'custom_admin/users/form.html', {'action': 'Create', 'nationality_choices': NATIONALITY_CHOICES})
        if email and User.objects.filter(email=email).exists():
            messages.error(request, f'Email "{email}" already in use.')
            return render(request, 'custom_admin/users/form.html', {'action': 'Create', 'nationality_choices': NATIONALITY_CHOICES})

        user = User.objects.create_user(
            username=username,
            email=email,
            password=password,
            first_name=first_name,
            last_name=last_name,
        )
        user.is_staff = request.POST.get('is_staff') == 'on'
        user.is_active = request.POST.get('is_active') != 'off'
        user.save()
        messages.success(request, f'User "{username}" created successfully!')
        return redirect('custom_admin:users_list')
    return render(request, 'custom_admin/users/form.html', {'action': 'Create', 'nationality_choices': NATIONALITY_CHOICES})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def user_edit(request, pk):
    target_user = get_object_or_404(User, pk=pk)

    # Only superusers may edit other superuser or staff accounts
    if (target_user.is_superuser or target_user.is_staff) and not request.user.is_superuser:
        messages.error(request, 'Only superusers can edit staff or superuser accounts.')
        return redirect('custom_admin:users_list')

    profile = getattr(target_user, 'profile', None)
    if not profile:
        profile = UserProfile.objects.create(user=target_user)

    if request.method == 'POST':
        target_user.first_name = request.POST.get('first_name', '')
        target_user.last_name = request.POST.get('last_name', '')
        target_user.email = request.POST.get('email', '')
        target_user.is_active = request.POST.get('is_active') == 'on'
        # Only superusers can modify staff status
        if request.user.is_superuser:
            target_user.is_staff = request.POST.get('is_staff') == 'on'

        new_password = request.POST.get('password', '').strip()
        if new_password:
            target_user.set_password(new_password)

        target_user.save()

        # Profile fields
        profile.phone_number = request.POST.get('phone_number', '')
        profile.nationality = request.POST.get('nationality', '')
        profile.gender = request.POST.get('gender', '')
        profile.is_verified = request.POST.get('is_verified') == 'on'
        profile.badge_type = request.POST.get('badge_type') or None
        profile.is_government_official = request.POST.get('is_government_official') == 'on'
        profile.is_usher = request.POST.get('is_usher') == 'on'
        profile.save()

        messages.success(request, f'User "{target_user.username}" updated successfully!')
        return redirect('custom_admin:users_list')

    verification_requests = VerificationRequest.objects.filter(user=target_user).order_by('-created_at')
    from core.models import ProfanityStrikeLog, NATIONALITY_CHOICES
    strike_logs = ProfanityStrikeLog.objects.filter(user=target_user).order_by('-created_at')[:20]
    return render(request, 'custom_admin/users/form.html', {
        'target_user': target_user,
        'profile': profile,
        'verification_requests': verification_requests,
        'strike_logs': strike_logs,
        'nationality_choices': NATIONALITY_CHOICES,
        'action': 'Edit',
    })


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@require_POST
def user_toggle_active(request, pk):
    target_user = get_object_or_404(User, pk=pk)
    if target_user == request.user:
        messages.error(request, 'You cannot block yourself.')
        return redirect('custom_admin:users_list')
    # Only superusers may toggle staff/superuser accounts
    if (target_user.is_superuser or target_user.is_staff) and not request.user.is_superuser:
        messages.error(request, 'Only superusers can modify staff or superuser accounts.')
        return redirect('custom_admin:users_list')
    old_active = target_user.is_active
    target_user.is_active = not target_user.is_active
    target_user.save()
    action = 'unblocked' if target_user.is_active else 'blocked'
    log_admin_action(
        request, 'status_change', 'User', object_id=pk,
        object_repr=target_user.username,
        changes={'is_active': {'old': str(old_active), 'new': str(target_user.is_active)}}
    )
    messages.success(request, f'User "{target_user.username}" has been {action}.')
    return redirect('custom_admin:users_list')


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@require_POST
def user_toggle_staff(request, pk):
    # Only superusers can modify staff status
    if not request.user.is_superuser:
        messages.error(request, 'Only superusers can modify staff permissions.')
        return redirect('custom_admin:users_list')
    target_user = get_object_or_404(User, pk=pk)
    if target_user == request.user:
        messages.error(request, 'You cannot remove your own staff status.')
        return redirect('custom_admin:users_list')
    old_staff = target_user.is_staff
    target_user.is_staff = not target_user.is_staff
    target_user.save()
    action = 'granted staff access' if target_user.is_staff else 'removed from staff'
    log_admin_action(
        request, 'status_change', 'User', object_id=pk,
        object_repr=target_user.username,
        changes={'is_staff': {'old': str(old_staff), 'new': str(target_user.is_staff)}}
    )
    messages.success(request, f'User "{target_user.username}" {action}.')
    return redirect('custom_admin:users_list')


# ═══════════════════════════════════════════════════════════════
#  ADMIN MANAGEMENT (Superuser only)
# ═══════════════════════════════════════════════════════════════

@login_required(login_url='custom_admin:login')
@user_passes_test(lambda u: u.is_superuser, login_url='custom_admin:login')
def admin_management(request):
    """Superadmin page to view/manage other admin (staff) users."""
    from .permissions import ADMIN_MENUS, ADMIN_MENU_GROUPS, MENU_KEYS
    admins = User.objects.filter(
        Q(is_staff=True) | Q(is_superuser=True)
    ).select_related('profile').order_by('-last_login')

    # Attach allowed-menu list to each admin for template rendering
    for a in admins:
        try:
            raw = a.profile.admin_sections or []
        except Exception:
            logger.warning('Failed to load admin_sections for user %s', a.pk, exc_info=True)
            raw = []
        a.allowed_sections_set = set(raw) & MENU_KEYS

    return render(request, 'custom_admin/admin_management/list.html', {
        'admins': admins,
        'total_admins': admins.count(),
        'superadmins': admins.filter(is_superuser=True).count(),
        'staff_only': admins.filter(is_staff=True, is_superuser=False).count(),
        'all_sections': ADMIN_MENUS,        # flat list (back-compat)
        'all_menu_groups': ADMIN_MENU_GROUPS, # grouped list for display
        'total_menus': len(ADMIN_MENUS),
    })


@login_required(login_url='custom_admin:login')
@user_passes_test(lambda u: u.is_superuser, login_url='custom_admin:login')
def admin_invite(request):
    """Invite a new admin by creating their account and sending credentials via email."""
    if request.method == 'POST':
        username = request.POST.get('username', '').strip()
        email = request.POST.get('email', '').strip()
        first_name = request.POST.get('first_name', '').strip()
        last_name = request.POST.get('last_name', '').strip()
        role = request.POST.get('role', 'staff')  # 'staff' or 'superuser'

        if not username or not email:
            messages.error(request, 'Username and email are required.')
            return redirect('custom_admin:admin_management')

        if User.objects.filter(username=username).exists():
            messages.error(request, f'Username "{username}" already exists.')
            return redirect('custom_admin:admin_management')

        if User.objects.filter(email=email).exists():
            messages.error(request, f'Email "{email}" is already in use.')
            return redirect('custom_admin:admin_management')

        # Generate a temporary password
        import secrets
        import string
        temp_password = ''.join(secrets.choice(string.ascii_letters + string.digits) for _ in range(12))

        user = User.objects.create_user(
            username=username,
            email=email,
            password=temp_password,
            first_name=first_name,
            last_name=last_name,
        )
        user.is_staff = True
        user.is_superuser = (role == 'superuser')
        user.save()

        # Force the invited user to change their password on first login
        try:
            user.profile.force_password_change = True
            user.profile.save(update_fields=['force_password_change'])
        except Exception:
            logger.exception('Failed to set force_password_change for user %s', user.pk)

        # Save per-section permissions (staff only; superusers have full access)
        from .permissions import SECTION_KEYS
        selected_sections = [s for s in request.POST.getlist('sections') if s in SECTION_KEYS]
        try:
            user.profile.admin_sections = selected_sections
            user.profile.save(update_fields=['admin_sections'])
        except Exception:
            logger.exception('Failed to save admin_sections on invite')

        # Send invitation email
        try:
            from django.core.mail import send_mail
            from django.conf import settings as conf_settings
            subject = 'Admin Portal Access — Be 4 Africa 2026'
            message = (
                f'Dear {first_name or username},\n\n'
                f'You have been granted {"Super Admin" if role == "superuser" else "Staff"} access '
                f'to the Be 4 Africa Admin Portal.\n\n'
                f'Your login credentials:\n'
                f'  Portal URL: https://burundi4africa.com/admin/\n'
                f'  Username: {username}\n'
                f'  Temporary Password: {temp_password}\n\n'
                f'Please change your password after your first login.\n\n'
                f'For questions, contact info@burundi4africa.com\n\n'
                f'Best regards,\n'
                f'Be 4 Africa Team\n'
                f'Ministère des Affaires Étrangères'
            )
            send_mail(
                subject,
                message,
                conf_settings.DEFAULT_FROM_EMAIL,
                [email],
                fail_silently=False,
            )
            messages.success(request, f'Admin "{username}" created and invitation email sent to {email}.')
        except Exception as e:
            logger.exception('Failed to send admin invitation email')
            messages.warning(
                request,
                f'Admin "{username}" created but email failed to send. '
                f'Please manually share: Username: {username}, Password: {temp_password}'
            )

        return redirect('custom_admin:admin_management')

    return redirect('custom_admin:admin_management')


@login_required(login_url='custom_admin:login')
@user_passes_test(lambda u: u.is_superuser, login_url='custom_admin:login')
@require_POST
def admin_edit_access(request, pk):
    """Update the per-section permissions of an existing admin user."""
    from .permissions import SECTION_KEYS
    target = get_object_or_404(User, pk=pk)

    if target.is_superuser:
        messages.info(request, f'{target.username} is a Super Admin — permissions are unrestricted.')
        return redirect('custom_admin:admin_management')

    selected = [s for s in request.POST.getlist('sections') if s in SECTION_KEYS]
    try:
        target.profile.admin_sections = selected
        target.profile.save(update_fields=['admin_sections'])
        log_admin_action(
            request, 'update', 'UserProfile', object_id=target.pk,
            object_repr=target.username,
            changes={'admin_sections': {'new': selected}},
        )
        messages.success(request, f'Access updated for {target.username} ({len(selected)} sections).')
    except Exception:
        logger.exception('Failed to update admin_sections')
        messages.error(request, 'Failed to update access. Please try again.')

    return redirect('custom_admin:admin_management')


# ═══════════════════════════════════════════════════════════════
#  VERIFICATION REQUESTS
# ═══════════════════════════════════════════════════════════════

@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def verification_requests_list(request):
    requests_qs = VerificationRequest.objects.all().select_related('user', 'reviewed_by').order_by('-created_at')
    status_filter = request.GET.get('status')
    if status_filter:
        requests_qs = requests_qs.filter(status=status_filter)
    paginator = Paginator(requests_qs, 20)
    page = request.GET.get('page')
    requests_page = paginator.get_page(page)
    pending_count = VerificationRequest.objects.filter(status='pending').count()
    total_count = VerificationRequest.objects.count()
    approved_count = VerificationRequest.objects.filter(status='approved').count()
    rejected_count = VerificationRequest.objects.filter(status='rejected').count()
    return render(request, 'custom_admin/verification/list.html', {
        'requests': requests_page,
        'pending_count': pending_count,
        'total_count': total_count,
        'approved_count': approved_count,
        'rejected_count': rejected_count,
        'current_filter': status_filter or '',
    })


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def verification_request_review(request, pk):
    ver_request = get_object_or_404(
        VerificationRequest.objects.select_related('user', 'reviewed_by').prefetch_related('social_media_profiles'),
        pk=pk
    )
    if request.method == 'POST':
        action = request.POST.get('action')
        if action == 'approve':
            badge_type = request.POST.get('badge_type', 'BLUE')
            ver_request.status = 'approved'
            ver_request.badge_type = badge_type
            ver_request.reviewed_by = request.user
            ver_request.reviewed_at = timezone.now()
            ver_request.save()
            # Update user profile
            profile = ver_request.user.profile
            profile.is_verified = True
            profile.badge_type = badge_type
            profile.verified_at = timezone.now()
            profile.save()
            log_admin_action(
                request, 'approve', 'VerificationRequest', object_id=pk,
                object_repr=ver_request.full_name,
                changes={'status': {'old': 'pending', 'new': 'approved'}, 'badge_type': {'old': '', 'new': badge_type}}
            )
            # Send verification approval email
            try:
                from django.core.mail import send_mail
                user = ver_request.user
                send_mail(
                    subject='Congratulations! Your Account is Verified',
                    message=f'Dear {user.first_name or user.username},\n\nYour verification request has been approved. You now have a {badge_type} badge on your profile.\n\nThank you for being part of the Be 4 Africa community.\n\nBest regards,\nB4Africa Team',
                    from_email=settings.DEFAULT_FROM_EMAIL,
                    recipient_list=[user.email],
                    fail_silently=True,
                )
            except Exception:
                pass
            messages.success(request, f'Approved {ver_request.full_name} with {badge_type} badge.')
        elif action == 'reject':
            ver_request.status = 'rejected'
            ver_request.rejection_reason = request.POST.get('rejection_reason', '')
            ver_request.reviewed_by = request.user
            ver_request.reviewed_at = timezone.now()
            ver_request.save()
            log_admin_action(
                request, 'reject', 'VerificationRequest', object_id=pk,
                object_repr=ver_request.full_name,
                changes={'status': {'old': 'pending', 'new': 'rejected'}, 'reason': {'old': '', 'new': ver_request.rejection_reason}}
            )
            messages.success(request, f'Rejected verification request from {ver_request.full_name}.')
        return redirect('custom_admin:verification_requests_list')
    return render(request, 'custom_admin/verification/review.html', {'ver_request': ver_request})


# ═══════════════════════════════════════════════════════════════
#  MAGAZINES
# ═══════════════════════════════════════════════════════════════

@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def magazines_list(request):
    magazines = MagazineEdition.objects.all().order_by('-publish_date')
    paginator = Paginator(magazines, 20)
    page = request.GET.get('page')
    magazines = paginator.get_page(page)
    return render(request, 'custom_admin/magazines/list.html', {'magazines': magazines})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@_catch_upload_errors
def magazine_create(request):
    if request.method == 'POST':
        content_status = request.POST.get('content_status', 'published')
        scheduled_publish_date = request.POST.get('scheduled_publish_date') or None
        MagazineEdition.objects.create(
            title=request.POST.get('title'),
            title_fr=request.POST.get('title_fr', ''),
            description=request.POST.get('description', ''),
            description_fr=request.POST.get('description_fr', ''),
            cover_image=_get_existing_or_uploaded(request, 'cover_image'),
            pdf_file=request.FILES.get('pdf_file'),
            page_count=request.POST.get('page_count', 0),
            file_size=request.POST.get('file_size', ''),
            publish_date=request.POST.get('publish_date') or timezone.now().date(),
            is_featured=request.POST.get('is_featured') == 'on',
            status=content_status,
            scheduled_publish_date=scheduled_publish_date,
        )
        log_admin_action(request, 'create', 'MagazineEdition', object_repr=request.POST.get('title', ''))
        messages.success(request, f'Magazine created as {content_status}!')
        return redirect('custom_admin:magazines_list')
    return render(request, 'custom_admin/magazines/form.html', {'action': 'Create', 'prefill_date': request.GET.get('date', '')})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@_catch_upload_errors
def magazine_edit(request, pk):
    magazine = get_object_or_404(MagazineEdition, pk=pk)
    if request.method == 'POST':
        new_values = {
            'title': request.POST.get('title'),
            'title_fr': request.POST.get('title_fr', ''),
            'description': request.POST.get('description', ''),
            'is_featured': request.POST.get('is_featured') == 'on',
        }
        changes = compute_model_diff(magazine, new_values)

        magazine.title = new_values['title']
        magazine.title_fr = new_values['title_fr']
        magazine.description = new_values['description']
        magazine.description_fr = request.POST.get('description_fr', '')
        _ci = _get_existing_or_uploaded(request, 'cover_image')
        if _ci:
            magazine.cover_image = _ci
            changes['cover_image'] = {'old': '', 'new': 'new image uploaded'}
        if request.FILES.get('pdf_file'):
            magazine.pdf_file = request.FILES.get('pdf_file')
            changes['pdf_file'] = {'old': '', 'new': 'new PDF uploaded'}
        magazine.page_count = request.POST.get('page_count', 0)
        magazine.file_size = request.POST.get('file_size', '')
        magazine.is_featured = new_values['is_featured']
        magazine.status = request.POST.get('content_status', 'published')
        magazine.scheduled_publish_date = request.POST.get('scheduled_publish_date') or None
        magazine.save()
        log_admin_action(request, 'update', 'MagazineEdition', object_id=pk, object_repr=magazine.title, changes=changes)
        messages.success(request, 'Magazine updated successfully!')
        return redirect('custom_admin:magazines_list')
    return render(request, 'custom_admin/magazines/form.html', {'magazine': magazine, 'action': 'Edit'})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@require_POST
def magazine_delete(request, pk):
    magazine = get_object_or_404(MagazineEdition, pk=pk)
    title = magazine.title
    log_admin_action(request, 'delete', 'MagazineEdition', object_id=pk, object_repr=title)
    magazine.delete()
    messages.success(request, 'Magazine deleted successfully!')
    return redirect('custom_admin:magazines_list')


# ═══════════════════════════════════════════════════════════════
#  FEATURE CARDS
# ═══════════════════════════════════════════════════════════════

@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def feature_cards_list(request):
    cards = FeatureCard.objects.all().order_by('order')
    return render(request, 'custom_admin/feature_cards/list.html', {'cards': cards})


def _save_feature_card_children(request, card):
    """Save key points, impact areas, and media from form arrays."""
    # --- Key Points ---
    card.key_point_items.all().delete()
    kp_texts = request.POST.getlist('kp_text[]')
    kp_texts_fr = request.POST.getlist('kp_text_fr[]')
    for i, text in enumerate(kp_texts):
        text = text.strip()
        if not text:
            continue
        FeatureCardKeyPoint.objects.create(
            feature_card=card,
            text=text,
            text_fr=kp_texts_fr[i].strip() if i < len(kp_texts_fr) else '',
            order=i,
        )

    # --- Impact Areas ---
    card.impact_area_items.all().delete()
    ia_icons = request.POST.getlist('ia_icon[]')
    ia_titles = request.POST.getlist('ia_title[]')
    ia_titles_fr = request.POST.getlist('ia_title_fr[]')
    ia_descs = request.POST.getlist('ia_desc[]')
    ia_descs_fr = request.POST.getlist('ia_desc_fr[]')
    for i, title in enumerate(ia_titles):
        title = title.strip()
        if not title:
            continue
        FeatureCardImpactArea.objects.create(
            feature_card=card,
            icon_name=ia_icons[i] if i < len(ia_icons) else 'stars',
            title=title,
            title_fr=ia_titles_fr[i].strip() if i < len(ia_titles_fr) else '',
            description=ia_descs[i].strip() if i < len(ia_descs) else '',
            description_fr=ia_descs_fr[i].strip() if i < len(ia_descs_fr) else '',
            order=i,
        )

    # --- Media ---
    card.media.all().delete()
    media_types = request.POST.getlist('media_type[]')
    media_urls = request.POST.getlist('media_url[]')
    media_captions = request.POST.getlist('media_caption[]')
    media_captions_fr = request.POST.getlist('media_caption_fr[]')
    # Map file inputs by index (image uploads or video uploads)
    media_file_map = {}
    for key, f in request.FILES.items():
        if key.startswith('media_file_'):
            try:
                idx = int(key.replace('media_file_', ''))
                media_file_map[idx] = f
            except ValueError:
                pass

    for i, mtype in enumerate(media_types):
        mtype = mtype.strip()
        if not mtype:
            continue
        url = media_urls[i].strip() if i < len(media_urls) else ''
        caption = media_captions[i].strip() if i < len(media_captions) else ''
        caption_fr = media_captions_fr[i].strip() if i < len(media_captions_fr) else ''
        uploaded_file = media_file_map.get(i)

        # Need at least a file or a URL
        if not uploaded_file and not url:
            continue

        kwargs = {
            'feature_card': card,
            'media_type': mtype,
            'caption': caption,
            'caption_fr': caption_fr,
            'order': i,
        }
        if mtype == 'image':
            if uploaded_file:
                kwargs['image'] = uploaded_file
            else:
                kwargs['image_url'] = url
        else:  # video
            if uploaded_file:
                kwargs['video_file'] = uploaded_file
            else:
                kwargs['video_url'] = url

        FeatureCardMedia.objects.create(**kwargs)


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@_catch_upload_errors
def feature_card_create(request):
    if request.method == 'POST':
        card = FeatureCard.objects.create(
            title=request.POST.get('title'),
            title_fr=request.POST.get('title_fr', ''),
            description=request.POST.get('description', ''),
            description_fr=request.POST.get('description_fr', ''),
            image=_get_existing_or_uploaded(request, 'image'),
            icon_image=_get_existing_or_uploaded(request, 'icon_image'),
            icon_name=request.POST.get('icon_name', ''),
            gradient_start=request.POST.get('gradient_start', '#1EB53A'),
            gradient_end=request.POST.get('gradient_end', '#4CAF50'),
            overview=request.POST.get('overview', ''),
            overview_fr=request.POST.get('overview_fr', ''),
            extra_content=request.POST.get('extra_content', ''),
            extra_content_fr=request.POST.get('extra_content_fr', ''),
            action_type=request.POST.get('action_type', 'none'),
            action_value=request.POST.get('action_value', ''),
            order=request.POST.get('order', 0),
            is_active=request.POST.get('is_active') == 'on',
        )
        _save_feature_card_children(request, card)
        messages.success(request, 'Feature card created successfully!')
        return redirect('custom_admin:feature_cards_list')
    icon_choices = FeatureCard.ICON_CHOICES
    return render(request, 'custom_admin/feature_cards/form.html', {'action': 'Create', 'icon_choices': icon_choices})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@_catch_upload_errors
def feature_card_edit(request, pk):
    card = get_object_or_404(FeatureCard, pk=pk)
    if request.method == 'POST':
        card.title = request.POST.get('title')
        card.title_fr = request.POST.get('title_fr', '')
        card.description = request.POST.get('description', '')
        card.description_fr = request.POST.get('description_fr', '')
        _img = _get_existing_or_uploaded(request, 'image')
        if _img:
            card.image = _img
        _icon = _get_existing_or_uploaded(request, 'icon_image')
        if _icon:
            card.icon_image = _icon
        card.icon_name = request.POST.get('icon_name', '')
        card.gradient_start = request.POST.get('gradient_start', '#1EB53A')
        card.gradient_end = request.POST.get('gradient_end', '#4CAF50')
        card.overview = request.POST.get('overview', '')
        card.overview_fr = request.POST.get('overview_fr', '')
        card.extra_content = request.POST.get('extra_content', '')
        card.extra_content_fr = request.POST.get('extra_content_fr', '')
        card.order = request.POST.get('order', 0)
        card.action_type = request.POST.get('action_type', 'none')
        card.action_value = request.POST.get('action_value', '')
        card.is_active = request.POST.get('is_active') == 'on'
        card.save()
        _save_feature_card_children(request, card)
        messages.success(request, 'Feature card updated successfully!')
        return redirect('custom_admin:feature_cards_list')
    icon_choices = FeatureCard.ICON_CHOICES
    key_points = list(card.key_point_items.all().values('text', 'text_fr'))
    impact_areas = list(card.impact_area_items.all().values('icon_name', 'title', 'title_fr', 'description', 'description_fr'))
    media_items = [
        {
            'media_type': m.media_type,
            'effective_url': m.effective_image_url if m.media_type == 'image' else m.effective_video_url,
            'caption': m.caption,
            'caption_fr': m.caption_fr,
        }
        for m in card.media.all()
    ]
    return render(request, 'custom_admin/feature_cards/form.html', {
        'card': card,
        'action': 'Edit',
        'icon_choices': icon_choices,
        'key_points': key_points,
        'impact_areas': impact_areas,
        'media_items': media_items,
    })


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@require_POST
def feature_card_delete(request, pk):
    card = get_object_or_404(FeatureCard, pk=pk)
    card.delete()
    messages.success(request, 'Feature card deleted successfully!')
    return redirect('custom_admin:feature_cards_list')


# ═══════════════════════════════════════════════════════════════
#  EVENT REGISTRATIONS (Event / Holiday Cards)
# ═══════════════════════════════════════════════════════════════

@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def event_registrations_list(request):
    registrations = EventRegistration.objects.all().annotate(
        submission_count=Count('submissions')
    )
    card_type_filter = request.GET.get('type')
    if card_type_filter:
        registrations = registrations.filter(card_type=card_type_filter)
    return render(request, 'custom_admin/event_registrations/list.html', {
        'registrations': registrations,
        'current_filter': card_type_filter or '',
    })


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def _save_form_fields(request, reg):
    """Parse and save inline form fields from the event registration form."""
    import json as _json
    # Delete removed fields
    existing_ids = set(reg.form_fields.values_list('id', flat=True))
    kept_ids = set()
    idx = 0
    while True:
        prefix = f'field_{idx}_'
        field_type = request.POST.get(f'{prefix}type')
        if field_type is None:
            break
        field_id = request.POST.get(f'{prefix}id')
        field_label = request.POST.get(f'{prefix}label', '')
        field_label_fr = request.POST.get(f'{prefix}label_fr', '')
        field_name = request.POST.get(f'{prefix}name', '')
        placeholder = request.POST.get(f'{prefix}placeholder', '')
        placeholder_fr = request.POST.get(f'{prefix}placeholder_fr', '')
        is_required = request.POST.get(f'{prefix}required') == 'on'
        is_active = request.POST.get(f'{prefix}active') == 'on'
        help_text = request.POST.get(f'{prefix}help_text', '')
        help_text_fr = request.POST.get(f'{prefix}help_text_fr', '')
        options_str = request.POST.get(f'{prefix}options', '')
        validation_regex = request.POST.get(f'{prefix}validation_regex', '')
        order = idx

        # Parse options: comma-separated or JSON array
        options = []
        if options_str.strip():
            try:
                options = _json.loads(options_str)
            except (ValueError, TypeError):
                options = [o.strip() for o in options_str.split(',') if o.strip()]

        data = {
            'event_registration': reg,
            'field_type': field_type,
            'field_label': field_label,
            'field_label_fr': field_label_fr,
            'field_name': field_name,
            'placeholder': placeholder,
            'placeholder_fr': placeholder_fr,
            'is_required': is_required,
            'is_active': is_active,
            'options': options,
            'help_text': help_text,
            'help_text_fr': help_text_fr,
            'validation_regex': validation_regex,
            'order': order,
        }

        if field_id and field_id.isdigit():
            fid = int(field_id)
            RegistrationFormField.objects.filter(pk=fid, event_registration=reg).update(**{
                k: v for k, v in data.items() if k != 'event_registration'
            })
            kept_ids.add(fid)
        else:
            obj = RegistrationFormField.objects.create(**data)
            kept_ids.add(obj.pk)
        idx += 1

    # Delete fields that were removed
    to_delete = existing_ids - kept_ids
    if to_delete:
        RegistrationFormField.objects.filter(pk__in=to_delete).delete()


def _save_event_photos(request, reg):
    """Handle photo uploads and deletions for an event registration."""
    # Delete photos marked for removal
    delete_ids = request.POST.getlist('delete_photo')
    if delete_ids:
        EventPhoto.objects.filter(
            pk__in=delete_ids, event_registration=reg
        ).delete()

    # Save new photo uploads
    idx = 0
    while True:
        photo_file = request.FILES.get(f'event_photo_{idx}')
        if photo_file is None:
            break
        caption = request.POST.get(f'event_photo_caption_{idx}', '')
        EventPhoto.objects.create(
            user=request.user,
            event_registration=reg,
            image=photo_file,
            caption=caption,
            is_approved=True,
        )
        idx += 1


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@_catch_upload_errors
def event_registration_create(request):
    if request.method == 'POST':
        reg = EventRegistration.objects.create(
            card_type=request.POST.get('card_type', 'event'),
            event_type=request.POST.get('event_type', 'in_person'),
            category_id=request.POST.get('category') or None,
            event_title=request.POST.get('event_title', ''),
            event_title_fr=request.POST.get('event_title_fr', ''),
            event_description=request.POST.get('event_description', ''),
            event_description_fr=request.POST.get('event_description_fr', ''),
            event_poster=request.FILES.get('event_poster'),
            event_date=request.POST.get('event_date') or None,
            event_end_date=request.POST.get('event_end_date') or None,
            venue=request.POST.get('venue', ''),
            venue_fr=request.POST.get('venue_fr', ''),
            venue_address=request.POST.get('venue_address', ''),
            contact_email=request.POST.get('contact_email', ''),
            contact_phone=request.POST.get('contact_phone', ''),
            is_registration_enabled=request.POST.get('is_registration_enabled') == 'on',
            registration_deadline=request.POST.get('registration_deadline') or None,
            max_registrations=request.POST.get('max_registrations') or 0,
            allow_proxy_registration=request.POST.get('allow_proxy_registration') == 'on',
            send_confirmation_email=request.POST.get('send_confirmation_email') == 'on',
            confirmation_message=request.POST.get('confirmation_message', ''),
            confirmation_message_fr=request.POST.get('confirmation_message_fr', ''),
            show_photos=request.POST.get('show_photos') == 'on',
            show_attendees=request.POST.get('show_attendees') == 'on',
            show_comments=request.POST.get('show_comments') == 'on',
            is_active=request.POST.get('is_active') == 'on',
            order=request.POST.get('order') or 0,
        )
        _save_form_fields(request, reg)
        _save_event_photos(request, reg)
        messages.success(request, 'Event created successfully!')
        return redirect('custom_admin:event_registrations_list')
    import json as _json
    return render(request, 'custom_admin/event_registrations/form.html', {
        'action': 'Create',
        'categories': EventCategory.objects.filter(is_active=True),
        'field_type_choices': _json.dumps(list(RegistrationFormField.FIELD_TYPE_CHOICES)).replace('<', '\\u003c'),
    })


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@_catch_upload_errors
def event_registration_edit(request, pk):
    reg = get_object_or_404(EventRegistration, pk=pk)
    if request.method == 'POST':
        reg.card_type = request.POST.get('card_type', 'event')
        reg.event_type = request.POST.get('event_type', 'in_person')
        reg.category_id = request.POST.get('category') or None
        reg.event_title = request.POST.get('event_title', '')
        reg.event_title_fr = request.POST.get('event_title_fr', '')
        reg.event_description = request.POST.get('event_description', '')
        reg.event_description_fr = request.POST.get('event_description_fr', '')
        if request.FILES.get('event_poster'):
            reg.event_poster = request.FILES.get('event_poster')
        reg.event_date = request.POST.get('event_date') or None
        reg.event_end_date = request.POST.get('event_end_date') or None
        reg.venue = request.POST.get('venue', '')
        reg.venue_fr = request.POST.get('venue_fr', '')
        reg.venue_address = request.POST.get('venue_address', '')
        reg.contact_email = request.POST.get('contact_email', '')
        reg.contact_phone = request.POST.get('contact_phone', '')
        reg.is_registration_enabled = request.POST.get('is_registration_enabled') == 'on'
        reg.registration_deadline = request.POST.get('registration_deadline') or None
        reg.max_registrations = request.POST.get('max_registrations') or 0
        reg.allow_proxy_registration = request.POST.get('allow_proxy_registration') == 'on'
        reg.send_confirmation_email = request.POST.get('send_confirmation_email') == 'on'
        reg.confirmation_message = request.POST.get('confirmation_message', '')
        reg.confirmation_message_fr = request.POST.get('confirmation_message_fr', '')
        reg.show_photos = request.POST.get('show_photos') == 'on'
        reg.show_attendees = request.POST.get('show_attendees') == 'on'
        reg.show_comments = request.POST.get('show_comments') == 'on'
        reg.is_active = request.POST.get('is_active') == 'on'
        reg.order = request.POST.get('order') or 0
        reg.save()
        _save_form_fields(request, reg)
        _save_event_photos(request, reg)
        messages.success(request, 'Event updated successfully!')
        return redirect('custom_admin:event_registrations_list')

    import json as _json
    # Prepare existing fields as JSON for the template
    existing_fields = list(reg.form_fields.order_by('order').values(
        'id', 'field_type', 'field_label', 'field_label_fr', 'field_name',
        'placeholder', 'placeholder_fr', 'is_required', 'is_active',
        'options', 'help_text', 'help_text_fr', 'validation_regex', 'order',
    ))
    existing_photos = list(reg.user_photos.order_by('-created_at').values('id', 'image', 'caption'))
    return render(request, 'custom_admin/event_registrations/form.html', {
        'reg': reg,
        'action': 'Edit',
        'categories': EventCategory.objects.filter(is_active=True),
        'field_type_choices': _json.dumps(list(RegistrationFormField.FIELD_TYPE_CHOICES)).replace('<', '\\u003c'),
        'existing_fields_json': _json.dumps(existing_fields, default=str).replace('<', '\\u003c'),
        'existing_photos': existing_photos,
    })


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def event_registration_submissions(request, pk):
    import csv as _csv
    from django.http import HttpResponse

    reg = get_object_or_404(EventRegistration, pk=pk)
    qs = EventSubmission.objects.filter(event_registration=reg).select_related('user').order_by('-submitted_at')
    status_filter = request.GET.get('status')
    if status_filter:
        qs = qs.filter(status=status_filter)

    # CSV export
    if request.GET.get('export') == 'csv':
        response = HttpResponse(content_type='text/csv')
        response['Content-Disposition'] = f'attachment; filename="submissions_{reg.pk}.csv"'
        # Build field name → label mapping
        field_map = {f.field_name: f.field_label for f in reg.form_fields.all()}
        # Collect all form data keys across submissions
        all_keys = []
        for sub in qs:
            if sub.form_data:
                for k in sub.form_data.keys():
                    if k not in all_keys:
                        all_keys.append(k)

        writer = _csv.writer(response)
        header = ['#', 'User', 'Email', 'Status', 'Submitted At', 'Is Proxy', 'Proxy Name', 'Proxy Email', 'Proxy Email Verified', 'Proxy Phone']
        header += [field_map.get(k, k.replace('_', ' ').title()) for k in all_keys]
        writer.writerow(header)
        for i, sub in enumerate(qs, 1):
            row = [
                i,
                sub.user.username,
                sub.user.email or '',
                sub.get_status_display(),
                sub.submitted_at.strftime('%Y-%m-%d %H:%M'),
                'Yes' if sub.is_proxy else 'No',
                sub.proxy_name or '',
                sub.proxy_email or '',
                'Yes' if sub.proxy_email_verified else ('No' if sub.is_proxy else ''),
                sub.proxy_phone or '',
            ]
            for k in all_keys:
                val = sub.form_data.get(k, '') if sub.form_data else ''
                if isinstance(val, list):
                    val = ', '.join(str(v) for v in val)
                row.append(val)
            writer.writerow(_sanitize_csv_row(row))
        return response

    paginator = Paginator(qs, 20)
    page = request.GET.get('page')
    submissions = paginator.get_page(page)
    return render(request, 'custom_admin/event_registrations/submissions.html', {
        'reg': reg,
        'submissions': submissions,
        'current_filter': status_filter or '',
        'total_count': EventSubmission.objects.filter(event_registration=reg).count(),
        'pending_count': EventSubmission.objects.filter(event_registration=reg, status='pending').count(),
        'approved_count': EventSubmission.objects.filter(event_registration=reg, status='approved').count(),
        'rejected_count': EventSubmission.objects.filter(event_registration=reg, status='rejected').count(),
    })


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def event_submission_review(request, pk):
    submission = get_object_or_404(EventSubmission.objects.select_related('event_registration', 'user', 'reviewed_by'), pk=pk)
    if request.method == 'POST':
        action = request.POST.get('action')
        if action == 'approve':
            submission.status = 'approved'
            submission.admin_notes = request.POST.get('admin_notes', '')
            submission.reviewed_by = request.user
            submission.reviewed_at = timezone.now()
            submission.save()
            messages.success(request, f'Submission from {submission.user.username} approved.')

            # Send approval confirmation email
            if submission.user.email:
                try:
                    from django.core.mail import send_mail
                    event_reg = submission.event_registration
                    user = submission.user

                    subject = f'Registration Approved: {event_reg.event_title}'
                    html_message = f'''<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"></head>
<body style="margin:0;padding:0;background:#f4f6f9;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;">
<div style="max-width:600px;margin:0 auto;padding:40px 20px;">
  <div style="background:white;border-radius:16px;overflow:hidden;box-shadow:0 4px 24px rgba(0,0,0,0.08);">
    <div style="background:linear-gradient(135deg,#1a4731 0%,#276749 100%);padding:40px 32px;text-align:center;">
      <div style="width:60px;height:60px;background:white;border-radius:12px;margin:0 auto 16px;display:flex;align-items:center;justify-content:center;">
        <span style="font-size:28px;font-weight:900;color:#276749;">&#10003;</span>
      </div>
      <h1 style="color:white;font-size:22px;margin:0 0 8px;font-weight:700;">Registration Approved</h1>
      <p style="color:#9ae6b4;font-size:14px;margin:0;">Be 4 Africa 2026-2027</p>
    </div>
    <div style="padding:32px;">
      <p style="color:#2d3748;font-size:16px;line-height:1.6;margin:0 0 20px;">
        Dear <strong>{user.get_full_name() or user.username}</strong>,
      </p>
      <p style="color:#4a5568;font-size:15px;line-height:1.6;margin:0 0 24px;">
        Great news! Your registration for <strong>{event_reg.event_title}</strong> has been approved.
      </p>
      <div style="background:#f0fff4;border-radius:12px;padding:20px;margin:0 0 24px;">
        <h3 style="color:#276749;font-size:14px;margin:0 0 12px;text-transform:uppercase;letter-spacing:0.5px;">Event Details</h3>
        <table style="width:100%;border-collapse:collapse;">
          <tr><td style="padding:6px 0;color:#718096;font-size:14px;">Event</td><td style="padding:6px 0;color:#2d3748;font-size:14px;font-weight:600;">{event_reg.event_title}</td></tr>'''

                    if event_reg.event_date:
                        html_message += f'''
          <tr><td style="padding:6px 0;color:#718096;font-size:14px;">Date</td><td style="padding:6px 0;color:#2d3748;font-size:14px;">{event_reg.event_date.strftime("%B %d, %Y at %H:%M")}</td></tr>'''
                    if event_reg.venue:
                        html_message += f'''
          <tr><td style="padding:6px 0;color:#718096;font-size:14px;">Venue</td><td style="padding:6px 0;color:#2d3748;font-size:14px;">{event_reg.venue}</td></tr>'''

                    html_message += f'''
          <tr><td style="padding:6px 0;color:#718096;font-size:14px;">Status</td><td style="padding:6px 0;color:#38a169;font-size:14px;font-weight:600;">Approved</td></tr>
        </table>
      </div>'''

                    if submission.admin_notes:
                        html_message += f'''
      <div style="background:#fffff0;border-left:4px solid #ecc94b;padding:16px 20px;border-radius:0 8px 8px 0;margin:0 0 24px;">
        <p style="color:#744210;font-size:13px;margin:0 0 4px;font-weight:600;">Note from organizer:</p>
        <p style="color:#744210;font-size:14px;line-height:1.6;margin:0;">{submission.admin_notes}</p>
      </div>'''

                    html_message += f'''
      <p style="color:#4a5568;font-size:15px;line-height:1.6;margin:0 0 24px;">
        You can view your ticket and event details in the Be 4 Africa app.
      </p>
      <p style="color:#718096;font-size:13px;line-height:1.6;margin:0;">
        If you have any questions, please contact us at <a href="mailto:{event_reg.contact_email or "info@burundi4africa.com"}" style="color:#3182ce;">{event_reg.contact_email or "info@burundi4africa.com"}</a>
      </p>
    </div>
    <div style="background:#f7fafc;padding:20px 32px;text-align:center;border-top:1px solid #e2e8f0;">
      <p style="color:#a0aec0;font-size:12px;margin:0;">Republic of Burundi &mdash; Be 4 Africa 2026-2027</p>
    </div>
  </div>
</div>
</body>
</html>'''

                    plain_message = f"Dear {user.get_full_name() or user.username},\n\nYour registration for {event_reg.event_title} has been approved.\n\n"
                    if submission.admin_notes:
                        plain_message += f"Note from organizer: {submission.admin_notes}\n\n"
                    plain_message += "You can view your ticket and event details in the Be 4 Africa app.\n\nBest regards,\nBe 4 Africa Team"

                    send_mail(
                        subject=subject,
                        message=plain_message,
                        from_email=settings.DEFAULT_FROM_EMAIL,
                        recipient_list=[user.email],
                        html_message=html_message,
                        fail_silently=True,
                    )
                except Exception:
                    pass  # Don't fail the review if email fails

            # Send push notification to the user's device(s)
            try:
                import firebase_admin.messaging as fcm_messaging
                from config.firebase import initialize_firebase
                initialize_firebase()
                event_title = submission.event_registration.event_title
                tokens = set(
                    DeviceToken.objects.filter(
                        user=submission.user, is_active=True,
                    ).exclude(token='').values_list('token', flat=True)
                )
                legacy = UserProfile.objects.filter(
                    user=submission.user, fcm_token__isnull=False,
                ).exclude(fcm_token='').values_list('fcm_token', flat=True).first()
                if legacy:
                    tokens.add(legacy)
                for tok in tokens:
                    fcm_messaging.send(fcm_messaging.Message(
                        token=tok,
                        notification=fcm_messaging.Notification(
                            title='Registration Approved',
                            body=f'Your registration for {event_title} has been approved.',
                        ),
                        data={
                            'action_type': 'route',
                            'action_value': '/events',
                            'type': 'event',
                        },
                        android=fcm_messaging.AndroidConfig(
                            priority='high',
                            notification=fcm_messaging.AndroidNotification(
                                channel_id='default_channel',
                                priority='max',
                                default_sound=True,
                                default_vibrate_timings=True,
                            ),
                        ),
                        apns=fcm_messaging.APNSConfig(
                            headers={'apns-priority': '10'},
                            payload=fcm_messaging.APNSPayload(
                                aps=fcm_messaging.Aps(
                                    sound='default',
                                    badge=1,
                                    content_available=True,
                                ),
                            ),
                        ),
                    ))
            except Exception:
                pass  # Push is best-effort — don't fail the review

        elif action == 'reject':
            submission.status = 'rejected'
            submission.admin_notes = request.POST.get('admin_notes', '')
            submission.reviewed_by = request.user
            submission.reviewed_at = timezone.now()
            submission.save()
            messages.success(request, f'Submission from {submission.user.username} rejected.')

            # Send rejection notification email
            if submission.user.email:
                try:
                    from django.core.mail import send_mail
                    event_reg = submission.event_registration
                    user = submission.user

                    subject = f'Registration Update: {event_reg.event_title}'
                    html_message = f'''<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"></head>
<body style="margin:0;padding:0;background:#f4f6f9;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;">
<div style="max-width:600px;margin:0 auto;padding:40px 20px;">
  <div style="background:white;border-radius:16px;overflow:hidden;box-shadow:0 4px 24px rgba(0,0,0,0.08);">
    <div style="background:linear-gradient(135deg,#742a2a 0%,#9b2c2c 100%);padding:40px 32px;text-align:center;">
      <div style="width:60px;height:60px;background:white;border-radius:12px;margin:0 auto 16px;display:flex;align-items:center;justify-content:center;">
        <span style="font-size:28px;font-weight:900;color:#9b2c2c;">!</span>
      </div>
      <h1 style="color:white;font-size:22px;margin:0 0 8px;font-weight:700;">Registration Not Approved</h1>
      <p style="color:#feb2b2;font-size:14px;margin:0;">Be 4 Africa 2026-2027</p>
    </div>
    <div style="padding:32px;">
      <p style="color:#2d3748;font-size:16px;line-height:1.6;margin:0 0 20px;">
        Dear <strong>{user.get_full_name() or user.username}</strong>,
      </p>
      <p style="color:#4a5568;font-size:15px;line-height:1.6;margin:0 0 24px;">
        We regret to inform you that your registration for <strong>{event_reg.event_title}</strong> could not be approved at this time.
      </p>'''

                    if submission.admin_notes:
                        html_message += f'''
      <div style="background:#fff5f5;border-left:4px solid #fc8181;padding:16px 20px;border-radius:0 8px 8px 0;margin:0 0 24px;">
        <p style="color:#742a2a;font-size:13px;margin:0 0 4px;font-weight:600;">Reason:</p>
        <p style="color:#742a2a;font-size:14px;line-height:1.6;margin:0;">{submission.admin_notes}</p>
      </div>'''

                    html_message += f'''
      <p style="color:#4a5568;font-size:15px;line-height:1.6;margin:0 0 24px;">
        If you believe this was made in error or have any questions, please don't hesitate to reach out.
      </p>
      <p style="color:#718096;font-size:13px;line-height:1.6;margin:0;">
        Contact us at <a href="mailto:{event_reg.contact_email or "info@burundi4africa.com"}" style="color:#3182ce;">{event_reg.contact_email or "info@burundi4africa.com"}</a>
      </p>
    </div>
    <div style="background:#f7fafc;padding:20px 32px;text-align:center;border-top:1px solid #e2e8f0;">
      <p style="color:#a0aec0;font-size:12px;margin:0;">Republic of Burundi &mdash; Be 4 Africa 2026-2027</p>
    </div>
  </div>
</div>
</body>
</html>'''

                    plain_message = f"Dear {user.get_full_name() or user.username},\n\nWe regret to inform you that your registration for {event_reg.event_title} could not be approved at this time.\n\n"
                    if submission.admin_notes:
                        plain_message += f"Reason: {submission.admin_notes}\n\n"
                    plain_message += f"If you have any questions, please contact us at {event_reg.contact_email or 'info@burundi4africa.com'}.\n\nBest regards,\nBe 4 Africa Team"

                    send_mail(
                        subject=subject,
                        message=plain_message,
                        from_email=settings.DEFAULT_FROM_EMAIL,
                        recipient_list=[user.email],
                        html_message=html_message,
                        fail_silently=True,
                    )
                except Exception:
                    pass  # Don't fail the review if email fails

            # Send push notification to the user's device(s)
            try:
                import firebase_admin.messaging as fcm_messaging
                from config.firebase import initialize_firebase
                initialize_firebase()
                event_title = submission.event_registration.event_title
                tokens = set(
                    DeviceToken.objects.filter(
                        user=submission.user, is_active=True,
                    ).exclude(token='').values_list('token', flat=True)
                )
                legacy = UserProfile.objects.filter(
                    user=submission.user, fcm_token__isnull=False,
                ).exclude(fcm_token='').values_list('fcm_token', flat=True).first()
                if legacy:
                    tokens.add(legacy)
                for tok in tokens:
                    fcm_messaging.send(fcm_messaging.Message(
                        token=tok,
                        notification=fcm_messaging.Notification(
                            title='Registration Not Approved',
                            body=f'Your registration for {event_title} was not approved. Open the app for details.',
                        ),
                        data={
                            'action_type': 'route',
                            'action_value': '/events',
                            'type': 'event',
                        },
                        android=fcm_messaging.AndroidConfig(
                            priority='high',
                            notification=fcm_messaging.AndroidNotification(
                                channel_id='default_channel',
                                priority='max',
                                default_sound=True,
                                default_vibrate_timings=True,
                            ),
                        ),
                        apns=fcm_messaging.APNSConfig(
                            headers={'apns-priority': '10'},
                            payload=fcm_messaging.APNSPayload(
                                aps=fcm_messaging.Aps(
                                    sound='default',
                                    badge=1,
                                    content_available=True,
                                ),
                            ),
                        ),
                    ))
            except Exception:
                pass  # Push is best-effort — don't fail the review

        return redirect('custom_admin:event_registration_submissions', pk=submission.event_registration.pk)

    # Map field_name → field_label for friendly display
    field_map = {f.field_name: f.field_label for f in submission.event_registration.form_fields.all()}
    field_labels = {}
    if submission.form_data:
        from collections import OrderedDict
        field_labels = OrderedDict()
        for key, value in submission.form_data.items():
            friendly = field_map.get(key, key.replace('_', ' ').title())
            # Format list values (multi_checkbox)
            if isinstance(value, list):
                value = ', '.join(str(v) for v in value)
            field_labels[friendly] = value

    return render(request, 'custom_admin/event_registrations/submission_review.html', {
        'submission': submission,
        'field_labels': field_labels,
    })


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@require_POST
def event_registration_delete(request, pk):
    reg = get_object_or_404(EventRegistration, pk=pk)
    reg.delete()
    messages.success(request, 'Event/Holiday card deleted successfully!')
    return redirect('custom_admin:event_registrations_list')


# ═══════════════════════════════════════════════════════════════
#  QUICK ACCESS MENU
# ═══════════════════════════════════════════════════════════════

@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def quick_access_list(request):
    items = QuickAccessMenuItem.objects.all().order_by('order')
    return render(request, 'custom_admin/quick_access/list.html', {'items': items})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def quick_access_create(request):
    if request.method == 'POST':
        QuickAccessMenuItem.objects.create(
            title_en=request.POST.get('title_en'),
            title_fr=request.POST.get('title_fr', ''),
            icon_name=request.POST.get('icon_name'),
            action_type=request.POST.get('action_type', 'route'),
            action_value=request.POST.get('action_value'),
            order=request.POST.get('order', 0),
            is_active=request.POST.get('is_active') == 'on',
            has_live_indicator=request.POST.get('has_live_indicator') == 'on',
            badge_text=request.POST.get('badge_text', ''),
        )
        messages.success(request, 'Quick access item created successfully!')
        return redirect('custom_admin:quick_access_list')
    return render(request, 'custom_admin/quick_access/form.html', {'action': 'Create'})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def quick_access_edit(request, pk):
    item = get_object_or_404(QuickAccessMenuItem, pk=pk)
    if request.method == 'POST':
        item.title_en = request.POST.get('title_en')
        item.title_fr = request.POST.get('title_fr', '')
        item.icon_name = request.POST.get('icon_name')
        item.action_type = request.POST.get('action_type', 'route')
        item.action_value = request.POST.get('action_value')
        item.order = request.POST.get('order', 0)
        item.is_active = request.POST.get('is_active') == 'on'
        item.has_live_indicator = request.POST.get('has_live_indicator') == 'on'
        item.badge_text = request.POST.get('badge_text', '')
        item.save()
        messages.success(request, 'Quick access item updated successfully!')
        return redirect('custom_admin:quick_access_list')
    return render(request, 'custom_admin/quick_access/form.html', {'item': item, 'action': 'Edit'})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@require_POST
def quick_access_delete(request, pk):
    item = get_object_or_404(QuickAccessMenuItem, pk=pk)
    item.delete()
    messages.success(request, 'Quick access item deleted successfully!')
    return redirect('custom_admin:quick_access_list')


# ═══════════════════════════════════════════════════════════════
#  PRIORITY AGENDAS
# ═══════════════════════════════════════════════════════════════

@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def priority_agendas_list(request):
    agendas = PriorityAgenda.objects.all()
    return render(request, 'custom_admin/priority_agendas/list.html', {'agendas': agendas})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@_catch_upload_errors
def priority_agenda_create(request):
    if request.method == 'POST':
        from django.utils.text import slugify
        title = request.POST.get('title')
        PriorityAgenda.objects.create(
            title=title,
            title_fr=request.POST.get('title_fr', ''),
            slug=slugify(title),
            description=request.POST.get('description', ''),
            description_fr=request.POST.get('description_fr', ''),
            overview=request.POST.get('overview', ''),
            overview_fr=request.POST.get('overview_fr', ''),
            icon_name=request.POST.get('icon_name', 'stars'),
            hero_image=request.FILES.get('hero_image'),
            is_active=request.POST.get('is_active') == 'on',
        )
        messages.success(request, 'Priority agenda created successfully!')
        return redirect('custom_admin:priority_agendas_list')
    return render(request, 'custom_admin/priority_agendas/form.html', {'action': 'Create'})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@_catch_upload_errors
def priority_agenda_edit(request, pk):
    agenda = get_object_or_404(PriorityAgenda, pk=pk)
    if request.method == 'POST':
        from django.utils.text import slugify
        agenda.title = request.POST.get('title')
        agenda.title_fr = request.POST.get('title_fr', '')
        agenda.slug = slugify(agenda.title)
        agenda.description = request.POST.get('description', '')
        agenda.description_fr = request.POST.get('description_fr', '')
        agenda.overview = request.POST.get('overview', '')
        agenda.overview_fr = request.POST.get('overview_fr', '')
        agenda.icon_name = request.POST.get('icon_name', 'stars')
        if request.FILES.get('hero_image'):
            agenda.hero_image = request.FILES.get('hero_image')
        agenda.is_active = request.POST.get('is_active') == 'on'
        agenda.save()
        messages.success(request, 'Priority agenda updated successfully!')
        return redirect('custom_admin:priority_agendas_list')
    return render(request, 'custom_admin/priority_agendas/form.html', {'agenda': agenda, 'action': 'Edit'})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@require_POST
def priority_agenda_delete(request, pk):
    agenda = get_object_or_404(PriorityAgenda, pk=pk)
    agenda.delete()
    messages.success(request, 'Priority agenda deleted successfully!')
    return redirect('custom_admin:priority_agendas_list')


# ═══════════════════════════════════════════════════════════════
#  GALLERY
# ═══════════════════════════════════════════════════════════════

@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def gallery_list(request):
    albums = GalleryAlbum.objects.all().annotate(actual_photo_count=Count('photos')).order_by('-created_at')
    return render(request, 'custom_admin/gallery/list.html', {'albums': albums})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@_catch_upload_errors
def gallery_create(request):
    if request.method == 'POST':
        content_status = request.POST.get('content_status', 'published')
        scheduled_publish_date = request.POST.get('scheduled_publish_date') or None
        album = GalleryAlbum.objects.create(
            title=request.POST.get('title'),
            title_fr=request.POST.get('title_fr', ''),
            description=request.POST.get('description', ''),
            description_fr=request.POST.get('description_fr', ''),
            cover_image=_get_existing_or_uploaded(request, 'cover_image'),
            is_featured=request.POST.get('is_featured') == 'on',
            status=content_status,
            scheduled_publish_date=scheduled_publish_date,
        )
        # Handle multiple photo uploads
        photos = request.FILES.getlist('photos')
        for i, photo in enumerate(photos):
            GalleryPhoto.objects.create(album=album, image=photo, display_order=i)
        album.photo_count = len(photos)
        album.save()
        messages.success(request, f'Album created with {len(photos)} photos!')
        return redirect('custom_admin:gallery_list')
    return render(request, 'custom_admin/gallery/form.html', {'action': 'Create'})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@_catch_upload_errors
def gallery_edit(request, pk):
    album = get_object_or_404(GalleryAlbum, pk=pk)
    if request.method == 'POST':
        album.title = request.POST.get('title')
        album.title_fr = request.POST.get('title_fr', '')
        album.description = request.POST.get('description', '')
        album.description_fr = request.POST.get('description_fr', '')
        _ci = _get_existing_or_uploaded(request, 'cover_image')
        if _ci:
            album.cover_image = _ci
        album.is_featured = request.POST.get('is_featured') == 'on'
        album.status = request.POST.get('content_status', 'published')
        album.scheduled_publish_date = request.POST.get('scheduled_publish_date') or None
        # Delete selected photos
        delete_ids = request.POST.getlist('delete_photos')
        if delete_ids:
            album.photos.filter(id__in=delete_ids).delete()
        # Handle new photo uploads
        photos = request.FILES.getlist('photos')
        existing_count = album.photos.count()
        for i, photo in enumerate(photos):
            GalleryPhoto.objects.create(album=album, image=photo, display_order=existing_count + i)
        album.photo_count = album.photos.count()
        album.save()
        messages.success(request, 'Album updated successfully!')
        return redirect('custom_admin:gallery_list')
    return render(request, 'custom_admin/gallery/form.html', {'album': album, 'action': 'Edit'})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@require_POST
def gallery_delete(request, pk):
    album = get_object_or_404(GalleryAlbum, pk=pk)
    album.delete()
    messages.success(request, 'Album deleted successfully!')
    return redirect('custom_admin:gallery_list')


# ═══════════════════════════════════════════════════════════════
#  VIDEOS
# ═══════════════════════════════════════════════════════════════

@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def videos_list(request):
    videos = Video.objects.all().order_by('-created_at')
    paginator = Paginator(videos, 20)
    page = request.GET.get('page')
    videos = paginator.get_page(page)
    return render(request, 'custom_admin/videos/list.html', {'videos': videos})



def _save_video_chapters(request, video):
    """Save inline video chapters from the form POST data."""
    video.chapters.all().delete()
    titles = request.POST.getlist('chapter_title[]')
    titles_fr = request.POST.getlist('chapter_title_fr[]')
    timestamps = request.POST.getlist('chapter_timestamp[]')
    descriptions = request.POST.getlist('chapter_description[]')
    descriptions_fr = request.POST.getlist('chapter_description_fr[]')
    for i, title in enumerate(titles):
        if not title.strip():
            continue
        # Parse MM:SS or HH:MM:SS timestamp to seconds
        ts_raw = timestamps[i] if i < len(timestamps) else '0:00'
        try:
            parts = ts_raw.strip().split(':')
            if len(parts) == 2:
                ts_seconds = int(parts[0]) * 60 + int(parts[1])
            elif len(parts) == 3:
                ts_seconds = int(parts[0]) * 3600 + int(parts[1]) * 60 + int(parts[2])
            else:
                ts_seconds = int(ts_raw)
        except (ValueError, IndexError):
            ts_seconds = 0
        VideoChapter.objects.create(
            video=video,
            title=title.strip(),
            title_fr=(titles_fr[i] if i < len(titles_fr) else '').strip(),
            timestamp_seconds=ts_seconds,
            description=(descriptions[i] if i < len(descriptions) else '').strip(),
            description_fr=(descriptions_fr[i] if i < len(descriptions_fr) else '').strip(),
            order=i,
        )


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@_catch_upload_errors
def video_create(request):
    if request.method == 'POST':
        content_status = request.POST.get('content_status', 'published')
        scheduled_publish_date = request.POST.get('scheduled_publish_date') or None
        thumbnail = _get_existing_or_uploaded(request, 'thumbnail')
        video_url = request.POST.get('video_url', '')
        # Auto-fetch YouTube thumbnail if none provided
        if not thumbnail and video_url:
            thumbnail = _fetch_youtube_thumbnail(video_url)
        video = Video.objects.create(
            title=request.POST.get('title'),
            title_fr=request.POST.get('title_fr', ''),
            description=request.POST.get('description', ''),
            description_fr=request.POST.get('description_fr', ''),
            video_url=video_url,
            thumbnail=thumbnail,
            duration=request.POST.get('duration', ''),
            category=request.POST.get('category', 'highlight'),
            publish_date=request.POST.get('publish_date') or timezone.now(),
            is_featured=request.POST.get('is_featured') == 'on',
            status=content_status,
            scheduled_publish_date=scheduled_publish_date,
        )
        if request.FILES.get('video_file'):
            video.video_file = request.FILES['video_file']
            video.save()
        _save_video_chapters(request, video)
        messages.success(request, f'Video created as {content_status}!')
        return redirect('custom_admin:videos_list')
    category_choices = Video.CATEGORY_CHOICES
    return render(request, 'custom_admin/videos/form.html', {'action': 'Create', 'category_choices': category_choices, 'prefill_date': request.GET.get('date', '')})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@_catch_upload_errors
def video_edit(request, pk):
    video = get_object_or_404(Video, pk=pk)
    if request.method == 'POST':
        video.title = request.POST.get('title')
        video.title_fr = request.POST.get('title_fr', '')
        video.description = request.POST.get('description', '')
        video.description_fr = request.POST.get('description_fr', '')
        video.video_url = request.POST.get('video_url', '')
        if request.FILES.get('video_file'):
            video.video_file = request.FILES['video_file']
        _th = _get_existing_or_uploaded(request, 'thumbnail')
        if _th:
            video.thumbnail = _th
        elif not video.thumbnail and video.video_url:
            # Auto-fetch YouTube thumbnail if video has none
            _yt_th = _fetch_youtube_thumbnail(video.video_url)
            if _yt_th:
                video.thumbnail = _yt_th
        video.duration = request.POST.get('duration', '')
        video.category = request.POST.get('category', 'highlight')
        video.is_featured = request.POST.get('is_featured') == 'on'
        video.status = request.POST.get('content_status', 'published')
        video.scheduled_publish_date = request.POST.get('scheduled_publish_date') or None
        video.save()
        _save_video_chapters(request, video)
        messages.success(request, 'Video updated successfully!')
        return redirect('custom_admin:videos_list')
    category_choices = Video.CATEGORY_CHOICES
    chapters = video.chapters.all()
    return render(request, 'custom_admin/videos/form.html', {
        'video': video, 'action': 'Edit',
        'category_choices': category_choices, 'chapters': chapters,
    })


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@require_POST
def video_delete(request, pk):
    video = get_object_or_404(Video, pk=pk)
    video.delete()
    messages.success(request, 'Video deleted successfully!')
    return redirect('custom_admin:videos_list')


# ═══════════════════════════════════════════════════════════════
#  LIVE FEEDS
# ═══════════════════════════════════════════════════════════════

@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def live_feeds_list(request):
    feeds = LiveFeed.objects.all().order_by('-created_at')
    return render(request, 'custom_admin/live_feeds/list.html', {'feeds': feeds})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@_catch_upload_errors
def live_feed_create(request):
    if request.method == 'POST':
        content_status = request.POST.get('content_status', 'published')
        scheduled_publish_date = request.POST.get('scheduled_publish_date') or None
        event_id = request.POST.get('event') or None
        LiveFeed.objects.create(
            title=request.POST.get('title'),
            title_fr=request.POST.get('title_fr', ''),
            event_id=event_id,
            stream_url=request.POST.get('stream_url'),
            thumbnail=_get_existing_or_uploaded(request, 'thumbnail'),
            status=request.POST.get('status', 'upcoming'),
            duration=request.POST.get('duration', ''),
            scheduled_time=request.POST.get('scheduled_time') or None,
            content_status=content_status,
            scheduled_publish_date=scheduled_publish_date,
        )
        messages.success(request, f'Live feed created as {content_status}!')
        return redirect('custom_admin:live_feeds_list')
    events = Event.objects.all().order_by('-event_date')
    return render(request, 'custom_admin/live_feeds/form.html', {
        'action': 'Create',
        'events': events,
        'prefill_date': request.GET.get('date', ''),
    })


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@_catch_upload_errors
def live_feed_edit(request, pk):
    feed = get_object_or_404(LiveFeed, pk=pk)
    if request.method == 'POST':
        feed.title = request.POST.get('title')
        feed.title_fr = request.POST.get('title_fr', '')
        feed.event_id = request.POST.get('event') or None
        feed.stream_url = request.POST.get('stream_url')
        _th = _get_existing_or_uploaded(request, 'thumbnail')
        if _th:
            feed.thumbnail = _th
        feed.status = request.POST.get('status', 'upcoming')
        feed.duration = request.POST.get('duration', '')
        feed.scheduled_time = request.POST.get('scheduled_time') or None
        feed.content_status = request.POST.get('content_status', 'published')
        feed.scheduled_publish_date = request.POST.get('scheduled_publish_date') or None
        feed.save()
        messages.success(request, 'Live feed updated successfully!')
        return redirect('custom_admin:live_feeds_list')
    events = Event.objects.all().order_by('-event_date')
    return render(request, 'custom_admin/live_feeds/form.html', {
        'feed': feed,
        'action': 'Edit',
        'events': events,
    })


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@require_POST
def live_feed_delete(request, pk):
    feed = get_object_or_404(LiveFeed, pk=pk)
    feed.delete()
    messages.success(request, 'Live feed deleted successfully!')
    return redirect('custom_admin:live_feeds_list')


# ═══════════════════════════════════════════════════════════════
#  RESOURCES
# ═══════════════════════════════════════════════════════════════

@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def resources_list(request):
    resources = Resource.objects.all().order_by('-created_at')
    paginator = Paginator(resources, 20)
    page = request.GET.get('page')
    resources = paginator.get_page(page)
    return render(request, 'custom_admin/resources/list.html', {'resources': resources})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@_catch_upload_errors
def resource_create(request):
    if request.method == 'POST':
        content_status = request.POST.get('content_status', 'published')
        scheduled_publish_date = request.POST.get('scheduled_publish_date') or None
        Resource.objects.create(
            title=request.POST.get('title'),
            title_fr=request.POST.get('title_fr', ''),
            category=request.POST.get('category', 'official_documents'),
            file=request.FILES.get('file'),
            file_size=request.POST.get('file_size', ''),
            file_type=request.POST.get('file_type', 'pdf'),
            status=content_status,
            scheduled_publish_date=scheduled_publish_date,
        )
        messages.success(request, f'Resource created as {content_status}!')
        return redirect('custom_admin:resources_list')
    return render(request, 'custom_admin/resources/form.html', {'action': 'Create'})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@_catch_upload_errors
def resource_edit(request, pk):
    resource = get_object_or_404(Resource, pk=pk)
    if request.method == 'POST':
        resource.title = request.POST.get('title')
        resource.title_fr = request.POST.get('title_fr', '')
        resource.category = request.POST.get('category', 'official_documents')
        if request.FILES.get('file'):
            resource.file = request.FILES.get('file')
        resource.file_size = request.POST.get('file_size', '')
        resource.file_type = request.POST.get('file_type', 'pdf')
        resource.status = request.POST.get('content_status', 'published')
        resource.scheduled_publish_date = request.POST.get('scheduled_publish_date') or None
        resource.save()
        messages.success(request, 'Resource updated successfully!')
        return redirect('custom_admin:resources_list')
    return render(request, 'custom_admin/resources/form.html', {'resource': resource, 'action': 'Edit'})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@require_POST
def resource_delete(request, pk):
    resource = get_object_or_404(Resource, pk=pk)
    resource.delete()
    messages.success(request, 'Resource deleted successfully!')
    return redirect('custom_admin:resources_list')


# ═══════════════════════════════════════════════════════════════
#  SOCIAL MEDIA LINKS
# ═══════════════════════════════════════════════════════════════

@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def social_media_list(request):
    links = SocialMediaLink.objects.all().order_by('display_order')
    return render(request, 'custom_admin/social_media/list.html', {'links': links})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def social_media_create(request):
    if request.method == 'POST':
        SocialMediaLink.objects.create(
            platform=request.POST.get('platform'),
            display_name=request.POST.get('display_name'),
            display_name_fr=request.POST.get('display_name_fr', ''),
            url=request.POST.get('url'),
            handle=request.POST.get('handle', ''),
            follower_count=request.POST.get('follower_count', ''),
            display_order=request.POST.get('display_order', 0),
            is_active=request.POST.get('is_active') == 'on',
        )
        messages.success(request, 'Social media link created successfully!')
        return redirect('custom_admin:social_media_list')
    return render(request, 'custom_admin/social_media/form.html', {'action': 'Create'})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def social_media_edit(request, pk):
    link = get_object_or_404(SocialMediaLink, pk=pk)
    if request.method == 'POST':
        link.platform = request.POST.get('platform')
        link.display_name = request.POST.get('display_name')
        link.display_name_fr = request.POST.get('display_name_fr', '')
        link.url = request.POST.get('url')
        link.handle = request.POST.get('handle', '')
        link.follower_count = request.POST.get('follower_count', '')
        link.display_order = request.POST.get('display_order', 0)
        link.is_active = request.POST.get('is_active') == 'on'
        link.save()
        messages.success(request, 'Social media link updated successfully!')
        return redirect('custom_admin:social_media_list')
    return render(request, 'custom_admin/social_media/form.html', {'link': link, 'action': 'Edit'})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@require_POST
def social_media_delete(request, pk):
    link = get_object_or_404(SocialMediaLink, pk=pk)
    link.delete()
    messages.success(request, 'Social media link deleted successfully!')
    return redirect('custom_admin:social_media_list')


# ═══════════════════════════════════════════════════════════════
#  WEATHER CITIES
# ═══════════════════════════════════════════════════════════════

@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def weather_cities_list(request):
    cities = WeatherCity.objects.all().order_by('order')
    return render(request, 'custom_admin/weather_cities/list.html', {'cities': cities})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def weather_city_create(request):
    if request.method == 'POST':
        WeatherCity.objects.create(
            name=request.POST.get('name'),
            latitude=request.POST.get('latitude', 0),
            longitude=request.POST.get('longitude', 0),
            background_image=request.FILES.get('background_image'),
            order=request.POST.get('order', 0),
            is_default=request.POST.get('is_default') == 'on',
            is_active=request.POST.get('is_active') == 'on',
        )
        messages.success(request, 'Weather city created successfully!')
        return redirect('custom_admin:weather_cities_list')
    return render(request, 'custom_admin/weather_cities/form.html', {'action': 'Create'})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def weather_city_edit(request, pk):
    city = get_object_or_404(WeatherCity, pk=pk)
    if request.method == 'POST':
        city.name = request.POST.get('name')
        city.latitude = request.POST.get('latitude', 0)
        city.longitude = request.POST.get('longitude', 0)
        if request.FILES.get('background_image'):
            city.background_image = request.FILES.get('background_image')
        city.order = request.POST.get('order', 0)
        city.is_default = request.POST.get('is_default') == 'on'
        city.is_active = request.POST.get('is_active') == 'on'
        city.save()
        messages.success(request, 'Weather city updated successfully!')
        return redirect('custom_admin:weather_cities_list')
    return render(request, 'custom_admin/weather_cities/form.html', {'city': city, 'action': 'Edit'})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@require_POST
def weather_city_delete(request, pk):
    city = get_object_or_404(WeatherCity, pk=pk)
    city.delete()
    messages.success(request, 'Weather city deleted successfully!')
    return redirect('custom_admin:weather_cities_list')


# ═══════════════════════════════════════════════════════════════
#  APP SETTINGS
# ═══════════════════════════════════════════════════════════════

@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def app_settings(request):
    settings = AppSettings.load()
    if request.method == 'POST':
        settings.summit_year = request.POST.get('summit_year', '2026')
        settings.summit_theme = request.POST.get('summit_theme', '')
        settings.summit_theme_fr = request.POST.get('summit_theme_fr', '')
        settings.website_url = request.POST.get('website_url', '')
        settings.facebook_url = request.POST.get('facebook_url', '')
        settings.twitter_url = request.POST.get('twitter_url', '')
        settings.instagram_url = request.POST.get('instagram_url', '')
        settings.app_description = request.POST.get('app_description', '')
        settings.app_description_fr = request.POST.get('app_description_fr', '')
        settings.developer_name = request.POST.get('developer_name', '')
        settings.developer_url = request.POST.get('developer_url', '')
        settings.live_agent_online = request.POST.get('live_agent_online') == 'on'
        settings.bookmarks_enabled = request.POST.get('bookmarks_enabled') == 'on'
        settings.discussions_enabled = request.POST.get('discussions_enabled') == 'on'
        settings.polls_enabled = request.POST.get('polls_enabled') == 'on'
        settings.newsletter_enabled = request.POST.get('newsletter_enabled') == 'on'
        settings.app_store_url = request.POST.get('app_store_url', '')
        settings.play_store_url = request.POST.get('play_store_url', '')
        settings.app_store_id = request.POST.get('app_store_id', '')
        settings.play_store_id = request.POST.get('play_store_id', '')
        settings.countdown_enabled = request.POST.get('countdown_enabled') == 'on'
        settings.countdown_label = request.POST.get('countdown_label', '')
        settings.countdown_label_fr = request.POST.get('countdown_label_fr', '')
        settings.countdown_target_date = request.POST.get('countdown_target_date') or None
        settings.save()
        messages.success(request, 'App settings saved successfully!')
        return redirect('custom_admin:app_settings')
    audit_logs = AuditLogEntry.objects.all()[:20]
    return render(request, 'custom_admin/app_settings/view.html', {'settings': settings, 'audit_logs': audit_logs})


# ═══════════════════════════════════════════════════════════════
#  ANALYTICS
# ═══════════════════════════════════════════════════════════════

# ═══════════════════════════════════════════════════════════════
#  SUPPORT TICKETS
# ═══════════════════════════════════════════════════════════════

@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def support_tickets_list(request):
    tickets = SupportTicket.objects.all().select_related('user', 'assigned_to').order_by('-updated_at')

    # Filters
    status_filter = request.GET.get('status')
    if status_filter:
        tickets = tickets.filter(status=status_filter)
    search = request.GET.get('search')
    if search:
        tickets = tickets.filter(
            Q(subject__icontains=search) | Q(user__email__icontains=search) |
            Q(user__first_name__icontains=search)
        )

    total = SupportTicket.objects.count()
    open_count = SupportTicket.objects.filter(status='open').count()
    in_progress_count = SupportTicket.objects.filter(status='in_progress').count()
    resolved_count = SupportTicket.objects.filter(status='resolved').count()

    paginator = Paginator(tickets, 20)
    page = request.GET.get('page')
    tickets_page = paginator.get_page(page)

    return render(request, 'custom_admin/support/list.html', {
        'tickets': tickets_page,
        'total': total,
        'open_count': open_count,
        'in_progress_count': in_progress_count,
        'resolved_count': resolved_count,
        'current_status': status_filter,
        'search': search or '',
    })


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def support_ticket_detail(request, pk):
    ticket = get_object_or_404(SupportTicket.objects.select_related('user', 'assigned_to'), pk=pk)
    ticket_messages = ticket.messages.select_related('sender').all()
    return render(request, 'custom_admin/support/detail.html', {
        'ticket': ticket,
        'messages': ticket_messages,
    })


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@require_POST
def support_ticket_reply(request, pk):
    ticket = get_object_or_404(SupportTicket, pk=pk)
    message_text = request.POST.get('message', '').strip()

    if not message_text:
        messages.error(request, 'Reply message cannot be empty.')
        return redirect('custom_admin:support_ticket_detail', pk=pk)

    # Create admin reply
    TicketMessage.objects.create(
        ticket=ticket,
        sender=request.user,
        message=message_text,
        is_admin_reply=True,
        is_read=False,
    )

    # Update ticket status
    if ticket.status == 'open':
        ticket.status = 'in_progress'
        ticket.assigned_to = request.user
        ticket.save(update_fields=['status', 'assigned_to'])

    # Send email copy to user
    try:
        from django.core.mail import send_mail
        from django.conf import settings as django_settings
        send_mail(
            subject=f'Re: {ticket.subject} - Support Ticket #{ticket.pk}',
            message=(
                f'Hello {ticket.user.first_name or ticket.user.username},\n\n'
                f'You have a new reply to your support ticket:\n\n'
                f'"{message_text}"\n\n'
                f'Open the Burundi AU app to continue the conversation.\n\n'
                f'Best regards,\n'
                f'Burundi AU Support Team'
            ),
            from_email=django_settings.DEFAULT_FROM_EMAIL,
            recipient_list=[ticket.user.email],
            fail_silently=True,
        )
    except Exception:
        pass  # Don't block reply if email fails

    # Send push notification to user
    try:
        from config.firebase import initialize_firebase
        initialize_firebase()
        from firebase_admin import messaging

        fcm_token = ticket.user.profile.fcm_token if hasattr(ticket.user, 'profile') else ''
        if fcm_token:
            fcm_message = messaging.Message(
                notification=messaging.Notification(
                    title=f'Support Reply: {ticket.subject}',
                    body=message_text[:100],
                ),
                data={
                    'type': 'support_reply',
                    'ticket_id': str(ticket.pk),
                },
                token=fcm_token,
            )
            messaging.send(fcm_message)
    except Exception:
        pass  # Don't block reply if push fails

    messages.success(request, 'Reply sent successfully! User has been notified.')
    return redirect('custom_admin:support_ticket_detail', pk=pk)


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@require_POST
def support_ticket_update_status(request, pk):
    ticket = get_object_or_404(SupportTicket, pk=pk)
    new_status = request.POST.get('status')
    if new_status not in dict(SupportTicket.STATUS_CHOICES):
        messages.error(request, 'Invalid status.')
        return redirect('custom_admin:support_ticket_detail', pk=pk)

    ticket.status = new_status
    if new_status == 'resolved':
        ticket.resolved_at = timezone.now()

        # Send closing template message asking for rating
        closing_msg = (
            'Your support ticket has been resolved. '
            'We hope we were able to help!\n\n'
            'Please rate your experience to help us improve our service. '
            'Thank you for using Be 4 Africa support.'
        )
        TicketMessage.objects.create(
            ticket=ticket,
            sender=request.user,
            message=closing_msg,
            is_admin_reply=True,
            is_read=False,
        )

        # Send email with closing template
        try:
            from django.core.mail import send_mail
            from django.conf import settings as django_settings
            send_mail(
                subject=f'Ticket Resolved: {ticket.subject} - #{ticket.pk}',
                message=(
                    f'Hello {ticket.user.first_name or ticket.user.username},\n\n'
                    f'Your support ticket "#{ticket.pk} - {ticket.subject}" has been resolved.\n\n'
                    f'Please open the Burundi AU app to rate your experience.\n\n'
                    f'If you need further help, you can always open a new ticket.\n\n'
                    f'Best regards,\n'
                    f'Burundi AU Support Team'
                ),
                from_email=django_settings.DEFAULT_FROM_EMAIL,
                recipient_list=[ticket.user.email],
                fail_silently=True,
            )
        except Exception:
            pass

    ticket.save()
    messages.success(request, f'Ticket status updated to {new_status}.')
    return redirect('custom_admin:support_ticket_detail', pk=pk)


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def analytics_dashboard(request):
    from datetime import timedelta
    from django.db.models import Sum
    from django.db.models.functions import TruncMonth
    from core.models import UserSession, Video, GalleryAlbum

    now = timezone.now()

    # User metrics
    total_users = User.objects.count()
    new_7d = User.objects.filter(date_joined__gte=now - timedelta(days=7)).count()
    new_30d = User.objects.filter(date_joined__gte=now - timedelta(days=30)).count()
    active_7d = User.objects.filter(last_login__gte=now - timedelta(days=7)).count()
    active_30d = User.objects.filter(last_login__gte=now - timedelta(days=30)).count()
    active_today = User.objects.filter(last_login__date=now.date()).count()

    # User growth (12 months)
    user_growth = (
        User.objects.filter(date_joined__gte=now - timedelta(days=365))
        .annotate(month=TruncMonth('date_joined'))
        .values('month')
        .annotate(count=Count('id'))
        .order_by('month')
    )
    months = [g['month'].strftime('%b %Y') for g in user_growth]
    month_counts = [g['count'] for g in user_growth]

    # Country analytics — nationality
    nationality_data = list(
        UserProfile.objects.exclude(nationality='')
        .values('nationality')
        .annotate(count=Count('id'))
        .order_by('-count')[:20]
    )
    nat_labels = [d['nationality'] for d in nationality_data]
    nat_counts = [d['count'] for d in nationality_data]

    # Country analytics — IP geolocation
    ip_country_data = list(
        UserSession.objects.exclude(country_code='')
        .values('country_code', 'country_name')
        .annotate(session_count=Count('id'))
        .order_by('-session_count')[:20]
    )
    ip_labels = [d['country_name'] or d['country_code'] for d in ip_country_data]
    ip_counts = [d['session_count'] for d in ip_country_data]

    # Content engagement
    article_views = Article.objects.aggregate(s=Sum('view_count'))['s'] or 0
    article_likes = Article.objects.aggregate(s=Sum('like_count'))['s'] or 0
    magazine_views = MagazineEdition.objects.aggregate(s=Sum('view_count'))['s'] or 0
    magazine_likes = MagazineEdition.objects.aggregate(s=Sum('like_count'))['s'] or 0
    video_views = Video.objects.aggregate(s=Sum('view_count'))['s'] or 0
    video_likes = Video.objects.aggregate(s=Sum('like_count'))['s'] or 0
    album_views = GalleryAlbum.objects.aggregate(s=Sum('view_count'))['s'] or 0
    album_likes = GalleryAlbum.objects.aggregate(s=Sum('like_count'))['s'] or 0

    # Top content
    top_articles = Article.objects.order_by('-view_count')[:5]
    top_magazines = MagazineEdition.objects.order_by('-view_count')[:5]
    top_videos = Video.objects.order_by('-view_count')[:5]

    # Device OS distribution
    os_data = list(
        UserProfile.objects.exclude(device_os='')
        .values('device_os')
        .annotate(count=Count('id'))
        .order_by('-count')[:10]
    )
    os_labels = [d['device_os'] for d in os_data]
    os_counts = [d['count'] for d in os_data]

    # ─── ADVANCED ANALYTICS (features 131-140) ───

    # --- 132. Funnel Analysis ---
    total_registered = total_users
    verified_users = UserProfile.objects.filter(is_verified=True).count()
    try:
        event_registered_users = EventSubmission.objects.values('user').distinct().count()
    except Exception:
        event_registered_users = 0
    funnel_verify_pct = round(verified_users / max(total_registered, 1) * 100, 1)
    funnel_event_pct = round(event_registered_users / max(total_registered, 1) * 100, 1)

    # --- 133. Cohort Analysis (monthly, last 6 months) ---
    cohort_data = list(
        User.objects.filter(date_joined__gte=now - timedelta(days=180))
        .annotate(cohort=TruncMonth('date_joined'))
        .values('cohort')
        .annotate(
            total=Count('id'),
            retained=Count('id', filter=Q(last_login__gte=now - timedelta(days=30)))
        )
        .order_by('cohort')
    )
    # Format cohort dates for template
    for c in cohort_data:
        c['cohort_label'] = c['cohort'].strftime('%b %Y')
        c['retention_pct'] = round(c['retained'] / max(c['total'], 1) * 100, 1)

    # --- 135. Device Analytics (device_type breakdown) ---
    device_type_data = list(
        UserProfile.objects.exclude(device_type='')
        .values('device_type')
        .annotate(count=Count('id'))
        .order_by('-count')[:10]
    )
    device_type_labels = [d['device_type'] for d in device_type_data]
    device_type_counts = [d['count'] for d in device_type_data]

    # --- 137. Event Attendance ---
    try:
        from core.models import EventCheckIn
        total_checkins = EventCheckIn.objects.filter(checked_in=True).count()
    except Exception:
        total_checkins = 0

    total_event_submissions = EventSubmission.objects.count()

    # Per-event registration stats (EventRegistration cards with submission counts)
    event_attendance = list(
        EventRegistration.objects.annotate(
            sub_count=Count('submissions'),
        ).filter(sub_count__gt=0).order_by('-created_at')[:10]
    )

    # --- 138. Admin KPI Dashboard ---
    dau = active_today
    mau = active_30d
    content_published_30d = Article.objects.filter(created_at__gte=now - timedelta(days=30)).count()
    try:
        tickets_resolved_30d = SupportTicket.objects.filter(
            status='resolved',
            updated_at__gte=now - timedelta(days=30)
        ).count()
    except Exception:
        tickets_resolved_30d = 0
    try:
        open_tickets = SupportTicket.objects.filter(status='open').count()
    except Exception:
        open_tickets = 0

    # Staff email recipients for weekly report config
    staff_emails = list(
        User.objects.filter(Q(is_staff=True) | Q(is_superuser=True))
        .exclude(email='')
        .values_list('email', flat=True)
    )

    context = {
        # User metrics
        'total_users': total_users,
        'new_7d': new_7d,
        'new_30d': new_30d,
        'active_7d': active_7d,
        'active_30d': active_30d,
        'active_today': active_today,

        # User growth chart
        'months_json': months,
        'month_counts_json': month_counts,

        # Country data
        'nat_labels_json': nat_labels,
        'nat_counts_json': nat_counts,
        'ip_labels_json': ip_labels,
        'ip_counts_json': ip_counts,

        # Content engagement
        'total_articles': Article.objects.count(),
        'article_views': article_views,
        'article_likes': article_likes,
        'total_magazines': MagazineEdition.objects.count(),
        'magazine_views': magazine_views,
        'magazine_likes': magazine_likes,
        'total_videos': Video.objects.count(),
        'video_views': video_views,
        'video_likes': video_likes,
        'total_albums': GalleryAlbum.objects.count(),
        'album_views': album_views,
        'album_likes': album_likes,

        # Top content
        'top_articles': top_articles,
        'top_magazines': top_magazines,
        'top_videos': top_videos,

        # Device stats
        'os_labels_json': os_labels,
        'os_counts_json': os_counts,

        # --- Advanced Analytics ---

        # Funnel Analysis (132)
        'total_registered': total_registered,
        'verified_users': verified_users,
        'event_registered_users': event_registered_users,
        'funnel_verify_pct': funnel_verify_pct,
        'funnel_event_pct': funnel_event_pct,

        # Cohort Analysis (133)
        'cohort_data': cohort_data,

        # Device Analytics (135)
        'device_type_labels_json': device_type_labels,
        'device_type_counts_json': device_type_counts,

        # Event Attendance (137)
        'total_event_submissions': total_event_submissions,
        'total_checkins': total_checkins,
        'event_attendance': event_attendance,

        # Admin KPI (138)
        'dau': dau,
        'mau': mau,
        'content_published_30d': content_published_30d,
        'tickets_resolved_30d': tickets_resolved_30d,
        'open_tickets': open_tickets,

        # Weekly Report config (139)
        'staff_emails': staff_emails,
    }
    return render(request, 'custom_admin/analytics/dashboard.html', context)


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@require_POST
def analytics_export_pdf(request):
    """Admin dashboard PDF export route."""
    from core.analytics_views import generate_analytics_pdf
    from core.models import AuditLogEntry

    report_type = request.POST.get('report_type', 'marketing')
    month_str = request.POST.get('month', '')

    if report_type not in ('marketing', 'technical', 'diplomacy'):
        from django.http import HttpResponseBadRequest
        return HttpResponseBadRequest('Invalid report type')

    try:
        pdf_bytes = generate_analytics_pdf(report_type, month_str, request.user)
    except Exception as e:
        from django.http import HttpResponseServerError
        return HttpResponseServerError(f'Export failed: {e}')

    AuditLogEntry.objects.create(
        user=request.user,
        action='EXPORT',
        entity_type='AnalyticsReport',
        entity_label=f'{report_type.title()} report ({month_str or "current"})',
        status='success',
    )

    from django.http import HttpResponse
    response = HttpResponse(pdf_bytes, content_type='application/pdf')
    filename = f'burundi_au_{report_type}_report_{month_str or "current"}.pdf'
    response['Content-Disposition'] = f'attachment; filename="{filename}"'
    return response


# ═══════════════════════════════════════════════════════════════
#  NATIONALITY MAP / HEATMAP
# ═══════════════════════════════════════════════════════════════

AFRICAN_REGIONS = {
    'North Africa': {
        'color': '#3b82f6',
        'countries': [
            'Algeria', 'Egypt', 'Libya', 'Mauritania', 'Morocco',
            'Sahrawi Republic', 'Sudan', 'Tunisia',
        ],
    },
    'West Africa': {
        'color': '#22c55e',
        'countries': [
            'Benin', 'Burkina Faso', 'Cape Verde', 'Cabo Verde',
            "Cote d'Ivoire", "Ivory Coast", 'Gambia', 'Ghana', 'Guinea',
            'Guinea-Bissau', 'Liberia', 'Mali', 'Niger', 'Nigeria',
            'Senegal', 'Sierra Leone', 'Togo',
        ],
    },
    'East Africa': {
        'color': '#f97316',
        'countries': [
            'Burundi', 'Comoros', 'Djibouti', 'Eritrea', 'Ethiopia',
            'Kenya', 'Madagascar', 'Mauritius', 'Rwanda', 'Seychelles',
            'Somalia', 'South Sudan', 'Tanzania', 'Uganda',
        ],
    },
    'Central Africa': {
        'color': '#a855f7',
        'countries': [
            'Cameroon', 'Central African Republic', 'Chad', 'Congo',
            'Republic of the Congo', 'Democratic Republic of the Congo',
            'DR Congo', 'DRC', 'Equatorial Guinea', 'Gabon',
            'Sao Tome and Principe',
        ],
    },
    'Southern Africa': {
        'color': '#ef4444',
        'countries': [
            'Angola', 'Botswana', 'Eswatini', 'Swaziland', 'Lesotho',
            'Malawi', 'Mozambique', 'Namibia', 'South Africa', 'Zambia',
            'Zimbabwe',
        ],
    },
}


def _get_region(country_name):
    """Return the African region for a country, or 'Other' if not found."""
    name_lower = country_name.lower().strip()
    for region_name, info in AFRICAN_REGIONS.items():
        for c in info['countries']:
            if c.lower() == name_lower:
                return region_name
    return 'Other'


def _get_region_color(region_name):
    """Return the colour for a region."""
    if region_name in AFRICAN_REGIONS:
        return AFRICAN_REGIONS[region_name]['color']
    return '#64748b'  # slate for "Other"


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def nationality_map(request):
    """Detailed nationality analytics with regional grouping."""
    import json

    total_users = User.objects.count()

    # Full nationality data (no limit)
    raw_data = list(
        UserProfile.objects.exclude(nationality='')
        .exclude(nationality__isnull=True)
        .values('nationality')
        .annotate(count=Count('id'))
        .order_by('-count')
    )

    total_with_nationality = sum(d['count'] for d in raw_data)
    max_count = raw_data[0]['count'] if raw_data else 1

    # Build enriched nationality list
    nationality_data = []
    for d in raw_data:
        region = _get_region(d['nationality'])
        region_color = _get_region_color(region)
        pct = round(d['count'] / total_with_nationality * 100, 1) if total_with_nationality else 0
        bar_width = round(d['count'] / max_count * 100, 1) if max_count else 0
        nationality_data.append({
            'nationality': d['nationality'],
            'count': d['count'],
            'percentage': pct,
            'bar_width': bar_width,
            'region': region,
            'region_color': region_color,
        })

    # Aggregate by region
    region_agg = {}
    for item in nationality_data:
        r = item['region']
        if r not in region_agg:
            region_agg[r] = {'count': 0, 'countries': 0, 'country_list': []}
        region_agg[r]['count'] += item['count']
        region_agg[r]['countries'] += 1
        region_agg[r]['country_list'].append({
            'name': item['nationality'],
            'count': item['count'],
        })

    # Build ordered region list
    region_order = ['East Africa', 'West Africa', 'North Africa', 'Central Africa', 'Southern Africa', 'Other']
    regions = []
    for rname in region_order:
        if rname not in region_agg:
            continue
        info = region_agg[rname]
        pct = round(info['count'] / total_with_nationality * 100, 1) if total_with_nationality else 0
        # Calculate bar widths within region
        region_max = max((c['count'] for c in info['country_list']), default=1)
        for c in info['country_list']:
            c['region_bar_width'] = round(c['count'] / region_max * 100, 1) if region_max else 0
        regions.append({
            'name': rname,
            'color': _get_region_color(rname),
            'count': info['count'],
            'countries': info['countries'],
            'percentage': pct,
            'country_list': sorted(info['country_list'], key=lambda x: x['count'], reverse=True),
        })

    # Summary values
    top_nationality = raw_data[0]['nationality'] if raw_data else 'N/A'
    top_nationality_count = raw_data[0]['count'] if raw_data else 0
    coverage_pct = round(total_with_nationality / total_users * 100, 1) if total_users else 0

    context = {
        'nationality_data': nationality_data,
        'regions': regions,
        'total_nationalities': len(raw_data),
        'total_with_nationality': total_with_nationality,
        'total_users': total_users,
        'top_nationality': top_nationality,
        'top_nationality_count': top_nationality_count,
        'coverage_pct': coverage_pct,
        'nat_labels_json': json.dumps([d['nationality'] for d in nationality_data]),
        'nat_counts_json': json.dumps([d['count'] for d in nationality_data]),
    }
    return render(request, 'custom_admin/analytics/nationality_map.html', context)


# ═══════════════════════════════════════════════════════════════
#  POLLS MANAGEMENT
# ═══════════════════════════════════════════════════════════════

@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def polls_list(request):
    polls = Poll.objects.all().order_by('-created_at')
    active_polls = polls.filter(is_active=True).count()
    total_votes = sum(p.total_votes for p in polls)
    paginator = Paginator(polls, 20)
    page = request.GET.get('page')
    polls = paginator.get_page(page)
    return render(request, 'custom_admin/polls/list.html', {
        'polls': polls,
        'active_polls': active_polls,
        'total_votes': total_votes,
    })


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def poll_create(request):
    if request.method == 'POST':
        poll = Poll.objects.create(
            title=request.POST.get('title'),
            title_fr=request.POST.get('title_fr', ''),
            description=request.POST.get('description', ''),
            description_fr=request.POST.get('description_fr', ''),
            is_anonymous=request.POST.get('is_anonymous') == 'on',
            multiple_choice=request.POST.get('multiple_choice') == 'on',
            is_active=request.POST.get('is_active') == 'on',
            expires_at=request.POST.get('expires_at') or None,
            created_by=request.user,
        )
        # Create options
        options = request.POST.getlist('options[]')
        options_fr = request.POST.getlist('options_fr[]')
        for i, text in enumerate(options):
            if text.strip():
                PollOption.objects.create(
                    poll=poll,
                    text=text.strip(),
                    text_fr=options_fr[i].strip() if i < len(options_fr) else '',
                    display_order=i,
                )
        messages.success(request, 'Poll created successfully!')
        return redirect('custom_admin:polls_list')
    return render(request, 'custom_admin/polls/form.html', {'action': 'Create'})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def poll_edit(request, pk):
    poll = get_object_or_404(Poll, pk=pk)
    if request.method == 'POST':
        poll.title = request.POST.get('title')
        poll.title_fr = request.POST.get('title_fr', '')
        poll.description = request.POST.get('description', '')
        poll.description_fr = request.POST.get('description_fr', '')
        poll.is_anonymous = request.POST.get('is_anonymous') == 'on'
        poll.multiple_choice = request.POST.get('multiple_choice') == 'on'
        poll.is_active = request.POST.get('is_active') == 'on'
        poll.expires_at = request.POST.get('expires_at') or None
        poll.save()
        # Update options: delete existing, re-create
        poll.options.all().delete()
        options = request.POST.getlist('options[]')
        options_fr = request.POST.getlist('options_fr[]')
        for i, text in enumerate(options):
            if text.strip():
                PollOption.objects.create(
                    poll=poll,
                    text=text.strip(),
                    text_fr=options_fr[i].strip() if i < len(options_fr) else '',
                    display_order=i,
                )
        messages.success(request, 'Poll updated successfully!')
        return redirect('custom_admin:polls_list')
    options = poll.options.order_by('display_order')
    return render(request, 'custom_admin/polls/form.html', {'poll': poll, 'options': options, 'action': 'Edit'})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@require_POST
def poll_delete(request, pk):
    poll = get_object_or_404(Poll, pk=pk)
    poll.delete()
    messages.success(request, 'Poll deleted successfully!')
    return redirect('custom_admin:polls_list')


# ═══════════════════════════════════════════════════════════════
#  DISCUSSIONS / FORUMS MODERATION
# ═══════════════════════════════════════════════════════════════

@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def discussions_list(request):
    discussions = Discussion.objects.all().select_related('author').order_by('-is_pinned', '-created_at')
    category_filter = request.GET.get('category')
    if category_filter:
        discussions = discussions.filter(category=category_filter)
    total = discussions.count()
    pinned = discussions.filter(is_pinned=True).count()
    locked = discussions.filter(is_locked=True).count()
    paginator = Paginator(discussions, 20)
    page = request.GET.get('page')
    discussions = paginator.get_page(page)
    return render(request, 'custom_admin/discussions/list.html', {
        'discussions': discussions,
        'total': total,
        'pinned': pinned,
        'locked': locked,
        'category_choices': Discussion.CATEGORY_CHOICES,
        'current_category': category_filter,
    })


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@require_POST
def discussion_toggle_pin(request, pk):
    discussion = get_object_or_404(Discussion, pk=pk)
    discussion.is_pinned = not discussion.is_pinned
    discussion.save()
    action = 'pinned' if discussion.is_pinned else 'unpinned'
    messages.success(request, f'Discussion {action} successfully!')
    return redirect('custom_admin:discussions_list')


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@require_POST
def discussion_toggle_lock(request, pk):
    discussion = get_object_or_404(Discussion, pk=pk)
    discussion.is_locked = not discussion.is_locked
    discussion.save()
    action = 'locked' if discussion.is_locked else 'unlocked'
    messages.success(request, f'Discussion {action} successfully!')
    return redirect('custom_admin:discussions_list')


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@require_POST
def discussion_delete(request, pk):
    discussion = get_object_or_404(Discussion, pk=pk)
    discussion.delete()
    messages.success(request, 'Discussion deleted successfully!')
    return redirect('custom_admin:discussions_list')


# ═══════════════════════════════════════════════════════════════
#  CONTACT DIRECTORY
# ═══════════════════════════════════════════════════════════════

@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def contact_directory_list(request):
    contacts = ContactDirectory.objects.all().order_by('department', 'name')
    departments = contacts.values_list('department', flat=True).distinct()
    return render(request, 'custom_admin/contact_directory/list.html', {
        'contacts': contacts,
        'departments': departments,
        'total': contacts.count(),
    })


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def contact_directory_create(request):
    if request.method == 'POST':
        ContactDirectory.objects.create(
            name=request.POST.get('name'),
            name_fr=request.POST.get('name_fr', ''),
            title=request.POST.get('title', ''),
            title_fr=request.POST.get('title_fr', ''),
            department=request.POST.get('department', ''),
            department_fr=request.POST.get('department_fr', ''),
            email=request.POST.get('email', ''),
            phone=request.POST.get('phone', ''),
            photo=request.FILES.get('photo'),
            is_active=request.POST.get('is_active') == 'on',
            display_order=request.POST.get('display_order', 0) or 0,
        )
        messages.success(request, 'Contact added successfully!')
        return redirect('custom_admin:contact_directory_list')
    return render(request, 'custom_admin/contact_directory/form.html', {'action': 'Create'})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def contact_directory_edit(request, pk):
    contact = get_object_or_404(ContactDirectory, pk=pk)
    if request.method == 'POST':
        contact.name = request.POST.get('name')
        contact.name_fr = request.POST.get('name_fr', '')
        contact.title = request.POST.get('title', '')
        contact.title_fr = request.POST.get('title_fr', '')
        contact.department = request.POST.get('department', '')
        contact.department_fr = request.POST.get('department_fr', '')
        contact.email = request.POST.get('email', '')
        contact.phone = request.POST.get('phone', '')
        if request.FILES.get('photo'):
            contact.photo = request.FILES.get('photo')
        contact.is_active = request.POST.get('is_active') == 'on'
        contact.display_order = request.POST.get('display_order', 0) or 0
        contact.save()
        messages.success(request, 'Contact updated successfully!')
        return redirect('custom_admin:contact_directory_list')
    return render(request, 'custom_admin/contact_directory/form.html', {'contact': contact, 'action': 'Edit'})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@require_POST
def contact_directory_delete(request, pk):
    contact = get_object_or_404(ContactDirectory, pk=pk)
    contact.delete()
    messages.success(request, 'Contact deleted successfully!')
    return redirect('custom_admin:contact_directory_list')


# ═══════════════════════════════════════════════════════════════
#  ANNOUNCEMENT BANNERS
# ═══════════════════════════════════════════════════════════════

@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def announcements_list(request):
    banners = AnnouncementBanner.objects.all().order_by('-created_at')
    active_count = banners.filter(is_active=True).count()
    return render(request, 'custom_admin/announcements/list.html', {
        'banners': banners,
        'active_count': active_count,
    })


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def announcement_create(request):
    if request.method == 'POST':
        AnnouncementBanner.objects.create(
            title=request.POST.get('title'),
            title_fr=request.POST.get('title_fr', ''),
            message=request.POST.get('message', ''),
            message_fr=request.POST.get('message_fr', ''),
            banner_type=request.POST.get('banner_type', 'info'),
            link_url=request.POST.get('link_url', ''),
            action_url=request.POST.get('action_url', ''),
            action_text=request.POST.get('action_text', ''),
            action_text_fr=request.POST.get('action_text_fr', ''),
            is_dismissible=request.POST.get('is_dismissible') == 'on',
            is_active=request.POST.get('is_active') == 'on',
            starts_at=request.POST.get('starts_at') or None,
            ends_at=request.POST.get('ends_at') or None,
        )
        messages.success(request, 'Announcement created successfully!')
        return redirect('custom_admin:announcements_list')
    return render(request, 'custom_admin/announcements/form.html', {'action': 'Create'})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def announcement_edit(request, pk):
    banner = get_object_or_404(AnnouncementBanner, pk=pk)
    if request.method == 'POST':
        banner.title = request.POST.get('title')
        banner.title_fr = request.POST.get('title_fr', '')
        banner.message = request.POST.get('message', '')
        banner.message_fr = request.POST.get('message_fr', '')
        banner.banner_type = request.POST.get('banner_type', 'info')
        banner.link_url = request.POST.get('link_url', '')
        banner.action_url = request.POST.get('action_url', '')
        banner.action_text = request.POST.get('action_text', '')
        banner.action_text_fr = request.POST.get('action_text_fr', '')
        banner.is_dismissible = request.POST.get('is_dismissible') == 'on'
        banner.is_active = request.POST.get('is_active') == 'on'
        banner.starts_at = request.POST.get('starts_at') or None
        banner.ends_at = request.POST.get('ends_at') or None
        banner.save()
        messages.success(request, 'Announcement updated successfully!')
        return redirect('custom_admin:announcements_list')
    return render(request, 'custom_admin/announcements/form.html', {'banner': banner, 'action': 'Edit'})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@require_POST
def announcement_delete(request, pk):
    banner = get_object_or_404(AnnouncementBanner, pk=pk)
    banner.delete()
    messages.success(request, 'Announcement deleted successfully!')
    return redirect('custom_admin:announcements_list')


# ═══════════════════════════════════════════════════════════════
#  EVENT SPEAKERS
# ═══════════════════════════════════════════════════════════════

@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def event_speakers_list(request):
    speakers = EventSpeaker.objects.all().select_related('event').order_by('-created_at')
    event_filter = request.GET.get('event')
    if event_filter:
        speakers = speakers.filter(event_id=event_filter)
    events = Event.objects.all().order_by('-event_date')
    return render(request, 'custom_admin/event_speakers/list.html', {
        'speakers': speakers,
        'events': events,
        'current_event': event_filter,
    })


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@_catch_upload_errors
def event_speaker_create(request):
    if request.method == 'POST':
        EventSpeaker.objects.create(
            event_id=request.POST.get('event'),
            name=request.POST.get('name'),
            title=request.POST.get('title', ''),
            organization=request.POST.get('organization', ''),
            bio=request.POST.get('bio', ''),
            bio_fr=request.POST.get('bio_fr', ''),
            photo=request.FILES.get('photo'),
            topic=request.POST.get('topic', ''),
            topic_fr=request.POST.get('topic_fr', ''),
            display_order=request.POST.get('display_order', 0) or 0,
        )
        messages.success(request, 'Speaker added successfully!')
        return redirect('custom_admin:event_speakers_list')
    events = Event.objects.all().order_by('-event_date')
    return render(request, 'custom_admin/event_speakers/form.html', {'action': 'Create', 'events': events})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@_catch_upload_errors
def event_speaker_edit(request, pk):
    speaker = get_object_or_404(EventSpeaker, pk=pk)
    if request.method == 'POST':
        speaker.event_id = request.POST.get('event')
        speaker.name = request.POST.get('name')
        speaker.title = request.POST.get('title', '')
        speaker.organization = request.POST.get('organization', '')
        speaker.bio = request.POST.get('bio', '')
        speaker.bio_fr = request.POST.get('bio_fr', '')
        if request.FILES.get('photo'):
            speaker.photo = request.FILES.get('photo')
        speaker.topic = request.POST.get('topic', '')
        speaker.topic_fr = request.POST.get('topic_fr', '')
        speaker.display_order = request.POST.get('display_order', 0) or 0
        speaker.save()
        messages.success(request, 'Speaker updated successfully!')
        return redirect('custom_admin:event_speakers_list')
    events = Event.objects.all().order_by('-event_date')
    return render(request, 'custom_admin/event_speakers/form.html', {'speaker': speaker, 'action': 'Edit', 'events': events})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@require_POST
def event_speaker_delete(request, pk):
    speaker = get_object_or_404(EventSpeaker, pk=pk)
    speaker.delete()
    messages.success(request, 'Speaker deleted successfully!')
    return redirect('custom_admin:event_speakers_list')


# ═══════════════════════════════════════════════════════════════
#  ONBOARDING STEPS
# ═══════════════════════════════════════════════════════════════

@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def onboarding_steps_list(request):
    steps = OnboardingStep.objects.all().order_by('order')
    return render(request, 'custom_admin/onboarding/list.html', {'steps': steps})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@_catch_upload_errors
def onboarding_step_create(request):
    if request.method == 'POST':
        OnboardingStep.objects.create(
            title=request.POST.get('title'),
            title_fr=request.POST.get('title_fr', ''),
            description=request.POST.get('description', ''),
            description_fr=request.POST.get('description_fr', ''),
            image=request.FILES.get('image'),
            image_dark=request.FILES.get('image_dark'),
            icon_name=request.POST.get('icon_name', ''),
            order=request.POST.get('order', 0) or 0,
            is_active=request.POST.get('is_active') == 'on',
        )
        messages.success(request, 'Onboarding step created successfully!')
        return redirect('custom_admin:onboarding_steps_list')
    return render(request, 'custom_admin/onboarding/form.html', {'action': 'Create'})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@_catch_upload_errors
def onboarding_step_edit(request, pk):
    step = get_object_or_404(OnboardingStep, pk=pk)
    if request.method == 'POST':
        step.title = request.POST.get('title')
        step.title_fr = request.POST.get('title_fr', '')
        step.description = request.POST.get('description', '')
        step.description_fr = request.POST.get('description_fr', '')
        if request.FILES.get('image'):
            step.image = request.FILES.get('image')
        if request.FILES.get('image_dark'):
            step.image_dark = request.FILES.get('image_dark')
        step.icon_name = request.POST.get('icon_name', '')
        step.order = request.POST.get('order', 0) or 0
        step.is_active = request.POST.get('is_active') == 'on'
        step.save()
        messages.success(request, 'Onboarding step updated successfully!')
        return redirect('custom_admin:onboarding_steps_list')
    return render(request, 'custom_admin/onboarding/form.html', {'step': step, 'action': 'Edit'})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@require_POST
def onboarding_step_delete(request, pk):
    step = get_object_or_404(OnboardingStep, pk=pk)
    step.delete()
    messages.success(request, 'Onboarding step deleted successfully!')
    return redirect('custom_admin:onboarding_steps_list')


# ═══════════════════════════════════════════════════════════════
#  SCHEDULED MAINTENANCE
# ═══════════════════════════════════════════════════════════════

@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def maintenance_list(request):
    windows = ScheduledMaintenance.objects.all().order_by('-starts_at')
    return render(request, 'custom_admin/maintenance/list.html', {'windows': windows})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def maintenance_create(request):
    if request.method == 'POST':
        from django.utils.dateparse import parse_datetime
        from django.utils.timezone import make_aware, is_naive
        starts_at_str = request.POST.get('starts_at', '')
        ends_at_str = request.POST.get('ends_at', '')
        starts_at_dt = parse_datetime(starts_at_str)
        if not starts_at_dt:
            messages.error(request, 'Invalid date format for starts_at.')
            return render(request, 'custom_admin/maintenance/form.html', {'action': 'Create'})
        if is_naive(starts_at_dt):
            starts_at_dt = make_aware(starts_at_dt)
        ends_at_dt = None
        if ends_at_str:
            ends_at_dt = parse_datetime(ends_at_str)
            if not ends_at_dt:
                messages.error(request, 'Invalid date format for ends_at.')
                return render(request, 'custom_admin/maintenance/form.html', {'action': 'Create'})
            if is_naive(ends_at_dt):
                ends_at_dt = make_aware(ends_at_dt)
        window = ScheduledMaintenance.objects.create(
            title=request.POST.get('title'),
            title_fr=request.POST.get('title_fr', ''),
            description=request.POST.get('description', ''),
            description_fr=request.POST.get('description_fr', ''),
            starts_at=starts_at_dt,
            ends_at=ends_at_dt,
            contact_email=request.POST.get('contact_email', ''),
            is_active=request.POST.get('is_active') == 'on',
        )
        if request.FILES.get('image'):
            window.image = request.FILES.get('image')
            window.save()
        messages.success(request, 'Maintenance window created successfully!')
        return redirect('custom_admin:maintenance_list')
    return render(request, 'custom_admin/maintenance/form.html', {'action': 'Create'})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def maintenance_edit(request, pk):
    window = get_object_or_404(ScheduledMaintenance, pk=pk)
    if request.method == 'POST':
        from django.utils.dateparse import parse_datetime
        from django.utils.timezone import make_aware, is_naive
        starts_at_str = request.POST.get('starts_at', '')
        ends_at_str = request.POST.get('ends_at', '')
        starts_at_dt = parse_datetime(starts_at_str)
        if not starts_at_dt:
            messages.error(request, 'Invalid date format for starts_at.')
            return render(request, 'custom_admin/maintenance/form.html', {'window': window, 'action': 'Edit'})
        if is_naive(starts_at_dt):
            starts_at_dt = make_aware(starts_at_dt)
        ends_at_dt = None
        if ends_at_str:
            ends_at_dt = parse_datetime(ends_at_str)
            if not ends_at_dt:
                messages.error(request, 'Invalid date format for ends_at.')
                return render(request, 'custom_admin/maintenance/form.html', {'window': window, 'action': 'Edit'})
            if is_naive(ends_at_dt):
                ends_at_dt = make_aware(ends_at_dt)
        window.title = request.POST.get('title')
        window.title_fr = request.POST.get('title_fr', '')
        window.description = request.POST.get('description', '')
        window.description_fr = request.POST.get('description_fr', '')
        window.starts_at = starts_at_dt
        window.ends_at = ends_at_dt
        window.contact_email = request.POST.get('contact_email', '')
        window.is_active = request.POST.get('is_active') == 'on'
        if request.FILES.get('image'):
            window.image = request.FILES.get('image')
        if request.POST.get('remove_image') == 'on':
            window.image = None
        window.save()
        messages.success(request, 'Maintenance window updated successfully!')
        return redirect('custom_admin:maintenance_list')
    return render(request, 'custom_admin/maintenance/form.html', {'window': window, 'action': 'Edit'})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@require_POST
def maintenance_delete(request, pk):
    window = get_object_or_404(ScheduledMaintenance, pk=pk)
    window.delete()
    messages.success(request, 'Maintenance window deleted successfully!')
    return redirect('custom_admin:maintenance_list')


# ═══════════════════════════════════════════════════════════════
#  PROMOTIONAL SPLASH
# ═══════════════════════════════════════════════════════════════

@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def promotional_splash_list(request):
    splashes = PromotionalSplash.objects.all().order_by('-priority', '-created_at')
    return render(request, 'custom_admin/promotional_splash/list.html', {'splashes': splashes})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def promotional_splash_create(request):
    if request.method == 'POST':
        from django.utils.dateparse import parse_datetime
        from django.utils.timezone import make_aware, is_naive
        starts_at_str = request.POST.get('starts_at', '').replace('T', ' ')
        ends_at_str = request.POST.get('ends_at', '').replace('T', ' ')
        starts_at_dt = parse_datetime(starts_at_str)
        ends_at_dt = parse_datetime(ends_at_str)
        if not starts_at_dt or not ends_at_dt:
            messages.error(request, 'Invalid date format for starts_at or ends_at.')
            return render(request, 'custom_admin/promotional_splash/form.html', {'action': 'Create'})
        if is_naive(starts_at_dt):
            starts_at_dt = make_aware(starts_at_dt)
        if is_naive(ends_at_dt):
            ends_at_dt = make_aware(ends_at_dt)
        if not request.FILES.get('image'):
            messages.error(request, 'An image is required for promotional splashes.')
            return render(request, 'custom_admin/promotional_splash/form.html', {'action': 'Create'})
        splash = PromotionalSplash.objects.create(
            title=request.POST.get('title', ''),
            title_fr=request.POST.get('title_fr', ''),
            image=request.FILES.get('image'),
            action_url=request.POST.get('action_url', ''),
            action_text=request.POST.get('action_text', ''),
            action_text_fr=request.POST.get('action_text_fr', ''),
            auto_close_seconds=int(request.POST.get('auto_close_seconds', 5) or 5),
            starts_at=starts_at_dt,
            ends_at=ends_at_dt,
            is_active=request.POST.get('is_active') == 'on',
            show_once=request.POST.get('show_once') == 'on',
            priority=int(request.POST.get('priority', 0) or 0),
        )
        messages.success(request, f'Promotional splash "{splash.title}" created successfully!')
        return redirect('custom_admin:promotional_splash_list')
    return render(request, 'custom_admin/promotional_splash/form.html', {'action': 'Create'})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def promotional_splash_edit(request, pk):
    splash = get_object_or_404(PromotionalSplash, pk=pk)
    if request.method == 'POST':
        from django.utils.dateparse import parse_datetime
        from django.utils.timezone import make_aware, is_naive
        starts_at_str = request.POST.get('starts_at', '').replace('T', ' ')
        ends_at_str = request.POST.get('ends_at', '').replace('T', ' ')
        starts_at_dt = parse_datetime(starts_at_str)
        ends_at_dt = parse_datetime(ends_at_str)
        if not starts_at_dt or not ends_at_dt:
            messages.error(request, 'Invalid date format for starts_at or ends_at.')
            return render(request, 'custom_admin/promotional_splash/form.html', {'splash': splash, 'action': 'Edit'})
        if is_naive(starts_at_dt):
            starts_at_dt = make_aware(starts_at_dt)
        if is_naive(ends_at_dt):
            ends_at_dt = make_aware(ends_at_dt)
        splash.title = request.POST.get('title', '')
        splash.title_fr = request.POST.get('title_fr', '')
        splash.action_url = request.POST.get('action_url', '')
        splash.action_text = request.POST.get('action_text', '')
        splash.action_text_fr = request.POST.get('action_text_fr', '')
        splash.auto_close_seconds = int(request.POST.get('auto_close_seconds', 5) or 5)
        splash.starts_at = starts_at_dt
        splash.ends_at = ends_at_dt
        splash.is_active = request.POST.get('is_active') == 'on'
        splash.show_once = request.POST.get('show_once') == 'on'
        splash.priority = int(request.POST.get('priority', 0) or 0)
        if request.FILES.get('image'):
            splash.image = request.FILES.get('image')
        if request.POST.get('remove_image') == 'on' and not request.FILES.get('image'):
            messages.error(request, 'Promotional splashes require an image.')
            return render(request, 'custom_admin/promotional_splash/form.html', {'splash': splash, 'action': 'Edit'})
        splash.save()
        messages.success(request, f'Promotional splash "{splash.title}" updated successfully!')
        return redirect('custom_admin:promotional_splash_list')
    return render(request, 'custom_admin/promotional_splash/form.html', {'splash': splash, 'action': 'Edit'})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@require_POST
def promotional_splash_delete(request, pk):
    splash = get_object_or_404(PromotionalSplash, pk=pk)
    splash.delete()
    messages.success(request, 'Promotional splash deleted successfully!')
    return redirect('custom_admin:promotional_splash_list')


# ═══════════════════════════════════════════════════════════════
#  AUDIT LOG
# ═══════════════════════════════════════════════════════════════

@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def admin_audit_log(request):
    """Enhanced audit log with AdminActivityLog (detailed changes, IP, user-agent)."""
    logs = AdminActivityLog.objects.all().select_related('user').order_by('-timestamp')

    # Filters
    user_filter = request.GET.get('user', '').strip()
    action_filter = request.GET.get('action', '').strip()
    model_filter = request.GET.get('model', '').strip()
    date_from = request.GET.get('date_from', '').strip()
    date_to = request.GET.get('date_to', '').strip()

    if user_filter:
        logs = logs.filter(
            Q(user__username__icontains=user_filter) |
            Q(user__email__icontains=user_filter)
        )
    if action_filter:
        logs = logs.filter(action_type=action_filter)
    if model_filter:
        logs = logs.filter(model_name__icontains=model_filter)
    if date_from:
        try:
            from django.utils.dateparse import parse_date
            d = parse_date(date_from)
            if d:
                logs = logs.filter(timestamp__date__gte=d)
        except (ValueError, TypeError):
            pass
    if date_to:
        try:
            from django.utils.dateparse import parse_date
            d = parse_date(date_to)
            if d:
                logs = logs.filter(timestamp__date__lte=d)
        except (ValueError, TypeError):
            pass

    # Export CSV if requested
    if request.GET.get('export') == 'csv':
        response = HttpResponse(content_type='text/csv')
        response['Content-Disposition'] = 'attachment; filename="audit_log_export.csv"'
        writer = csv.writer(response)
        writer.writerow(['Timestamp', 'User', 'Action', 'Model', 'Object ID', 'Object', 'Changes', 'IP Address', 'Path'])
        for log in logs[:5000]:  # Limit export to 5000 rows
            writer.writerow(_sanitize_csv_row([
                log.timestamp.strftime('%Y-%m-%d %H:%M:%S') if log.timestamp else '',
                log.user.username if log.user else 'System',
                log.action_type,
                log.model_name,
                log.object_id or '',
                log.object_repr,
                json.dumps(log.changes) if log.changes else '',
                log.ip_address or '',
                log.path or '',
            ]))
        return response

    # Get distinct values for filter dropdowns
    action_choices = AdminActivityLog.ACTION_TYPE_CHOICES
    entity_types = (
        AdminActivityLog.objects.values_list('model_name', flat=True)
        .exclude(model_name='')
        .distinct()
        .order_by('model_name')
    )

    paginator = Paginator(logs, 30)
    page = request.GET.get('page')
    logs = paginator.get_page(page)

    return render(request, 'custom_admin/audit_log/list.html', {
        'logs': logs,
        'action_choices': action_choices,
        'entity_types': entity_types,
        'current_user_filter': user_filter,
        'current_action_filter': action_filter,
        'current_model_filter': model_filter,
        'current_date_from': date_from,
        'current_date_to': date_to,
    })


# ═══════════════════════════════════════════════════════════════
#  BULK ACTIONS
# ═══════════════════════════════════════════════════════════════

@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@require_POST
def bulk_user_action(request):
    action = request.POST.get('bulk_action')
    user_ids = request.POST.getlist('selected_ids')

    if not user_ids:
        messages.warning(request, 'No users selected.')
        return redirect('custom_admin:users_list')

    users = User.objects.filter(pk__in=user_ids)
    # Prevent bulk actions on superusers
    users = users.filter(is_superuser=False)
    count = users.count()

    if action == 'activate':
        users.update(is_active=True)
        log_admin_action(request, 'bulk_action', 'User', object_repr=f'Bulk activate {count} user(s)',
                         changes={'action': {'old': '', 'new': 'activate'}, 'count': {'old': '', 'new': str(count)}})
        messages.success(request, f'{count} user(s) activated successfully.')
    elif action == 'deactivate':
        users.update(is_active=False)
        log_admin_action(request, 'bulk_action', 'User', object_repr=f'Bulk deactivate {count} user(s)',
                         changes={'action': {'old': '', 'new': 'deactivate'}, 'count': {'old': '', 'new': str(count)}})
        messages.success(request, f'{count} user(s) deactivated successfully.')
    elif action == 'delete':
        if not request.user.is_superuser:
            messages.error(request, 'Only superusers can bulk delete users.')
            return redirect('custom_admin:users_list')
        log_admin_action(request, 'bulk_action', 'User', object_repr=f'Bulk delete {count} user(s)',
                         changes={'action': {'old': '', 'new': 'delete'}, 'count': {'old': '', 'new': str(count)}})
        users.delete()
        messages.success(request, f'{count} user(s) deleted successfully.')
    else:
        messages.error(request, 'Invalid action.')

    return redirect('custom_admin:users_list')


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@require_POST
def bulk_content_action(request):
    action = request.POST.get('bulk_action')
    selected_ids = request.POST.getlist('selected_ids')
    model_type = request.POST.get('model_type', 'article')

    # Map model_type to (Model, display name, list redirect name)
    MODEL_MAP = {
        'article': (Article, 'article', 'custom_admin:articles_list'),
        'magazine': (MagazineEdition, 'magazine', 'custom_admin:magazines_list'),
        'video': (Video, 'video', 'custom_admin:videos_list'),
        'live_feed': (LiveFeed, 'live feed', 'custom_admin:live_feeds_list'),
        'event': (Event, 'event', 'custom_admin:events_list'),
        'gallery': (GalleryAlbum, 'album', 'custom_admin:gallery_list'),
        'feature_card': (FeatureCard, 'feature card', 'custom_admin:feature_cards_list'),
        'hero_slide': (HeroSlide, 'hero slide', 'custom_admin:hero_slides_list'),
    }

    if model_type not in MODEL_MAP:
        messages.error(request, 'Invalid content type.')
        return redirect('custom_admin:dashboard')

    Model, display_name, redirect_url = MODEL_MAP[model_type]

    if not selected_ids:
        messages.warning(request, f'No {display_name}s selected.')
        return redirect(redirect_url)

    queryset = Model.objects.filter(pk__in=selected_ids)
    count = queryset.count()

    if action == 'delete':
        log_admin_action(request, 'bulk_action', Model.__name__,
                         object_repr=f'Bulk delete {count} {display_name}(s)',
                         changes={'action': {'old': '', 'new': 'delete'}, 'count': {'old': '', 'new': str(count)}})
        queryset.delete()
        messages.success(request, f'{count} {display_name}(s) deleted successfully.')
    elif action == 'activate' and model_type == 'article':
        queryset.update(is_featured=True)
        log_admin_action(request, 'bulk_action', 'Article',
                         object_repr=f'Bulk feature {count} article(s)',
                         changes={'action': {'old': '', 'new': 'feature'}, 'count': {'old': '', 'new': str(count)}})
        messages.success(request, f'{count} article(s) set to featured.')
    elif action == 'deactivate' and model_type == 'article':
        queryset.update(is_featured=False)
        log_admin_action(request, 'bulk_action', 'Article',
                         object_repr=f'Bulk unfeature {count} article(s)',
                         changes={'action': {'old': '', 'new': 'unfeature'}, 'count': {'old': '', 'new': str(count)}})
        messages.success(request, f'{count} article(s) unfeatured.')
    elif action == 'activate' and model_type == 'event':
        queryset.update(is_active=True)
        log_admin_action(request, 'bulk_action', 'Event',
                         object_repr=f'Bulk activate {count} event(s)',
                         changes={'action': {'old': '', 'new': 'activate'}, 'count': {'old': '', 'new': str(count)}})
        messages.success(request, f'{count} event(s) activated.')
    elif action == 'deactivate' and model_type == 'event':
        queryset.update(is_active=False)
        log_admin_action(request, 'bulk_action', 'Event',
                         object_repr=f'Bulk deactivate {count} event(s)',
                         changes={'action': {'old': '', 'new': 'deactivate'}, 'count': {'old': '', 'new': str(count)}})
        messages.success(request, f'{count} event(s) deactivated.')
    else:
        messages.error(request, 'Invalid action.')

    return redirect(redirect_url)


# ═══════════════════════════════════════════════════════════════
#  GLOBAL SEARCH
# ═══════════════════════════════════════════════════════════════

def _search_admin_menus(query, user, limit=10):
    """Match sidebar menu labels against a query, filtered by permissions.

    Returns a list of {title, subtitle, url, icon} dicts ready to drop into
    either the JSON API or the full-page results. Menu keys come from
    permissions.ADMIN_MENUS (single source of truth for the sidebar).
    """
    from django.urls import reverse, NoReverseMatch
    from .permissions import ADMIN_MENUS, user_can_access

    q = (query or '').strip().lower()
    if not q:
        return []

    items = []
    for key, label, icon in ADMIN_MENUS:
        if q not in label.lower() and q not in key.lower():
            continue
        if not user_can_access(user, key):
            continue
        try:
            url = reverse(f'custom_admin:{key}')
        except NoReverseMatch:
            continue
        items.append({
            'title': label,
            'subtitle': 'Navigation',
            'url': url,
            'icon': icon,
            'key': key,
        })
        if len(items) >= limit:
            break
    return items


def _user_allowed_sections(user):
    """Return the set of section keys the user may access.

    Superusers get None (meaning *all*); regular staff get their explicit list.
    """
    if user.is_superuser:
        return None  # sentinel: unrestricted
    try:
        return set(user.profile.admin_sections or [])
    except Exception:
        return set()


def admin_global_search(request):
    """Full-page search results view.

    Results are scoped to sections the caller has access to so that a
    staff user scoped to, say, 'Weather' cannot discover user records,
    support tickets, or other data outside their remit.
    """
    query = request.GET.get('q', '').strip()
    allowed = _user_allowed_sections(request.user)
    results = {
        'menus': [],
        'users': [],
        'articles': [],
        'events': [],
        'magazines': [],
        'tickets': [],
        'videos': [],
    }

    if query and len(query) >= 2:
        results['menus'] = _search_admin_menus(query, request.user, limit=20)

        if allowed is None or 'users_list' in allowed:
            results['users'] = User.objects.filter(
                Q(username__icontains=query) |
                Q(email__icontains=query) |
                Q(first_name__icontains=query) |
                Q(last_name__icontains=query)
            ).select_related('profile')[:20]

        if allowed is None or 'articles_list' in allowed:
            results['articles'] = Article.objects.filter(
                Q(title__icontains=query) |
                Q(title_fr__icontains=query) |
                Q(content__icontains=query) |
                Q(author__icontains=query)
            )[:20]

        if allowed is None or 'events_list' in allowed:
            results['events'] = Event.objects.filter(
                Q(name__icontains=query) |
                Q(name_fr__icontains=query) |
                Q(description__icontains=query) |
                Q(address__icontains=query)
            )[:20]

        if allowed is None or 'magazines_list' in allowed:
            results['magazines'] = MagazineEdition.objects.filter(
                Q(title__icontains=query) |
                Q(title_fr__icontains=query) |
                Q(description__icontains=query)
            )[:20]

        if allowed is None or 'support_tickets_list' in allowed:
            results['tickets'] = SupportTicket.objects.filter(
                Q(subject__icontains=query) |
                Q(user__username__icontains=query) |
                Q(user__email__icontains=query)
            ).select_related('user')[:20]

        if allowed is None or 'videos_list' in allowed:
            results['videos'] = Video.objects.filter(
                Q(title__icontains=query) |
                Q(title_fr__icontains=query) |
                Q(description__icontains=query)
            )[:20]

    total_results = sum(len(v) for v in results.values())

    return render(request, 'custom_admin/search_results.html', {
        'query': query,
        'results': results,
        'total_results': total_results,
    })


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def admin_global_search_api(request):
    """JSON API endpoint for live search dropdown in the top navigation bar.
    Returns categorized results with max 5 per category, 20 total."""
    query = request.GET.get('q', '').strip()

    if not query or len(query) < 2:
        return JsonResponse({'results': []})

    categories = []
    total_count = 0
    max_per_category = 5
    max_total = 20

    # Section-scope: only return categories the caller is allowed to see
    allowed = _user_allowed_sections(request.user)

    # --- Navigation (sidebar menus) ---
    menu_items = _search_admin_menus(query, request.user, limit=max_per_category)
    if menu_items:
        categories.append({'category': 'Navigation', 'items': menu_items})
        total_count += len(menu_items)

    # --- Users ---
    if allowed is None or 'users_list' in allowed:
        users = User.objects.filter(
            Q(username__icontains=query) |
            Q(email__icontains=query) |
            Q(first_name__icontains=query) |
            Q(last_name__icontains=query)
        )[:max_per_category]
        if users:
            items = []
            for u in users:
                full_name = f"{u.first_name} {u.last_name}".strip()
                items.append({
                    'title': u.username,
                    'subtitle': full_name if full_name else u.email,
                    'url': f'/admin/users/{u.pk}/edit/',
                    'icon': 'person',
                })
            categories.append({'category': 'Users', 'items': items})
            total_count += len(items)

    # --- Articles ---
    if total_count < max_total and (allowed is None or 'articles_list' in allowed):
        articles = Article.objects.filter(
            Q(title__icontains=query) |
            Q(title_fr__icontains=query)
        )[:max_per_category]
        if articles:
            items = []
            for a in articles:
                items.append({
                    'title': a.title,
                    'subtitle': f"By {a.author}" if a.author else (a.title_fr or ''),
                    'url': f'/admin/articles/{a.pk}/edit/',
                    'icon': 'article',
                })
            categories.append({'category': 'Articles', 'items': items})
            total_count += len(items)

    # --- Events ---
    if total_count < max_total and (allowed is None or 'events_list' in allowed):
        events = Event.objects.filter(
            Q(name__icontains=query) |
            Q(name_fr__icontains=query)
        )[:max_per_category]
        if events:
            items = []
            for e in events:
                date_str = e.event_date.strftime('%b %d, %Y') if e.event_date else ''
                items.append({
                    'title': e.name,
                    'subtitle': date_str,
                    'url': f'/admin/events/{e.pk}/edit/',
                    'icon': 'event',
                })
            categories.append({'category': 'Events', 'items': items})
            total_count += len(items)

    # --- Magazines ---
    if total_count < max_total and (allowed is None or 'magazines_list' in allowed):
        magazines = MagazineEdition.objects.filter(
            Q(title__icontains=query) |
            Q(title_fr__icontains=query)
        )[:max_per_category]
        if magazines:
            items = []
            for m in magazines:
                subtitle = m.title_fr or ''
                if not subtitle and m.publish_date:
                    subtitle = f"Published {m.publish_date.strftime('%b %Y')}"
                items.append({
                    'title': m.title,
                    'subtitle': subtitle,
                    'url': f'/admin/magazines/{m.pk}/edit/',
                    'icon': 'menu_book',
                })
            categories.append({'category': 'Magazines', 'items': items})
            total_count += len(items)

    # --- Support Tickets ---
    if total_count < max_total and (allowed is None or 'support_tickets_list' in allowed):
        tickets = SupportTicket.objects.filter(
            Q(subject__icontains=query) |
            Q(user__username__icontains=query) |
            Q(user__email__icontains=query)
        ).select_related('user')[:max_per_category]
        if tickets:
            items = []
            for t in tickets:
                items.append({
                    'title': t.subject,
                    'subtitle': f"{t.get_status_display()} - {t.user.username}",
                    'url': f'/admin/support/{t.pk}/',
                    'icon': 'support_agent',
                })
            categories.append({'category': 'Support Tickets', 'items': items})
            total_count += len(items)

    # --- Videos ---
    if total_count < max_total and (allowed is None or 'videos_list' in allowed):
        videos = Video.objects.filter(
            Q(title__icontains=query) |
            Q(title_fr__icontains=query)
        )[:max_per_category]
        if videos:
            items = []
            for v in videos:
                subtitle = v.title_fr or ''
                if not subtitle and hasattr(v, 'get_category_display'):
                    subtitle = v.get_category_display()
                items.append({
                    'title': v.title,
                    'subtitle': subtitle,
                    'url': f'/admin/videos/{v.pk}/edit/',
                    'icon': 'videocam',
                })
            categories.append({'category': 'Videos', 'items': items})
            total_count += len(items)

    return JsonResponse({'results': categories})


# ═══════════════════════════════════════════════════════════════
#  EXPORT REPORTS (CSV)
# ═══════════════════════════════════════════════════════════════

@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@require_POST
def export_users_csv(request):
    response = HttpResponse(content_type='text/csv')
    response['Content-Disposition'] = 'attachment; filename="users_export.csv"'

    writer = csv.writer(response)
    writer.writerow([
        'ID', 'Username', 'Email', 'First Name', 'Last Name',
        'Is Active', 'Is Staff', 'Is Superuser', 'Date Joined',
        'Last Login', 'Nationality', 'Gender', 'Is Verified',
    ])

    users = User.objects.all().select_related('profile').order_by('-date_joined')
    for user in users:
        profile = getattr(user, 'profile', None)
        writer.writerow(_sanitize_csv_row([
            user.id,
            user.username,
            user.email,
            user.first_name,
            user.last_name,
            user.is_active,
            user.is_staff,
            user.is_superuser,
            user.date_joined.strftime('%Y-%m-%d %H:%M:%S') if user.date_joined else '',
            user.last_login.strftime('%Y-%m-%d %H:%M:%S') if user.last_login else '',
            profile.nationality if profile else '',
            profile.gender if profile else '',
            profile.is_verified if profile else False,
        ]))

    # Log the export (both old AuditLogEntry and new AdminActivityLog)
    AuditLogEntry.objects.create(
        user=request.user,
        action='EXPORT',
        entity_type='User',
        entity_label=f'CSV export of {users.count()} users',
        status='success',
    )
    log_admin_action(request, 'export', 'User', object_repr=f'CSV export of {users.count()} users')

    return response


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@require_POST
def export_analytics_csv(request):
    from datetime import timedelta

    response = HttpResponse(content_type='text/csv')
    response['Content-Disposition'] = 'attachment; filename="analytics_export.csv"'

    writer = csv.writer(response)
    now = timezone.now()

    # Summary section
    writer.writerow(['=== ANALYTICS SUMMARY ==='])
    writer.writerow(['Metric', 'Value'])
    writer.writerow(['Total Users', User.objects.count()])
    writer.writerow(['Active Users (30 days)', User.objects.filter(last_login__gte=now - timedelta(days=30)).count()])
    writer.writerow(['Active Users (7 days)', User.objects.filter(last_login__gte=now - timedelta(days=7)).count()])
    writer.writerow(['Total Articles', Article.objects.count()])
    writer.writerow(['Total Events', Event.objects.count()])
    writer.writerow(['Total Magazines', MagazineEdition.objects.count()])
    writer.writerow(['Total Videos', Video.objects.count()])
    writer.writerow(['Active Live Feeds', LiveFeed.objects.filter(status='live').count()])
    writer.writerow(['Open Support Tickets', SupportTicket.objects.filter(status='open').count()])
    writer.writerow([])

    # User growth (last 30 days)
    writer.writerow(['=== USER GROWTH (Last 30 Days) ==='])
    writer.writerow(['Date', 'New Users'])
    for i in range(30, -1, -1):
        day = (now - timedelta(days=i)).date()
        count = User.objects.filter(date_joined__date=day).count()
        writer.writerow([day.strftime('%Y-%m-%d'), count])
    writer.writerow([])

    # Top countries
    writer.writerow(['=== TOP COUNTRIES BY NATIONALITY ==='])
    writer.writerow(['Country', 'User Count'])
    nationality_data = (
        UserProfile.objects.exclude(nationality='')
        .values('nationality')
        .annotate(count=Count('id'))
        .order_by('-count')[:20]
    )
    for entry in nationality_data:
        writer.writerow(_sanitize_csv_row([entry['nationality'], entry['count']]))
    writer.writerow([])

    # Content engagement
    writer.writerow(['=== CONTENT ENGAGEMENT ==='])
    writer.writerow(['Content Type', 'Total Views', 'Total Likes'])
    article_views = Article.objects.aggregate(s=Sum('view_count'))['s'] or 0
    article_likes = Article.objects.aggregate(s=Sum('like_count'))['s'] or 0
    magazine_views = MagazineEdition.objects.aggregate(s=Sum('view_count'))['s'] or 0
    writer.writerow(['Articles', article_views, article_likes])
    writer.writerow(['Magazines', magazine_views, 'N/A'])

    # Log the export
    AuditLogEntry.objects.create(
        user=request.user,
        action='EXPORT',
        entity_type='AnalyticsReport',
        entity_label='CSV analytics export',
        status='success',
    )

    return response


# ═══════════════════════════════════════════════════════════════
#  TRANSLATION MANAGER
# ═══════════════════════════════════════════════════════════════

@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def translation_manager(request):
    translations = TranslationEntry.objects.all().order_by('-updated_at')

    status_filter = request.GET.get('status')
    if status_filter:
        translations = translations.filter(status=status_filter)

    search = request.GET.get('search')
    if search:
        translations = translations.filter(
            Q(key__icontains=search) |
            Q(source_text__icontains=search) |
            Q(translated_text__icontains=search)
        )

    total_count = TranslationEntry.objects.count()
    pending_count = TranslationEntry.objects.filter(status='pending').count()
    completed_count = TranslationEntry.objects.filter(status='completed').count()
    reviewed_count = TranslationEntry.objects.filter(status='reviewed').count()

    paginator = Paginator(translations, 20)
    page = request.GET.get('page')
    translations = paginator.get_page(page)

    return render(request, 'custom_admin/translations/manager.html', {
        'translations': translations,
        'total_count': total_count,
        'pending_count': pending_count,
        'completed_count': completed_count,
        'reviewed_count': reviewed_count,
        'current_status': status_filter or '',
        'current_search': search or '',
    })


# ═══════════════════════════════════════════════════════════════
#  RATE LIMITING DASHBOARD
# ═══════════════════════════════════════════════════════════════

@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def rate_limiting_dashboard(request):
    """Admin dashboard showing throttled requests, top offending IPs, and endpoint stats."""
    import json
    from datetime import timedelta
    from django.db.models import Count, Min, Max
    from django.db.models.functions import TruncHour, TruncDate

    now = timezone.now()
    period = request.GET.get('period', '24h')

    # Determine time range
    if period == '1h':
        since = now - timedelta(hours=1)
        period_label = 'Last Hour'
    elif period == '7d':
        since = now - timedelta(days=7)
        period_label = 'Last 7 Days'
    elif period == '30d':
        since = now - timedelta(days=30)
        period_label = 'Last 30 Days'
    else:
        since = now - timedelta(hours=24)
        period = '24h'
        period_label = 'Last 24 Hours'

    base_qs = RateLimitLog.objects.filter(timestamp__gte=since)

    # ── Summary counts ──
    total_blocked = base_qs.count()
    unique_ips = base_qs.values('ip_address').distinct().count()
    unique_endpoints = base_qs.values('endpoint').distinct().count()
    unique_users = base_qs.exclude(user__isnull=True).values('user').distinct().count()

    # ── Top offending IPs ──
    top_ips = list(
        base_qs.values('ip_address')
        .annotate(
            block_count=Count('id'),
            first_seen=Min('timestamp'),
            last_seen=Max('timestamp'),
        )
        .order_by('-block_count')[:15]
    )

    # ── Top throttled endpoints ──
    top_endpoints = list(
        base_qs.values('endpoint')
        .annotate(
            block_count=Count('id'),
            unique_ips=Count('ip_address', distinct=True),
        )
        .order_by('-block_count')[:15]
    )

    # ── Top throttle classes ──
    top_throttle_classes = list(
        base_qs.exclude(throttle_class='')
        .values('throttle_class')
        .annotate(block_count=Count('id'))
        .order_by('-block_count')[:10]
    )

    # ── HTTP method breakdown ──
    method_breakdown = list(
        base_qs.values('request_method')
        .annotate(count=Count('id'))
        .order_by('-count')
    )

    # ── Timeline chart (hourly for <=24h, daily for longer) ──
    if period in ('1h', '24h'):
        timeline_qs = (
            base_qs.annotate(bucket=TruncHour('timestamp'))
            .values('bucket')
            .annotate(count=Count('id'))
            .order_by('bucket')
        )
        timeline_labels = [t['bucket'].strftime('%H:%M') for t in timeline_qs]
    else:
        timeline_qs = (
            base_qs.annotate(bucket=TruncDate('timestamp'))
            .values('bucket')
            .annotate(count=Count('id'))
            .order_by('bucket')
        )
        timeline_labels = [t['bucket'].strftime('%b %d') for t in timeline_qs]

    timeline_data = [t['count'] for t in timeline_qs]

    # ── Recent blocked requests (paginated) ──
    recent_logs = base_qs.select_related('user').order_by('-timestamp')
    paginator = Paginator(recent_logs, 25)
    page = request.GET.get('page')
    recent_logs_page = paginator.get_page(page)

    context = {
        'period': period,
        'period_label': period_label,
        'total_blocked': total_blocked,
        'unique_ips': unique_ips,
        'unique_endpoints': unique_endpoints,
        'unique_users': unique_users,
        'top_ips': top_ips,
        'top_endpoints': top_endpoints,
        'top_throttle_classes': top_throttle_classes,
        'method_breakdown': method_breakdown,
        'timeline_labels_json': json.dumps(timeline_labels),
        'timeline_data_json': json.dumps(timeline_data),
        'recent_logs': recent_logs_page,
    }
    return render(request, 'custom_admin/analytics/rate_limiting.html', context)


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def analytics_charts(request):
    """Deep-dive interactive Chart.js dashboard with 8 chart types."""
    import json
    from datetime import timedelta
    from django.db.models import Sum, Count, Q
    from django.db.models.functions import (
        TruncDate, TruncWeek, TruncMonth, ExtractHour,
    )

    now = timezone.now()

    # Period filter (default 30 days)
    period_param = request.GET.get('period', '30')
    try:
        period_days = int(period_param)
    except (ValueError, TypeError):
        period_days = 30
    if period_days not in (7, 30, 90):
        period_days = 30
    period_start = now - timedelta(days=period_days)

    # ──────────────────────────────────────────────────────
    # 1. USER GROWTH (line chart) — registrations per day
    # ──────────────────────────────────────────────────────
    user_growth_qs = (
        User.objects.filter(date_joined__gte=period_start)
        .annotate(day=TruncDate('date_joined'))
        .values('day')
        .annotate(count=Count('id'))
        .order_by('day')
    )
    user_growth_labels = [g['day'].strftime('%b %d') for g in user_growth_qs]
    user_growth_data = [g['count'] for g in user_growth_qs]

    # ──────────────────────────────────────────────────────
    # 2. CONTENT PUBLISHED (stacked bar) — per week, last 12 weeks
    # ──────────────────────────────────────────────────────
    content_weeks = 12
    content_start = now - timedelta(weeks=content_weeks)

    articles_by_week = dict(
        Article.objects.filter(created_at__gte=content_start)
        .annotate(week=TruncWeek('created_at'))
        .values('week')
        .annotate(count=Count('id'))
        .values_list('week', 'count')
    )
    magazines_by_week = dict(
        MagazineEdition.objects.filter(created_at__gte=content_start)
        .annotate(week=TruncWeek('created_at'))
        .values('week')
        .annotate(count=Count('id'))
        .values_list('week', 'count')
    )
    videos_by_week = dict(
        Video.objects.filter(created_at__gte=content_start)
        .annotate(week=TruncWeek('created_at'))
        .values('week')
        .annotate(count=Count('id'))
        .values_list('week', 'count')
    )

    # Build unified week labels
    content_week_labels = []
    content_articles = []
    content_magazines = []
    content_videos = []
    for i in range(content_weeks - 1, -1, -1):
        week_date = (now - timedelta(weeks=i)).date()
        # TruncWeek returns Monday of each week
        from datetime import date as date_type
        monday = week_date - timedelta(days=week_date.weekday())
        label = monday.strftime('%b %d')
        content_week_labels.append(label)
        from django.utils.timezone import make_aware
        from datetime import datetime as dt_type
        week_key = make_aware(dt_type.combine(monday, dt_type.min.time()))
        content_articles.append(articles_by_week.get(week_key, 0))
        content_magazines.append(magazines_by_week.get(week_key, 0))
        content_videos.append(videos_by_week.get(week_key, 0))

    # ──────────────────────────────────────────────────────
    # 3. ENGAGEMENT METRICS (multi-line) — daily over period
    # ──────────────────────────────────────────────────────
    engagement_days = min(period_days, 30)
    engagement_start = now - timedelta(days=engagement_days)

    # Article views by day — use ArticleLike/ArticleComment created_at as proxies
    likes_by_day = dict(
        ArticleLike.objects.filter(created_at__gte=engagement_start)
        .annotate(day=TruncDate('created_at'))
        .values('day')
        .annotate(count=Count('id'))
        .values_list('day', 'count')
    )
    comments_by_day = dict(
        ArticleComment.objects.filter(created_at__gte=engagement_start)
        .annotate(day=TruncDate('created_at'))
        .values('day')
        .annotate(count=Count('id'))
        .values_list('day', 'count')
    )
    reactions_by_day = dict(
        Reaction.objects.filter(created_at__gte=engagement_start)
        .annotate(day=TruncDate('created_at'))
        .values('day')
        .annotate(count=Count('id'))
        .values_list('day', 'count')
    )
    bookmarks_by_day = dict(
        Bookmark.objects.filter(created_at__gte=engagement_start)
        .annotate(day=TruncDate('created_at'))
        .values('day')
        .annotate(count=Count('id'))
        .values_list('day', 'count')
    )

    engagement_labels = []
    engagement_likes = []
    engagement_comments = []
    engagement_reactions = []
    engagement_bookmarks = []
    for i in range(engagement_days - 1, -1, -1):
        day = (now - timedelta(days=i)).date()
        engagement_labels.append(day.strftime('%b %d'))
        engagement_likes.append(likes_by_day.get(day, 0))
        engagement_comments.append(comments_by_day.get(day, 0))
        engagement_reactions.append(reactions_by_day.get(day, 0))
        engagement_bookmarks.append(bookmarks_by_day.get(day, 0))

    # ──────────────────────────────────────────────────────
    # 4. USER DEMOGRAPHICS (doughnut) — by nationality top 10
    # ──────────────────────────────────────────────────────
    nationality_data = list(
        UserProfile.objects.exclude(nationality='')
        .values('nationality')
        .annotate(count=Count('id'))
        .order_by('-count')[:10]
    )
    nationality_labels = [d['nationality'] for d in nationality_data]
    nationality_counts = [d['count'] for d in nationality_data]
    # Add "Other" bucket
    top_10_total = sum(nationality_counts)
    total_with_nationality = UserProfile.objects.exclude(nationality='').count()
    other_count = total_with_nationality - top_10_total
    if other_count > 0:
        nationality_labels.append('Other')
        nationality_counts.append(other_count)

    # ──────────────────────────────────────────────────────
    # 5. EVENT ACTIVITY (bar chart) — registrations per event, top 10
    # ──────────────────────────────────────────────────────
    event_activity = list(
        EventRegistration.objects.annotate(
            sub_count=Count('submissions')
        ).filter(sub_count__gt=0)
        .order_by('-sub_count')[:10]
    )
    event_labels = [e.event_title[:40] for e in event_activity]
    event_counts = [e.sub_count for e in event_activity]

    # ──────────────────────────────────────────────────────
    # 6. SUPPORT TICKETS (line chart) — opened vs closed per week
    # ──────────────────────────────────────────────────────
    ticket_weeks = 8
    ticket_start = now - timedelta(weeks=ticket_weeks)

    tickets_opened_by_week = dict(
        SupportTicket.objects.filter(created_at__gte=ticket_start)
        .annotate(week=TruncWeek('created_at'))
        .values('week')
        .annotate(count=Count('id'))
        .values_list('week', 'count')
    )
    tickets_closed_by_week = dict(
        SupportTicket.objects.filter(
            resolved_at__gte=ticket_start,
            status__in=['resolved', 'closed']
        )
        .annotate(week=TruncWeek('resolved_at'))
        .values('week')
        .annotate(count=Count('id'))
        .values_list('week', 'count')
    )

    ticket_labels = []
    ticket_opened = []
    ticket_closed = []
    for i in range(ticket_weeks - 1, -1, -1):
        week_date = (now - timedelta(weeks=i)).date()
        monday = week_date - timedelta(days=week_date.weekday())
        label = monday.strftime('%b %d')
        ticket_labels.append(label)
        week_key = make_aware(dt_type.combine(monday, dt_type.min.time()))
        ticket_opened.append(tickets_opened_by_week.get(week_key, 0))
        ticket_closed.append(tickets_closed_by_week.get(week_key, 0))

    # ──────────────────────────────────────────────────────
    # 7. TRAFFIC BY HOUR (area chart) — login activity averaged over last 7 days
    # ──────────────────────────────────────────────────────
    traffic_start = now - timedelta(days=7)
    hourly_logins = dict(
        LoginHistory.objects.filter(created_at__gte=traffic_start, success=True)
        .annotate(hour=ExtractHour('created_at'))
        .values('hour')
        .annotate(count=Count('id'))
        .values_list('hour', 'count')
    )
    traffic_labels = [f'{h:02d}:00' for h in range(24)]
    traffic_data = [round(hourly_logins.get(h, 0) / 7, 1) for h in range(24)]

    # ──────────────────────────────────────────────────────
    # 8. BADGE DISTRIBUTION (pie chart)
    # ──────────────────────────────────────────────────────
    gold_count = UserProfile.objects.filter(badge_type='GOLD').count()
    blue_count = UserProfile.objects.filter(badge_type='BLUE').count()
    no_badge_count = UserProfile.objects.filter(
        Q(badge_type__isnull=True) | Q(badge_type='')
    ).count()
    badge_labels = ['Gold Badge', 'Blue Badge', 'No Badge']
    badge_data = [gold_count, blue_count, no_badge_count]

    # ──────────────────────────────────────────────────────
    # Build context with JSON-safe data
    # ──────────────────────────────────────────────────────
    context = {
        'period': period_days,
        # 1. User Growth
        'user_growth_labels': json.dumps(user_growth_labels),
        'user_growth_data': json.dumps(user_growth_data),
        # 2. Content Published
        'content_week_labels': json.dumps(content_week_labels),
        'content_articles': json.dumps(content_articles),
        'content_magazines': json.dumps(content_magazines),
        'content_videos': json.dumps(content_videos),
        # 3. Engagement
        'engagement_labels': json.dumps(engagement_labels),
        'engagement_likes': json.dumps(engagement_likes),
        'engagement_comments': json.dumps(engagement_comments),
        'engagement_reactions': json.dumps(engagement_reactions),
        'engagement_bookmarks': json.dumps(engagement_bookmarks),
        # 4. Demographics
        'nationality_labels': json.dumps(nationality_labels),
        'nationality_counts': json.dumps(nationality_counts),
        # 5. Event Activity
        'event_labels': json.dumps(event_labels),
        'event_counts': json.dumps(event_counts),
        # 6. Support Tickets
        'ticket_labels': json.dumps(ticket_labels),
        'ticket_opened': json.dumps(ticket_opened),
        'ticket_closed': json.dumps(ticket_closed),
        # 7. Traffic by Hour
        'traffic_labels': json.dumps(traffic_labels),
        'traffic_data': json.dumps(traffic_data),
        # 8. Badge Distribution
        'badge_labels': json.dumps(badge_labels),
        'badge_data': json.dumps(badge_data),
    }
    return render(request, 'custom_admin/analytics/charts.html', context)


# ═══════════════════════════════════════════════════════════════
#  ADMIN ACTIVITY LOG
# ═══════════════════════════════════════════════════════════════

@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def activity_log(request):
    """View and filter admin activity logs with CSV export support."""
    import json as json_mod
    from datetime import timedelta

    logs = AdminActivityLog.objects.all().select_related('user').order_by('-timestamp')

    # ── Filters ──
    user_filter = request.GET.get('user', '').strip()
    action_filter = request.GET.get('action', '').strip()
    model_filter = request.GET.get('model', '').strip()
    date_from = request.GET.get('date_from', '').strip()
    date_to = request.GET.get('date_to', '').strip()

    if user_filter:
        logs = logs.filter(
            Q(user__username__icontains=user_filter) |
            Q(user__email__icontains=user_filter) |
            Q(user__first_name__icontains=user_filter) |
            Q(user__last_name__icontains=user_filter)
        )
    if action_filter:
        logs = logs.filter(action_type=action_filter)
    if model_filter:
        logs = logs.filter(model_name__icontains=model_filter)
    if date_from:
        try:
            from datetime import datetime as dt
            from_date = dt.strptime(date_from, '%Y-%m-%d')
            logs = logs.filter(timestamp__date__gte=from_date.date())
        except ValueError:
            pass
    if date_to:
        try:
            from datetime import datetime as dt
            to_date = dt.strptime(date_to, '%Y-%m-%d')
            logs = logs.filter(timestamp__date__lte=to_date.date())
        except ValueError:
            pass

    # ── CSV Export ──
    if request.GET.get('export') == 'csv':
        response = HttpResponse(content_type='text/csv')
        response['Content-Disposition'] = 'attachment; filename="admin_activity_log.csv"'
        writer = csv.writer(response)
        writer.writerow(['Timestamp', 'Admin', 'Action', 'Model', 'Object ID', 'Object', 'IP Address', 'Path', 'Changes'])
        for log in logs[:5000]:  # Limit CSV rows
            writer.writerow(_sanitize_csv_row([
                log.timestamp.strftime('%Y-%m-%d %H:%M:%S'),
                log.user.username if log.user else 'Unknown',
                log.get_action_type_display(),
                log.model_name,
                log.object_id or '',
                log.object_repr,
                log.ip_address or '',
                log.path,
                json_mod.dumps(log.changes) if log.changes else '',
            ]))
        return response

    # ── Filter dropdown data ──
    action_choices = AdminActivityLog.ACTION_TYPE_CHOICES
    model_names = (
        AdminActivityLog.objects.exclude(model_name='')
        .values_list('model_name', flat=True)
        .distinct()
        .order_by('model_name')
    )
    admin_users = (
        User.objects.filter(is_staff=True)
        .values_list('username', flat=True)
        .order_by('username')
    )

    # ── Pagination ──
    paginator = Paginator(logs, 50)
    page = request.GET.get('page')
    logs_page = paginator.get_page(page)

    return render(request, 'custom_admin/activity_log.html', {
        'logs': logs_page,
        'action_choices': action_choices,
        'model_names': model_names,
        'admin_users': admin_users,
        'current_user_filter': user_filter,
        'current_action_filter': action_filter,
        'current_model_filter': model_filter,
        'current_date_from': date_from,
        'current_date_to': date_to,
    })


# ═══════════════════════════════════════════════════════════════
#  USER SEGMENTS
# ═══════════════════════════════════════════════════════════════

@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def segment_list(request):
    """List all user segments."""
    segments = UserSegment.objects.all().select_related('created_by')
    # Annotate each segment with its member count
    segment_data = []
    for seg in segments:
        segment_data.append({
            'segment': seg,
            'member_count': seg.get_member_count(),
        })
    return render(request, 'custom_admin/segments/list.html', {
        'segment_data': segment_data,
    })


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def segment_create(request):
    """Create a new user segment."""
    import json as json_mod
    from core.models import NATIONALITY_CHOICES

    if request.method == 'POST':
        name = request.POST.get('name', '').strip()
        description = request.POST.get('description', '').strip()
        is_dynamic = request.POST.get('is_dynamic') == 'on'

        if not name:
            messages.error(request, 'Segment name is required.')
            return render(request, 'custom_admin/segments/form.html', {
                'action': 'Create',
                'nationality_choices': NATIONALITY_CHOICES,
            })

        filters = {}
        if is_dynamic:
            filters = _build_segment_filters(request)

        segment = UserSegment.objects.create(
            name=name,
            description=description,
            filters=filters,
            is_dynamic=is_dynamic,
            created_by=request.user,
        )

        # For static segments, add selected users
        if not is_dynamic:
            user_ids = request.POST.getlist('static_users')
            for uid in user_ids:
                try:
                    UserSegmentMembership.objects.create(
                        segment=segment,
                        user_id=int(uid),
                    )
                except (ValueError, Exception):
                    pass

        messages.success(request, f'Segment "{name}" created successfully!')
        return redirect('custom_admin:segment_detail', pk=segment.pk)

    return render(request, 'custom_admin/segments/form.html', {
        'action': 'Create',
        'nationality_choices': NATIONALITY_CHOICES,
    })


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def segment_edit(request, pk):
    """Edit an existing user segment."""
    import json as json_mod
    from core.models import NATIONALITY_CHOICES

    segment = get_object_or_404(UserSegment, pk=pk)

    if request.method == 'POST':
        name = request.POST.get('name', '').strip()
        description = request.POST.get('description', '').strip()
        is_dynamic = request.POST.get('is_dynamic') == 'on'

        if not name:
            messages.error(request, 'Segment name is required.')
            return render(request, 'custom_admin/segments/form.html', {
                'action': 'Edit',
                'segment': segment,
                'nationality_choices': NATIONALITY_CHOICES,
            })

        segment.name = name
        segment.description = description
        segment.is_dynamic = is_dynamic

        if is_dynamic:
            segment.filters = _build_segment_filters(request)
            # Clear any static memberships when switching to dynamic
            segment.memberships.all().delete()
        else:
            segment.filters = {}
            # Update static membership
            segment.memberships.all().delete()
            user_ids = request.POST.getlist('static_users')
            for uid in user_ids:
                try:
                    UserSegmentMembership.objects.create(
                        segment=segment,
                        user_id=int(uid),
                    )
                except (ValueError, Exception):
                    pass

        segment.save()
        messages.success(request, f'Segment "{name}" updated successfully!')
        return redirect('custom_admin:segment_detail', pk=segment.pk)

    return render(request, 'custom_admin/segments/form.html', {
        'action': 'Edit',
        'segment': segment,
        'nationality_choices': NATIONALITY_CHOICES,
    })


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def segment_detail(request, pk):
    """View segment details with paginated member list."""
    segment = get_object_or_404(UserSegment, pk=pk)
    users = segment.get_users().select_related('profile').order_by('-date_joined')
    member_count = users.count()

    paginator = Paginator(users, 25)
    page = request.GET.get('page')
    users_page = paginator.get_page(page)

    return render(request, 'custom_admin/segments/detail.html', {
        'segment': segment,
        'users': users_page,
        'member_count': member_count,
    })


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@require_POST
def segment_delete(request, pk):
    """Delete a user segment."""
    segment = get_object_or_404(UserSegment, pk=pk)
    name = segment.name
    segment.delete()
    messages.success(request, f'Segment "{name}" deleted successfully.')
    return redirect('custom_admin:segment_list')


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def segment_preview(request):
    """AJAX endpoint: return user count for given filter criteria."""
    import json as json_mod

    if request.method != 'POST':
        return JsonResponse({'error': 'POST required'}, status=405)

    try:
        body = json_mod.loads(request.body)
    except (json_mod.JSONDecodeError, ValueError):
        return JsonResponse({'error': 'Invalid JSON'}, status=400)

    # Build a temporary in-memory segment to compute preview
    temp_segment = UserSegment(filters=body, is_dynamic=True)
    count = temp_segment.get_users().count()
    return JsonResponse({'count': count})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@require_POST
def segment_export(request, pk):
    """Export segment members as a CSV download."""
    segment = get_object_or_404(UserSegment, pk=pk)
    users = segment.get_users().select_related('profile').order_by('username')

    response = HttpResponse(content_type='text/csv')
    response['Content-Disposition'] = f'attachment; filename="segment_{segment.pk}_{segment.name}.csv"'

    writer = csv.writer(response)
    writer.writerow(['Username', 'Email', 'First Name', 'Last Name', 'Nationality', 'Gender', 'Badge', 'Date Joined', 'Email Verified', 'Active'])

    for user in users:
        profile = getattr(user, 'profile', None)
        writer.writerow(_sanitize_csv_row([
            user.username,
            user.email,
            user.first_name,
            user.last_name,
            profile.get_nationality_display() if profile and profile.nationality else '',
            profile.get_gender_display() if profile and profile.gender else '',
            profile.get_badge_type_display() if profile and profile.badge_type else 'None',
            user.date_joined.strftime('%Y-%m-%d %H:%M'),
            'Yes' if profile and profile.is_email_verified else 'No',
            'Yes' if user.is_active else 'No',
        ]))

    return response


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@require_POST
def segment_notify(request, pk):
    """Send a push notification to all members of a segment."""
    segment = get_object_or_404(UserSegment, pk=pk)
    title = request.POST.get('notify_title', '').strip()
    body = request.POST.get('notify_body', '').strip()

    if not title or not body:
        messages.error(request, 'Both notification title and body are required.')
        return redirect('custom_admin:segment_detail', pk=pk)

    # Create a notification targeting the segment members
    users = segment.get_users()
    notification = Notification.objects.create(
        title=title,
        message=body,
        notification_type='general',
        is_global=False,
    )
    notification.target_users.set(users)

    from core.tasks import send_notification_push_async
    send_notification_push_async.delay(notification.pk)
    messages.success(
        request,
        f'Notification queued for segment "{segment.name}".'
    )

    return redirect('custom_admin:segment_detail', pk=pk)


def _build_segment_filters(request):
    """
    Helper: extract filter criteria from the POST form and return a dict
    suitable for storing in UserSegment.filters JSONField.
    """
    filters = {}

    # Nationalities (multi-select)
    nationalities = request.POST.getlist('filter_nationality')
    if nationalities:
        filters['nationality'] = nationalities

    # Gender (checkboxes)
    genders = request.POST.getlist('filter_gender')
    if genders:
        filters['gender'] = genders

    # Badge type (checkboxes)
    badge_types = request.POST.getlist('filter_badge_type')
    if badge_types:
        filters['badge_type'] = badge_types

    # Age range
    age_min = request.POST.get('filter_age_min', '').strip()
    age_max = request.POST.get('filter_age_max', '').strip()
    if age_min or age_max:
        age_range = {}
        if age_min:
            try:
                age_range['min'] = int(age_min)
            except ValueError:
                pass
        if age_max:
            try:
                age_range['max'] = int(age_max)
            except ValueError:
                pass
        if age_range:
            filters['age_range'] = age_range

    # Registration date filters
    registered_after = request.POST.get('filter_registered_after', '').strip()
    if registered_after:
        filters['registered_after'] = registered_after

    registered_before = request.POST.get('filter_registered_before', '').strip()
    if registered_before:
        filters['registered_before'] = registered_before

    # Email verified
    email_verified = request.POST.get('filter_email_verified', 'any')
    if email_verified == 'yes':
        filters['has_verified_email'] = True
    elif email_verified == 'no':
        filters['has_verified_email'] = False

    # Active status
    active_status = request.POST.get('filter_active_status', 'any')
    if active_status == 'active':
        filters['is_active'] = True
    elif active_status == 'inactive':
        filters['is_active'] = False

    return filters


# =============================================================================
# System Health Dashboard
# =============================================================================

@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def system_health_dashboard(request):
    """Render the system health dashboard page."""
    return render(request, 'custom_admin/system_health.html')


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def system_health_api(request):
    """Return system health data as JSON for AJAX refresh."""
    import time
    import platform
    import socket
    import re
    import django
    from datetime import timedelta
    from django.db import connection
    from django.conf import settings

    data = {}

    # ── Server Info ──
    data['server_info'] = {
        'django_version': django.get_version(),
        'python_version': platform.python_version(),
        'hostname': socket.gethostname(),
        'os': f"{platform.system()} {platform.release()}",
        'environment': os.environ.get(
            'SENTRY_ENVIRONMENT',
            'development' if settings.DEBUG else 'production'
        ),
    }

    # ── CPU / Memory / Disk (psutil) ──
    try:
        import psutil
        data['cpu_percent'] = psutil.cpu_percent(interval=0.5)

        mem = psutil.virtual_memory()
        data['memory_percent'] = mem.percent
        data['memory_used_gb'] = round(mem.used / (1024 ** 3), 2)
        data['memory_total_gb'] = round(mem.total / (1024 ** 3), 2)

        disk = psutil.disk_usage('/')
        data['disk_percent'] = disk.percent
        data['disk_used_gb'] = round(disk.used / (1024 ** 3), 2)
        data['disk_total_gb'] = round(disk.total / (1024 ** 3), 2)

        boot_time = psutil.boot_time()
        uptime_seconds = time.time() - boot_time
        uptime_days = int(uptime_seconds // 86400)
        uptime_hours = int((uptime_seconds % 86400) // 3600)
        data['uptime_days'] = uptime_days
        data['uptime_hours'] = uptime_hours

        data['psutil_available'] = True
    except ImportError:
        data['cpu_percent'] = 0
        data['memory_percent'] = 0
        data['memory_used_gb'] = 0
        data['memory_total_gb'] = 0
        data['disk_percent'] = 0
        data['disk_used_gb'] = 0
        data['disk_total_gb'] = 0
        data['uptime_days'] = 0
        data['uptime_hours'] = 0
        data['psutil_available'] = False

    # ── Database connectivity & latency ──
    try:
        start = time.time()
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1")
        latency_ms = round((time.time() - start) * 1000, 1)
        data['db_connected'] = True
        data['db_latency_ms'] = latency_ms
    except Exception:
        data['db_connected'] = False
        data['db_latency_ms'] = 0

    # ── Cache connectivity ──
    try:
        from django.core.cache import cache
        cache.set('_health_check', 'ok', 10)
        val = cache.get('_health_check')
        data['cache_connected'] = val == 'ok'
    except Exception:
        data['cache_connected'] = False

    # ── Email configured ──
    email_backend = getattr(settings, 'EMAIL_BACKEND', '')
    data['email_configured'] = bool(
        email_backend and 'console' not in email_backend.lower()
        and getattr(settings, 'EMAIL_HOST', '')
    )

    # ── Database stats ──
    try:
        db_engine = settings.DATABASES['default']['ENGINE']
        db_name = settings.DATABASES['default']['NAME']
        data['db_engine'] = db_engine.split('.')[-1]
        data['db_name'] = db_name.split('/')[-1] if '/' in str(db_name) else str(db_name)

        with connection.cursor() as cursor:
            if 'postgresql' in db_engine or 'postgis' in db_engine:
                cursor.execute(
                    "SELECT count(*) FROM information_schema.tables "
                    "WHERE table_schema = 'public' AND table_type = 'BASE TABLE'"
                )
                data['table_count'] = cursor.fetchone()[0]
                cursor.execute(
                    "SELECT sum(n_live_tup) FROM pg_stat_user_tables"
                )
                row_result = cursor.fetchone()[0]
                data['row_count'] = int(row_result) if row_result else 0
                cursor.execute(
                    "SELECT pg_size_pretty(pg_database_size(current_database()))"
                )
                data['db_size'] = cursor.fetchone()[0]
                # PostgreSQL version
                cursor.execute("SELECT version()")
                data['db_version'] = cursor.fetchone()[0]
            elif 'sqlite' in db_engine:
                cursor.execute(
                    "SELECT count(*) FROM sqlite_master WHERE type='table'"
                )
                data['table_count'] = cursor.fetchone()[0]
                data['row_count'] = 0
                if os.path.exists(str(db_name)):
                    size_bytes = os.path.getsize(str(db_name))
                    if size_bytes < 1024 * 1024:
                        data['db_size'] = f"{round(size_bytes / 1024, 1)} KB"
                    else:
                        data['db_size'] = f"{round(size_bytes / (1024 * 1024), 2)} MB"
                else:
                    data['db_size'] = 'N/A'
                cursor.execute("SELECT sqlite_version()")
                data['db_version'] = f"SQLite {cursor.fetchone()[0]}"
            else:
                data['table_count'] = 0
                data['row_count'] = 0
                data['db_size'] = 'N/A'
                data['db_version'] = 'N/A'
    except Exception:
        data['db_engine'] = 'Unknown'
        data['db_name'] = 'Unknown'
        data['table_count'] = 0
        data['row_count'] = 0
        data['db_size'] = 'N/A'
        data['db_version'] = 'N/A'

    # ── Application Stats (real counts from database) ──
    thirty_days_ago = timezone.now() - timedelta(days=30)
    try:
        data['app_stats'] = {
            'total_users': User.objects.count(),
            'active_users_30d': UserProfile.objects.filter(
                user__last_login__gte=thirty_days_ago
            ).count(),
            'total_articles': Article.objects.count(),
            'total_events': Event.objects.count(),
            'total_magazines': MagazineEdition.objects.count(),
            'total_videos': Video.objects.count(),
            'total_gallery_albums': GalleryAlbum.objects.count(),
            'total_gallery_photos': GalleryPhoto.objects.count(),
            'total_live_feeds': LiveFeed.objects.count(),
            'notifications_sent': Notification.objects.filter(
                push_sent=True
            ).count(),
            'pending_tickets': SupportTicket.objects.filter(
                status='open'
            ).count(),
            'pending_verifications': VerificationRequest.objects.filter(
                status='pending'
            ).count(),
        }
    except Exception:
        data['app_stats'] = {}

    # ── Media / Storage Info ──
    try:
        media_root = getattr(settings, 'MEDIA_ROOT', '')
        if media_root and os.path.isdir(media_root):
            total_size = 0
            for dirpath, dirnames, filenames in os.walk(media_root):
                for f in filenames:
                    fp = os.path.join(dirpath, f)
                    if os.path.isfile(fp):
                        total_size += os.path.getsize(fp)
            if total_size < 1024 * 1024:
                data['media_size'] = f"{round(total_size / 1024, 1)} KB"
            elif total_size < 1024 * 1024 * 1024:
                data['media_size'] = f"{round(total_size / (1024 * 1024), 1)} MB"
            else:
                data['media_size'] = f"{round(total_size / (1024 * 1024 * 1024), 2)} GB"
        else:
            data['media_size'] = 'N/A'
    except Exception:
        data['media_size'] = 'N/A'

    # ── Deployment / Environment Info ──
    try:
        deploy_info = {}
        # Database URL (masked)
        db_url = os.environ.get('DATABASE_URL', '')
        if db_url:
            masked = re.sub(r'://([^:]+):([^@]+)@', r'://\1:****@', db_url)
            deploy_info['database_url'] = masked
        else:
            deploy_info['database_url'] = 'Not set (using SQLite)'

        deploy_info['django_env'] = os.environ.get(
            'SENTRY_ENVIRONMENT',
            'development' if settings.DEBUG else 'production'
        )
        deploy_info['debug_mode'] = settings.DEBUG
        deploy_info['allowed_hosts'] = (
            ', '.join(settings.ALLOWED_HOSTS)
            if settings.ALLOWED_HOSTS else '*'
        )
        deploy_info['static_url'] = getattr(settings, 'STATIC_URL', '/static/')
        deploy_info['media_url'] = getattr(settings, 'MEDIA_URL', '/media/')

        # Storage backend
        default_file_storage = getattr(
            settings, 'DEFAULT_FILE_STORAGE', ''
        )
        if 's3' in default_file_storage.lower() or 'boto' in default_file_storage.lower():
            deploy_info['storage_backend'] = 'S3 / DigitalOcean Spaces'
        else:
            deploy_info['storage_backend'] = 'Local filesystem'

        data['deploy_info'] = deploy_info
    except Exception:
        data['deploy_info'] = {}

    # ── Recent admin logins ──
    try:
        recent_logins = LoginHistory.objects.select_related('user').order_by('-logged_in_at')[:10]
        data['recent_logins'] = [
            {
                'username': lh.user.username if lh.user else 'Unknown',
                'ip_address': lh.ip_address or 'N/A',
                'logged_in_at': lh.logged_in_at.strftime('%Y-%m-%d %H:%M') if lh.logged_in_at else 'N/A',
            }
            for lh in recent_logins
        ]
    except Exception:
        data['recent_logins'] = []

    return JsonResponse(data)


# =============================================================================
# Database Backup UI
# =============================================================================

@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def database_backup_page(request):
    """Render the database backup management page."""
    from django.conf import settings as django_settings

    backups = DatabaseBackup.objects.select_related('created_by').order_by('-created_at')

    db_engine = django_settings.DATABASES['default']['ENGINE'].split('.')[-1]
    db_name_raw = django_settings.DATABASES['default']['NAME']
    db_name = str(db_name_raw).split('/')[-1] if '/' in str(db_name_raw) else str(db_name_raw)

    # Estimate DB size
    db_size = 'N/A'
    try:
        from django.db import connection
        with connection.cursor() as cursor:
            engine_full = django_settings.DATABASES['default']['ENGINE']
            if 'postgresql' in engine_full or 'postgis' in engine_full:
                cursor.execute("SELECT pg_size_pretty(pg_database_size(current_database()))")
                db_size = cursor.fetchone()[0]
            elif 'sqlite' in engine_full:
                import os
                if os.path.exists(str(db_name_raw)):
                    size_bytes = os.path.getsize(str(db_name_raw))
                    if size_bytes < 1024 * 1024:
                        db_size = f"{round(size_bytes / 1024, 1)} KB"
                    else:
                        db_size = f"{round(size_bytes / (1024 * 1024), 2)} MB"
    except Exception:
        pass

    context = {
        'backups': backups,
        'db_engine': db_engine,
        'db_name': db_name,
        'db_size': db_size,
    }
    return render(request, 'custom_admin/database_backup.html', context)


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@require_POST
def create_backup(request):
    """Create a new database backup using Django dumpdata."""
    import io
    import os
    from django.conf import settings as django_settings
    from django.core.management import call_command
    from datetime import datetime

    backup_type = request.POST.get('backup_type', 'full')
    notes = request.POST.get('notes', '').strip()

    # Create backups/ directory if needed
    backup_dir = os.path.join(django_settings.BASE_DIR, 'backups')
    os.makedirs(backup_dir, exist_ok=True)

    filename = f"backup_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
    filepath = os.path.join(backup_dir, filename)

    # Create the DatabaseBackup record first
    backup_record = DatabaseBackup.objects.create(
        filename=filename,
        file_path=filepath,
        backup_type=backup_type,
        status='in_progress',
        created_by=request.user,
        notes=notes,
    )

    try:
        output = io.StringIO()
        cmd_kwargs = {
            'stdout': output,
            'verbosity': 0,
        }

        if backup_type == 'data_only':
            call_command(
                'dumpdata',
                '--natural-foreign',
                '--natural-primary',
                '--exclude=contenttypes',
                '--exclude=auth.permission',
                **cmd_kwargs,
            )
        else:
            # Full backup — include all models
            call_command(
                'dumpdata',
                '--all',
                '--natural-foreign',
                '--natural-primary',
                **cmd_kwargs,
            )

        with open(filepath, 'w') as f:
            f.write(output.getvalue())

        file_size = os.path.getsize(filepath)
        backup_record.file_size = file_size
        backup_record.status = 'completed'
        backup_record.save()

        log_admin_action(request, 'backup', 'DatabaseBackup', object_id=backup_record.pk,
                         object_repr=filename, changes={'type': {'old': '', 'new': backup_type}, 'size': {'old': '', 'new': _format_file_size(file_size)}})
        messages.success(request, f'Backup "{filename}" created successfully ({_format_file_size(file_size)}).')
    except Exception as e:
        backup_record.status = 'failed'
        backup_record.error_message = str(e)
        backup_record.save()
        messages.error(request, f'Backup failed: {str(e)}')

    return redirect('custom_admin:database_backup')


def _format_file_size(size_bytes):
    """Format bytes into human-readable size."""
    if size_bytes < 1024:
        return f"{size_bytes} B"
    elif size_bytes < 1024 * 1024:
        return f"{round(size_bytes / 1024, 1)} KB"
    elif size_bytes < 1024 * 1024 * 1024:
        return f"{round(size_bytes / (1024 * 1024), 2)} MB"
    else:
        return f"{round(size_bytes / (1024 * 1024 * 1024), 2)} GB"


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@require_POST
def download_backup(request, pk):
    """Serve a backup file for download."""
    import os
    from django.http import FileResponse

    backup = get_object_or_404(DatabaseBackup, pk=pk)

    if not os.path.exists(backup.file_path):
        messages.error(request, 'Backup file not found on disk.')
        return redirect('custom_admin:database_backup')

    return FileResponse(
        open(backup.file_path, 'rb'),
        as_attachment=True,
        filename=backup.filename,
        content_type='application/json',
    )


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@require_POST
def delete_backup(request, pk):
    """Delete a backup record and its file from disk."""
    import os

    backup = get_object_or_404(DatabaseBackup, pk=pk)
    filename = backup.filename
    log_admin_action(request, 'delete', 'DatabaseBackup', object_id=pk, object_repr=filename)

    # Delete file from disk if it exists
    if backup.file_path and os.path.exists(backup.file_path):
        try:
            os.remove(backup.file_path)
        except OSError:
            pass

    backup.delete()
    messages.success(request, f'Backup "{filename}" deleted.')
    return redirect('custom_admin:database_backup')


# =============================================================================
# Admin Notifications (Bell icon in header)
# =============================================================================

@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def admin_notifications_api(request):
    """JSON API for notification bell dropdown. Returns unread count + recent notifications."""
    notifications = AdminNotification.objects.order_by('-created_at')[:20]
    unread_count = AdminNotification.objects.filter(is_read=False).count()

    data = {
        'unread_count': unread_count,
        'notifications': [
            {
                'id': n.id,
                'notification_type': n.notification_type,
                'title': n.title,
                'message': n.message,
                'link': n.link,
                'icon': n.icon,
                'is_read': n.is_read,
                'created_at': n.created_at.isoformat(),
                'time_ago': _time_ago(n.created_at),
            }
            for n in notifications
        ],
    }
    return JsonResponse(data)


def _time_ago(dt):
    """Return a human-readable 'time ago' string."""
    now = timezone.now()
    diff = now - dt
    seconds = int(diff.total_seconds())
    if seconds < 60:
        return 'just now'
    minutes = seconds // 60
    if minutes < 60:
        return f'{minutes}m ago'
    hours = minutes // 60
    if hours < 24:
        return f'{hours}h ago'
    days = hours // 24
    if days < 30:
        return f'{days}d ago'
    months = days // 30
    return f'{months}mo ago'


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def admin_notification_mark_read(request):
    """POST: mark notifications as read. Accepts JSON {"ids": [1,2,3]} or {"all": true}."""
    if request.method != 'POST':
        return JsonResponse({'error': 'POST required'}, status=405)

    try:
        body = json.loads(request.body)
    except (json.JSONDecodeError, ValueError):
        return JsonResponse({'error': 'Invalid JSON'}, status=400)

    if body.get('all'):
        AdminNotification.objects.filter(is_read=False).update(is_read=True)
    elif body.get('ids'):
        ids = body['ids']
        if isinstance(ids, list):
            AdminNotification.objects.filter(id__in=ids, is_read=False).update(is_read=True)
    else:
        return JsonResponse({'error': 'Provide "ids" or "all"'}, status=400)

    return JsonResponse({'success': True})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def admin_notifications_page(request):
    """Full page view of all admin notifications with filtering and pagination."""
    filter_status = request.GET.get('status', 'all')
    qs = AdminNotification.objects.order_by('-created_at')

    if filter_status == 'unread':
        qs = qs.filter(is_read=False)
    elif filter_status == 'read':
        qs = qs.filter(is_read=True)

    paginator = Paginator(qs, 25)
    page_number = request.GET.get('page', 1)
    page_obj = paginator.get_page(page_number)

    unread_count = AdminNotification.objects.filter(is_read=False).count()

    return render(request, 'custom_admin/admin_notifications.html', {
        'page_obj': page_obj,
        'filter_status': filter_status,
        'unread_count': unread_count,
    })


# =============================================================================
# Image Editor / Cropper
# =============================================================================

@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def image_editor(request):
    """Renders the standalone image editor page with Cropper.js."""
    image_url = request.GET.get('image', '')
    return render(request, 'custom_admin/image_editor.html', {
        'image_url': image_url,
    })


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def image_crop_save(request):
    """POST: receives cropped image (multipart), saves as WebP, returns new URL."""
    if request.method != 'POST':
        return JsonResponse({'error': 'POST required'}, status=405)

    image_file = request.FILES.get('image')
    original_path = request.POST.get('original_path', '')

    if not image_file:
        return JsonResponse({'error': 'No image file provided'}, status=400)

    try:
        from PIL import Image as PILImage

        img = PILImage.open(image_file)

        # Convert to RGB if necessary (handles RGBA, P, etc.)
        if img.mode in ('RGBA', 'LA', 'P'):
            background = PILImage.new('RGB', img.size, (255, 255, 255))
            if img.mode == 'P':
                img = img.convert('RGBA')
            background.paste(img, mask=img.split()[-1] if 'A' in img.mode else None)
            img = background
        elif img.mode != 'RGB':
            img = img.convert('RGB')

        # Save as WebP to buffer
        buffer = io.BytesIO()
        img.save(buffer, format='WEBP', quality=85, method=4)
        buffer.seek(0)

        # Generate filename
        timestamp = timezone.now().strftime('%Y%m%d_%H%M%S')
        if original_path:
            base_name = os.path.splitext(os.path.basename(original_path))[0]
            filename = f'cropped/{base_name}_cropped_{timestamp}.webp'
        else:
            filename = f'cropped/cropped_{timestamp}.webp'

        # Save using Django storage
        saved_path = default_storage.save(filename, ContentFile(buffer.read()))
        new_url = default_storage.url(saved_path)

        return JsonResponse({
            'success': True,
            'url': new_url,
            'path': saved_path,
        })

    except ImportError:
        return JsonResponse({'error': 'Pillow is not installed'}, status=500)
    except Exception as e:
        logger.error(f'Image crop save error: {e}')
        return JsonResponse({'error': str(e)}, status=500)


# ═══════════════════════════════════════════════════════════════
#  DASHBOARD WIDGET DATA (AJAX / Lazy Loading)
# ═══════════════════════════════════════════════════════════════

@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def widget_data(request):
    """GET returns JSON data for a specific dashboard widget (lazy loading)."""
    import time
    from django.db import connection

    widget = request.GET.get('widget', '')

    if widget == 'verification_queue':
        pending = VerificationRequest.objects.filter(status='pending').count()
        recent = list(
            VerificationRequest.objects.filter(status='pending')
            .select_related('user')
            .order_by('-created_at')[:5]
        )
        items = []
        for vr in recent:
            items.append({
                'username': vr.user.get_full_name() or vr.user.username if vr.user else 'Unknown',
                'email': vr.user.email if vr.user else '',
                'submitted_at': vr.created_at.strftime('%b %d, %Y') if vr.created_at else '',
                'badge_type': vr.badge_type or 'N/A',
            })
        return JsonResponse({
            'pending_count': pending,
            'items': items,
        })

    elif widget == 'system_status':
        # DB connection check
        db_ok = False
        db_latency = 0
        try:
            start = time.time()
            with connection.cursor() as cursor:
                cursor.execute("SELECT 1")
            db_latency = round((time.time() - start) * 1000, 1)
            db_ok = True
        except Exception:
            pass

        # Last backup time
        last_backup = None
        try:
            backup = DatabaseBackup.objects.filter(status='completed').order_by('-created_at').first()
            if backup:
                last_backup = backup.created_at.strftime('%b %d, %Y %H:%M')
        except Exception:
            pass

        # Disk usage
        disk_percent = 0
        try:
            import shutil
            total, used, free = shutil.disk_usage('/')
            disk_percent = round((used / total) * 100, 1)
        except Exception:
            pass

        return JsonResponse({
            'db_connected': db_ok,
            'db_latency_ms': db_latency,
            'last_backup': last_backup,
            'disk_percent': disk_percent,
        })

    elif widget == 'upcoming_events':
        now = timezone.now()
        upcoming = (
            Event.objects.filter(event_date__gte=now, is_active=True)
            .order_by('event_date')[:5]
        )
        items = []
        for event in upcoming:
            # Count registrations by matching event title
            reg_count = EventSubmission.objects.filter(
                event_registration__event_title__icontains=event.name[:50]
            ).count()
            items.append({
                'name': event.name,
                'date': event.event_date.strftime('%b %d, %Y %H:%M') if event.event_date else '',
                'address': (event.address[:50] + '...') if len(event.address) > 50 else event.address,
                'is_active': event.is_active,
                'registration_count': reg_count,
            })
        return JsonResponse({'items': items})

    return JsonResponse({'error': 'Unknown widget type'}, status=400)


# ═══════════════════════════════════════════════════════════════
#  CONTENT CALENDAR
# ═══════════════════════════════════════════════════════════════

@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def content_calendar(request):
    import json
    import calendar as cal_module
    from datetime import date, timedelta

    # Parse month query param (format: YYYY-MM), default to current month
    month_param = request.GET.get('month', '')
    today = date.today()
    try:
        year, month = [int(x) for x in month_param.split('-')]
        current_date = date(year, month, 1)
    except (ValueError, TypeError):
        current_date = date(today.year, today.month, 1)

    year = current_date.year
    month = current_date.month

    # Calculate first and last day of month
    _, days_in_month = cal_module.monthrange(year, month)
    month_start = date(year, month, 1)
    month_end = date(year, month, days_in_month)

    # Build calendar grid (includes days from prev/next months to fill the grid)
    # Find the Sunday that starts the calendar grid
    first_weekday = month_start.weekday()  # Monday=0, Sunday=6
    # Convert to Sunday-based: Sunday=0
    first_weekday_sunday = (first_weekday + 1) % 7
    grid_start = month_start - timedelta(days=first_weekday_sunday)

    # Find the Saturday that ends the calendar grid
    last_weekday = month_end.weekday()
    last_weekday_sunday = (last_weekday + 1) % 7
    grid_end = month_end + timedelta(days=(6 - last_weekday_sunday))

    # Build calendar_days list
    calendar_days = []
    d = grid_start
    while d <= grid_end:
        calendar_days.append({
            'date': d.strftime('%Y-%m-%d'),
            'day': d.day,
            'current_month': d.month == month and d.year == year,
            'date_label': d.strftime('%A, %B %d, %Y'),
        })
        d += timedelta(days=1)

    # Query content for the grid date range (use timezone-aware datetimes)
    from django.utils.timezone import make_aware
    from datetime import datetime
    grid_start_dt = make_aware(datetime.combine(grid_start, datetime.min.time()))
    grid_end_dt = make_aware(datetime.combine(grid_end, datetime.max.time()))

    items = []

    # Articles (publish_date is DateTimeField)
    for a in Article.objects.filter(publish_date__range=(grid_start_dt, grid_end_dt)):
        items.append({
            'type': 'article',
            'title': a.title,
            'id': a.pk,
            'date': a.publish_date.strftime('%Y-%m-%d'),
            'time': a.publish_date.strftime('%H:%M'),
        })

    # Events (event_date is DateTimeField)
    for e in Event.objects.filter(event_date__range=(grid_start_dt, grid_end_dt)):
        items.append({
            'type': 'event',
            'title': e.name,
            'id': e.pk,
            'date': e.event_date.strftime('%Y-%m-%d'),
            'time': e.event_date.strftime('%H:%M'),
        })

    # Magazines (publish_date is DateField)
    for m in MagazineEdition.objects.filter(publish_date__range=(grid_start, grid_end)):
        items.append({
            'type': 'magazine',
            'title': m.title,
            'id': m.pk,
            'date': m.publish_date.strftime('%Y-%m-%d'),
            'time': '',
        })

    # Live Feeds (scheduled_time is DateTimeField, nullable)
    live_feeds_qs = LiveFeed.objects.filter(
        scheduled_time__range=(grid_start_dt, grid_end_dt)
    )
    for lf in live_feeds_qs:
        items.append({
            'type': 'livefeed',
            'title': lf.title,
            'id': lf.pk,
            'date': lf.scheduled_time.strftime('%Y-%m-%d'),
            'time': lf.scheduled_time.strftime('%H:%M'),
        })
    # Also include live feeds without scheduled_time using created_at
    live_feeds_no_sched = LiveFeed.objects.filter(
        scheduled_time__isnull=True,
        created_at__range=(grid_start_dt, grid_end_dt),
    )
    for lf in live_feeds_no_sched:
        items.append({
            'type': 'livefeed',
            'title': lf.title,
            'id': lf.pk,
            'date': lf.created_at.strftime('%Y-%m-%d'),
            'time': lf.created_at.strftime('%H:%M'),
        })

    # Videos (publish_date is DateTimeField)
    for v in Video.objects.filter(publish_date__range=(grid_start_dt, grid_end_dt)):
        items.append({
            'type': 'video',
            'title': v.title,
            'id': v.pk,
            'date': v.publish_date.strftime('%Y-%m-%d'),
            'time': v.publish_date.strftime('%H:%M'),
        })

    # Scheduled Maintenance (starts_at is DateTimeField)
    for sm in ScheduledMaintenance.objects.filter(starts_at__range=(grid_start_dt, grid_end_dt)):
        items.append({
            'type': 'maintenance',
            'title': sm.title,
            'id': sm.pk,
            'date': sm.starts_at.strftime('%Y-%m-%d'),
            'time': sm.starts_at.strftime('%H:%M'),
        })

    # Build calendar data JSON for the template
    calendar_data_json = {
        'items': items,
        'calendar_days': calendar_days,
        'today': today.strftime('%Y-%m-%d'),
    }

    # Month navigation
    if month == 1:
        prev_month = f'{year - 1}-12'
    else:
        prev_month = f'{year}-{month - 1:02d}'
    if month == 12:
        next_month = f'{year + 1}-01'
    else:
        next_month = f'{year}-{month + 1:02d}'

    current_month_str = f'{year}-{month:02d}'
    today_month = f'{today.year}-{today.month:02d}'

    # Month picker options (12 months back, 12 months forward)
    month_options = []
    for offset in range(-12, 13):
        m = today.month + offset
        y = today.year
        while m < 1:
            m += 12
            y -= 1
        while m > 12:
            m -= 12
            y += 1
        val = f'{y}-{m:02d}'
        label = date(y, m, 1).strftime('%B %Y')
        month_options.append({'value': val, 'label': label})

    display_month = current_date.strftime('%B %Y')

    context = {
        'calendar_data_json': calendar_data_json,
        'prev_month': prev_month,
        'next_month': next_month,
        'current_month': current_month_str,
        'today_month': today_month,
        'month_options': month_options,
        'display_month': display_month,
    }
    return render(request, 'custom_admin/content_calendar.html', context)


# ═══════════════════════════════════════════════════════════════
#  DRAG & DROP REORDER
# ═══════════════════════════════════════════════════════════════

# Map of model keys to configuration for the reorder page
REORDER_MODEL_CONFIG = {
    'hero_slides': {
        'model': HeroSlide,
        'order_field': 'order',
        'title_field': 'label',
        'image_method': lambda obj: obj.image.url if obj.image else None,
        'display_name': 'Hero Slides',
        'back_url': 'custom_admin:hero_slides_list',
        'has_active': True,
        'active_field': 'is_active',
        'icon': 'view_carousel',
    },
    'feature_cards': {
        'model': FeatureCard,
        'order_field': 'order',
        'title_field': 'title',
        'image_method': lambda obj: obj.image.url if obj.image else None,
        'display_name': 'Feature Cards',
        'back_url': 'custom_admin:feature_cards_list',
        'has_active': True,
        'active_field': 'is_active',
        'icon': 'auto_awesome',
    },
    'onboarding_steps': {
        'model': OnboardingStep,
        'order_field': 'order',
        'title_field': 'title',
        'image_method': lambda obj: obj.image.url if obj.image else None,
        'display_name': 'Onboarding Steps',
        'back_url': 'custom_admin:onboarding_steps_list',
        'has_active': True,
        'active_field': 'is_active',
        'icon': 'rocket_launch',
    },
    'gallery_albums': {
        'model': GalleryAlbum,
        'order_field': 'display_order',
        'title_field': 'title',
        'image_method': lambda obj: obj.cover_image.url if obj.cover_image else None,
        'display_name': 'Gallery Albums',
        'back_url': 'custom_admin:gallery_list',
        'has_active': False,
        'active_field': None,
        'icon': 'photo_library',
    },
    'quick_access': {
        'model': QuickAccessMenuItem,
        'order_field': 'order',
        'title_field': 'title_en',
        'image_method': lambda obj: None,
        'display_name': 'Quick Access Menu',
        'back_url': 'custom_admin:quick_access_list',
        'has_active': True,
        'active_field': 'is_active',
        'icon': 'bolt',
    },
}


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def reorder_page(request):
    from django.urls import reverse

    model_key = request.GET.get('model', '')
    config = REORDER_MODEL_CONFIG.get(model_key)

    if not config:
        messages.error(request, f'Unknown model: {model_key}. Valid models: {", ".join(REORDER_MODEL_CONFIG.keys())}')
        return redirect('custom_admin:dashboard')

    Model = config['model']
    order_field = config['order_field']
    items_qs = Model.objects.all().order_by(order_field)

    items = []
    for obj in items_qs:
        item = {
            'id': obj.pk,
            'title': getattr(obj, config['title_field'], ''),
            'image_url': config['image_method'](obj),
            'current_order': getattr(obj, order_field),
            'icon': config.get('icon', 'image'),
            'subtitle': None,
            'is_active': None,
        }
        if config['has_active'] and config['active_field']:
            item['is_active'] = getattr(obj, config['active_field'], None)
        items.append(item)

    context = {
        'model_key': model_key,
        'model_display_name': config['display_name'],
        'items': items,
        'back_url': reverse(config['back_url']),
    }
    return render(request, 'custom_admin/reorder.html', context)


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@require_POST
def reorder_save(request):
    import json as json_module

    try:
        data = json_module.loads(request.body)
    except (json_module.JSONDecodeError, ValueError):
        return JsonResponse({'success': False, 'error': 'Invalid JSON'}, status=400)

    model_key = data.get('model', '')
    config = REORDER_MODEL_CONFIG.get(model_key)

    if not config:
        return JsonResponse({'success': False, 'error': f'Unknown model: {model_key}'}, status=400)

    Model = config['model']
    order_field = config['order_field']
    items_data = data.get('items', [])

    if not items_data:
        return JsonResponse({'success': False, 'error': 'No items provided'}, status=400)

    # Update order for each item
    for item in items_data:
        item_id = item.get('id')
        new_order = item.get('order')
        if item_id is not None and new_order is not None:
            try:
                obj = Model.objects.get(pk=item_id)
                setattr(obj, order_field, new_order)
                obj.save(update_fields=[order_field])
            except Model.DoesNotExist:
                continue

    return JsonResponse({'success': True, 'message': 'Order saved successfully'})


# ═══════════════════════════════════════════════════════════════
#  SCHEDULED MAINTENANCE MANAGEMENT
# ═══════════════════════════════════════════════════════════════

@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def maintenance_management(request):
    now = timezone.now()

    # Determine active maintenance window (includes indefinite windows with no ends_at)
    active_window = ScheduledMaintenance.objects.filter(
        is_active=True,
        starts_at__lte=now,
    ).filter(
        Q(ends_at__gte=now) | Q(ends_at__isnull=True)
    ).first()

    is_maintenance_active = active_window is not None

    # Upcoming windows (future, ordered by start time)
    upcoming_windows = list(ScheduledMaintenance.objects.filter(
        is_active=True,
        starts_at__gt=now,
    ).order_by('starts_at'))

    # Next upcoming (for countdown)
    next_upcoming = upcoming_windows[0] if upcoming_windows else None

    # Past windows (ended, ordered by most recent first) — only windows with an end time
    past_windows = list(ScheduledMaintenance.objects.filter(
        ends_at__isnull=False,
        ends_at__lt=now,
    ).order_by('-ends_at'))

    # Total count
    total_count = ScheduledMaintenance.objects.count()

    # Service choices for the form
    service_choices = ScheduledMaintenance.AFFECTED_SERVICES_CHOICES

    # Check if editing an existing window
    editing_window = None
    edit_pk = request.GET.get('edit')
    if edit_pk:
        try:
            editing_window = ScheduledMaintenance.objects.get(pk=edit_pk)
        except ScheduledMaintenance.DoesNotExist:
            pass

    context = {
        'is_maintenance_active': is_maintenance_active,
        'active_window': active_window,
        'upcoming_windows': upcoming_windows,
        'next_upcoming': next_upcoming,
        'past_windows': past_windows,
        'total_count': total_count,
        'service_choices': service_choices,
        'editing_window': editing_window,
    }
    return render(request, 'custom_admin/maintenance/management.html', context)


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@require_POST
def maintenance_toggle(request):
    now = timezone.now()

    # Find currently active maintenance window (including indefinite ones)
    active_window = ScheduledMaintenance.objects.filter(
        is_active=True,
        starts_at__lte=now,
    ).filter(
        Q(ends_at__gte=now) | Q(ends_at__isnull=True)
    ).first()

    if active_window:
        # Disable: deactivate the current window
        active_window.is_active = False
        active_window.save(update_fields=['is_active'])
        messages.success(request, f'Maintenance mode disabled. "{active_window.title}" has been deactivated.')
    else:
        # Enable: create immediate indefinite maintenance (no end time — turn off manually)
        ScheduledMaintenance.objects.create(
            title='Emergency Maintenance',
            title_fr='Maintenance d\'urgence',
            description='Maintenance mode enabled via quick toggle.',
            description_fr='Mode maintenance activé via le bouton rapide.',
            starts_at=now,
            ends_at=None,
            is_active=True,
            show_banner=True,
            severity='major',
            affected_services='all',
        )
        messages.success(request, 'Maintenance mode enabled. Turn it off manually when done.')

    return redirect('custom_admin:maintenance_management')


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@require_POST
def maintenance_schedule(request):
    from django.utils.dateparse import parse_datetime
    from django.utils.timezone import make_aware, is_naive

    title = request.POST.get('title', '').strip()
    title_fr = request.POST.get('title_fr', '').strip()
    description = request.POST.get('description', '').strip()
    description_fr = request.POST.get('description_fr', '').strip()
    starts_at_str = request.POST.get('starts_at', '')
    ends_at_str = request.POST.get('ends_at', '')
    contact_email = request.POST.get('contact_email', '').strip()
    severity = request.POST.get('severity', 'minor')
    is_active = request.POST.get('is_active') == 'on'
    show_banner = request.POST.get('show_banner') == 'on'
    auto_activate = request.POST.get('auto_activate') == 'on'

    # Affected services (multi-checkbox)
    affected_services_list = request.POST.getlist('affected_services')
    affected_services = ','.join(affected_services_list) if affected_services_list else 'all'

    if not title or not starts_at_str:
        messages.error(request, 'Title and start date are required.')
        return redirect('custom_admin:maintenance_management')

    # Parse datetime strings from HTML datetime-local inputs
    starts_at_dt = parse_datetime(starts_at_str)
    if not starts_at_dt:
        messages.error(request, 'Invalid date format for start date.')
        return redirect('custom_admin:maintenance_management')
    if is_naive(starts_at_dt):
        starts_at_dt = make_aware(starts_at_dt)

    # ends_at is optional — leave empty for indefinite maintenance
    ends_at_dt = None
    if ends_at_str:
        ends_at_dt = parse_datetime(ends_at_str)
        if not ends_at_dt:
            messages.error(request, 'Invalid date format for end date.')
            return redirect('custom_admin:maintenance_management')
        if is_naive(ends_at_dt):
            ends_at_dt = make_aware(ends_at_dt)

    # Handle image upload
    image_file = request.FILES.get('image')

    # Check if editing existing window
    pk = request.POST.get('pk')
    if pk:
        try:
            window = ScheduledMaintenance.objects.get(pk=pk)
            window.title = title
            window.title_fr = title_fr
            window.description = description
            window.description_fr = description_fr
            window.starts_at = starts_at_dt
            window.ends_at = ends_at_dt
            window.contact_email = contact_email
            window.severity = severity
            window.is_active = is_active
            window.show_banner = show_banner
            window.auto_activate = auto_activate
            window.affected_services = affected_services
            if image_file:
                window.image = image_file
            window.save()
            messages.success(request, f'Maintenance window "{title}" updated successfully.')
        except ScheduledMaintenance.DoesNotExist:
            messages.error(request, 'Maintenance window not found.')
    else:
        window = ScheduledMaintenance.objects.create(
            title=title,
            title_fr=title_fr,
            description=description,
            description_fr=description_fr,
            starts_at=starts_at_dt,
            ends_at=ends_at_dt,
            contact_email=contact_email,
            severity=severity,
            is_active=is_active,
            show_banner=show_banner,
            auto_activate=auto_activate,
            affected_services=affected_services,
        )
        if image_file:
            window.image = image_file
            window.save()
        messages.success(request, f'Maintenance window "{title}" scheduled successfully.')

    return redirect('custom_admin:maintenance_management')


# ══════════════════════════════════════════════════════════════
# A/B TESTING MANAGEMENT
# ══════════════════════════════════════════════════════════════

@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def ab_test_list(request):
    """List all A/B tests."""
    tests_qs = (
        ABTest.objects
        .annotate(participant_count=Count('participants'))
        .order_by('-created_at')
    )
    paginator = Paginator(tests_qs, 20)
    page = request.GET.get('page')
    tests = paginator.get_page(page)

    context = {
        'tests': tests,
        'total_tests': tests_qs.count(),
        'running_tests': tests_qs.filter(status='running').count(),
        'draft_tests': tests_qs.filter(status='draft').count(),
        'completed_tests': tests_qs.filter(status='completed').count(),
    }
    return render(request, 'custom_admin/ab_tests/list.html', context)


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def ab_test_create(request):
    """Create a new A/B test."""
    if request.method == 'POST':
        name = request.POST.get('name', '').strip()
        description = request.POST.get('description', '').strip()
        test_type = request.POST.get('test_type', 'content')
        status = request.POST.get('status', 'draft')
        traffic_split = int(request.POST.get('traffic_split', 50))
        variant_a_label = request.POST.get('variant_a_label', 'Control').strip()
        variant_b_label = request.POST.get('variant_b_label', 'Variant').strip()
        variant_a_content_id = request.POST.get('variant_a_content_id', '').strip()
        variant_b_content_id = request.POST.get('variant_b_content_id', '').strip()
        started_at = request.POST.get('started_at', '').strip()
        ended_at = request.POST.get('ended_at', '').strip()

        if not name:
            messages.error(request, 'Name is required.')
            return render(request, 'custom_admin/ab_tests/form.html', {
                'action': 'Create', 'test': None,
            })

        test = ABTest.objects.create(
            name=name,
            description=description,
            test_type=test_type,
            status=status,
            traffic_split=max(0, min(100, traffic_split)),
            variant_a_label=variant_a_label or 'Control',
            variant_b_label=variant_b_label or 'Variant',
            variant_a_content_id=int(variant_a_content_id) if variant_a_content_id else None,
            variant_b_content_id=int(variant_b_content_id) if variant_b_content_id else None,
            is_active=(status == 'running'),
            started_at=started_at or None,
            ended_at=ended_at or None,
        )
        messages.success(request, f'A/B test "{name}" created successfully.')
        return redirect('custom_admin:ab_test_list')

    return render(request, 'custom_admin/ab_tests/form.html', {
        'action': 'Create', 'test': None,
    })


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def ab_test_edit(request, pk):
    """Edit an existing A/B test."""
    test = get_object_or_404(ABTest, pk=pk)

    if request.method == 'POST':
        test.name = request.POST.get('name', test.name).strip()
        test.description = request.POST.get('description', test.description).strip()
        test.test_type = request.POST.get('test_type', test.test_type)
        test.status = request.POST.get('status', test.status)
        test.traffic_split = max(0, min(100, int(request.POST.get('traffic_split', test.traffic_split))))
        test.variant_a_label = request.POST.get('variant_a_label', test.variant_a_label).strip() or 'Control'
        test.variant_b_label = request.POST.get('variant_b_label', test.variant_b_label).strip() or 'Variant'

        variant_a_content_id = request.POST.get('variant_a_content_id', '').strip()
        variant_b_content_id = request.POST.get('variant_b_content_id', '').strip()
        test.variant_a_content_id = int(variant_a_content_id) if variant_a_content_id else None
        test.variant_b_content_id = int(variant_b_content_id) if variant_b_content_id else None

        started_at = request.POST.get('started_at', '').strip()
        ended_at = request.POST.get('ended_at', '').strip()
        if started_at:
            test.started_at = started_at
        if ended_at:
            test.ended_at = ended_at

        # Auto-set started_at when transitioning to running
        if test.status == 'running' and not test.started_at:
            test.started_at = timezone.now()
        # Auto-set ended_at when completing
        if test.status == 'completed' and not test.ended_at:
            test.ended_at = timezone.now()

        test.is_active = (test.status == 'running')
        test.save()

        messages.success(request, f'A/B test "{test.name}" updated successfully.')

        # Support redirect back to detail page
        if request.POST.get('_redirect') == 'detail':
            return redirect('custom_admin:ab_test_detail', pk=pk)
        return redirect('custom_admin:ab_test_list')

    return render(request, 'custom_admin/ab_tests/form.html', {
        'action': 'Edit', 'test': test,
    })


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def ab_test_detail(request, pk):
    """View A/B test details and results."""
    test = get_object_or_404(ABTest, pk=pk)

    variant_a_participants = test.participants.filter(variant='A')
    variant_b_participants = test.participants.filter(variant='B')

    variant_a_count = variant_a_participants.count()
    variant_b_count = variant_b_participants.count()
    variant_a_conversions = variant_a_participants.filter(converted=True).count()
    variant_b_conversions = variant_b_participants.filter(converted=True).count()

    total_participants = variant_a_count + variant_b_count
    total_conversions = variant_a_conversions + variant_b_conversions

    variant_a_rate = round((variant_a_conversions / variant_a_count * 100), 1) if variant_a_count > 0 else 0
    variant_b_rate = round((variant_b_conversions / variant_b_count * 100), 1) if variant_b_count > 0 else 0

    context = {
        'test': test,
        'variant_a_count': variant_a_count,
        'variant_b_count': variant_b_count,
        'variant_a_conversions': variant_a_conversions,
        'variant_b_conversions': variant_b_conversions,
        'variant_a_rate': variant_a_rate,
        'variant_b_rate': variant_b_rate,
        'variant_a_pct': 100 - test.traffic_split,
        'total_participants': total_participants,
        'total_conversions': total_conversions,
    }
    return render(request, 'custom_admin/ab_tests/detail.html', context)


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@require_POST
def ab_test_delete(request, pk):
    """Delete an A/B test."""
    test = get_object_or_404(ABTest, pk=pk)
    name = test.name
    test.delete()
    messages.success(request, f'A/B test "{name}" deleted.')
    return redirect('custom_admin:ab_test_list')


# ══════════════════════════════════════════════════════════════
# WEBHOOK INTEGRATIONS MANAGEMENT
# ══════════════════════════════════════════════════════════════

@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def webhook_list(request):
    """List all webhooks."""
    webhooks_qs = Webhook.objects.all()

    # Add masked URL property to each webhook for display
    webhook_items = list(webhooks_qs)
    for wh in webhook_items:
        wh.masked_url = _mask_url(wh.url)

    paginator = Paginator(webhook_items, 20)
    page = request.GET.get('page')
    webhooks = paginator.get_page(page)

    context = {
        'webhooks': webhooks,
        'total_webhooks': webhooks_qs.count(),
        'active_webhooks': webhooks_qs.filter(is_active=True).count(),
        'failing_webhooks': webhooks_qs.filter(failure_count__gt=3).count(),
    }
    return render(request, 'custom_admin/webhooks/list.html', context)


def _mask_url(url):
    """Partially mask a webhook URL for display."""
    if not url:
        return ''
    if len(url) <= 30:
        return url
    return url[:25] + '...' + url[-8:]


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def webhook_create(request):
    """Create a new webhook."""
    event_choices = Webhook.EVENT_CHOICES

    if request.method == 'POST':
        name = request.POST.get('name', '').strip()
        url = request.POST.get('url', '').strip()
        service_type = request.POST.get('service_type', 'custom')
        secret_key = request.POST.get('secret_key', '').strip()
        events = request.POST.getlist('events')

        # Build custom headers from key-value pairs
        header_keys = request.POST.getlist('header_keys[]')
        header_values = request.POST.getlist('header_values[]')
        custom_headers = {}
        for k, v in zip(header_keys, header_values):
            k = k.strip()
            v = v.strip()
            if k:
                custom_headers[k] = v

        if not name or not url:
            messages.error(request, 'Name and URL are required.')
            return render(request, 'custom_admin/webhooks/form.html', {
                'action': 'Create', 'webhook': None,
                'event_choices': event_choices, 'selected_events': events,
            })

        # SSRF guard: reject URLs targeting private/internal networks
        from core.webhooks import _validate_webhook_url
        try:
            _validate_webhook_url(url)
        except ValueError as e:
            messages.error(request, f'Invalid webhook URL: {e}')
            return render(request, 'custom_admin/webhooks/form.html', {
                'action': 'Create', 'webhook': None,
                'event_choices': event_choices, 'selected_events': events,
            })

        Webhook.objects.create(
            name=name,
            url=url,
            service_type=service_type,
            events=events,
            secret_key=secret_key,
            custom_headers=custom_headers,
        )
        messages.success(request, f'Webhook "{name}" created successfully.')
        return redirect('custom_admin:webhook_list')

    return render(request, 'custom_admin/webhooks/form.html', {
        'action': 'Create', 'webhook': None,
        'event_choices': event_choices, 'selected_events': [],
    })


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def webhook_edit(request, pk):
    """Edit an existing webhook."""
    webhook = get_object_or_404(Webhook, pk=pk)
    event_choices = Webhook.EVENT_CHOICES

    if request.method == 'POST':
        webhook.name = request.POST.get('name', webhook.name).strip()
        webhook.url = request.POST.get('url', webhook.url).strip()
        webhook.service_type = request.POST.get('service_type', webhook.service_type)
        webhook.secret_key = request.POST.get('secret_key', webhook.secret_key).strip()
        webhook.events = request.POST.getlist('events')

        # Build custom headers from key-value pairs
        header_keys = request.POST.getlist('header_keys[]')
        header_values = request.POST.getlist('header_values[]')
        custom_headers = {}
        for k, v in zip(header_keys, header_values):
            k = k.strip()
            v = v.strip()
            if k:
                custom_headers[k] = v
        webhook.custom_headers = custom_headers

        # SSRF guard: reject URLs targeting private/internal networks
        from core.webhooks import _validate_webhook_url
        try:
            _validate_webhook_url(webhook.url)
        except ValueError as e:
            messages.error(request, f'Invalid webhook URL: {e}')
            selected_events = webhook.events if isinstance(webhook.events, list) else []
            return render(request, 'custom_admin/webhooks/form.html', {
                'action': 'Edit', 'webhook': webhook,
                'event_choices': event_choices, 'selected_events': selected_events,
            })

        webhook.save()
        messages.success(request, f'Webhook "{webhook.name}" updated successfully.')
        return redirect('custom_admin:webhook_list')

    selected_events = webhook.events if isinstance(webhook.events, list) else []
    return render(request, 'custom_admin/webhooks/form.html', {
        'action': 'Edit', 'webhook': webhook,
        'event_choices': event_choices, 'selected_events': selected_events,
    })


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@require_POST
def webhook_delete(request, pk):
    """Delete a webhook."""
    webhook = get_object_or_404(Webhook, pk=pk)
    name = webhook.name
    webhook.delete()
    messages.success(request, f'Webhook "{name}" deleted.')
    return redirect('custom_admin:webhook_list')


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@require_POST
def webhook_toggle(request, pk):
    """Toggle a webhook active/inactive."""
    webhook = get_object_or_404(Webhook, pk=pk)
    webhook.is_active = not webhook.is_active
    webhook.save(update_fields=['is_active'])
    status_str = 'activated' if webhook.is_active else 'deactivated'
    messages.success(request, f'Webhook "{webhook.name}" {status_str}.')
    return redirect('custom_admin:webhook_list')


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def webhook_logs(request, pk):
    """View delivery logs for a webhook."""
    webhook = get_object_or_404(Webhook, pk=pk)
    logs_qs = webhook.logs.all()

    # Add pretty-printed payload to each log for template use
    log_items = list(logs_qs)
    for log in log_items:
        try:
            log.payload_pretty = json.dumps(log.payload, indent=2, default=str)
        except (TypeError, ValueError):
            log.payload_pretty = str(log.payload)

    paginator = Paginator(log_items, 25)
    page = request.GET.get('page')
    logs = paginator.get_page(page)

    context = {
        'webhook': webhook,
        'logs': logs,
        'success_count': logs_qs.filter(success=True).count(),
        'fail_count': logs_qs.filter(success=False).count(),
    }
    return render(request, 'custom_admin/webhooks/logs.html', context)


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@require_POST
def webhook_test(request, pk):
    """Send a test payload to a webhook."""
    webhook = get_object_or_404(Webhook, pk=pk)

    from core.webhooks import send_test_webhook
    success, status_code, error = send_test_webhook(webhook)

    # Handle AJAX requests
    if request.headers.get('X-Requested-With') == 'XMLHttpRequest':
        return JsonResponse({
            'success': success,
            'status_code': status_code,
            'error': error,
        })

    if success:
        messages.success(request, f'Test webhook sent successfully (HTTP {status_code}).')
    else:
        messages.error(request, f'Test webhook failed: {error}')

    return redirect('custom_admin:webhook_list')


# ═══════════════════════════════════════════════════════════════
#  TRANSLATION QUEUE (#46)
# ═══════════════════════════════════════════════════════════════

@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def translation_queue_list(request):
    """Admin view for the translation queue."""
    status_filter = request.GET.get('status')
    qs = TranslationRequest.objects.select_related('assigned_to').all()
    if status_filter:
        qs = qs.filter(status=status_filter)

    total = TranslationRequest.objects.count()
    pending = TranslationRequest.objects.filter(status='pending').count()
    in_progress = TranslationRequest.objects.filter(status='in_progress').count()
    completed = TranslationRequest.objects.filter(status='completed').count()

    paginator = Paginator(qs, 20)
    page = request.GET.get('page')
    items = paginator.get_page(page)

    staff_users = User.objects.filter(is_staff=True).order_by('username')

    return render(request, 'custom_admin/translation_queue/list.html', {
        'items': items,
        'total': total,
        'pending': pending,
        'in_progress': in_progress,
        'completed': completed,
        'current_filter': status_filter or 'all',
        'staff_users': staff_users,
    })


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@require_POST
def translation_queue_update(request, pk):
    """Update a translation request status/assignment."""
    tr = get_object_or_404(TranslationRequest, pk=pk)
    new_status = request.POST.get('status')
    assigned_to_id = request.POST.get('assigned_to')
    notes = request.POST.get('notes', '')

    if new_status:
        tr.status = new_status
        if new_status == 'completed':
            tr.completed_at = timezone.now()
    if assigned_to_id:
        tr.assigned_to_id = int(assigned_to_id) if assigned_to_id else None
    if notes:
        tr.notes = notes
    tr.save()

    messages.success(request, f'Translation request #{tr.pk} updated.')
    return redirect('custom_admin:translation_queue_list')


# ==============================================================
#  COMMENTS MANAGEMENT
# ==============================================================


COMMENT_MODEL_MAP = {
    'article': ArticleComment,
    'event': EventComment,
    'magazine': MagazineComment,
    'livefeed': LiveFeedComment,
    'video': VideoComment,
    'gallery': GalleryComment,
    'discussion': DiscussionReply,
}

# (Model, type_key, content_fk, title_accessor, user_field)
_COMMENT_SOURCES = [
    (ArticleComment, 'article', 'article', lambda c: c.article.title, 'user'),
    (EventComment, 'event', 'event', lambda c: c.event.name, 'user'),
    (MagazineComment, 'magazine', 'edition', lambda c: c.edition.title, 'user'),
    (LiveFeedComment, 'livefeed', 'feed', lambda c: c.feed.title, 'user'),
    (VideoComment, 'video', 'video', lambda c: c.video.title, 'user'),
    (GalleryComment, 'gallery', 'album', lambda c: c.album.title, 'user'),
    (DiscussionReply, 'discussion', 'discussion', lambda c: c.discussion.title, 'author'),
]


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def comments_list(request):
    """List all comments across all 7 content types with filters."""
    content_filter = request.GET.get('type', 'all')
    search_query = request.GET.get('q', '').strip()

    # Build querysets for each type with search filtering
    type_counts = {}
    querysets = {}
    for model, type_key, content_fk, title_fn, user_field in _COMMENT_SOURCES:
        qs = model.objects.select_related(user_field, content_fk).all()
        if search_query:
            q_filter = (
                Q(content__icontains=search_query)
                | Q(**{f'{user_field}__username__icontains': search_query})
                | Q(**{f'{user_field}__first_name__icontains': search_query})
                | Q(**{f'{user_field}__last_name__icontains': search_query})
            )
            # Add content title search
            if content_fk == 'event':
                q_filter |= Q(event__name__icontains=search_query)
            elif content_fk == 'edition':
                q_filter |= Q(edition__title__icontains=search_query)
            elif content_fk == 'feed':
                q_filter |= Q(feed__title__icontains=search_query)
            elif content_fk == 'album':
                q_filter |= Q(album__title__icontains=search_query)
            else:
                q_filter |= Q(**{f'{content_fk}__title__icontains': search_query})
            qs = qs.filter(q_filter)
        type_counts[type_key] = qs.count()
        querysets[type_key] = qs

    total_all = sum(type_counts.values())

    # Build unified list based on filter
    unified = []
    for model, type_key, content_fk, title_fn, user_field in _COMMENT_SOURCES:
        if content_filter != 'all' and content_filter != type_key:
            continue
        for c in querysets[type_key]:
            user = getattr(c, user_field)
            profile = getattr(user, 'profile', None)
            content_obj = getattr(c, content_fk)
            unified.append({
                'pk': c.pk,
                'content': c.content,
                'user': user,
                'content_type': type_key,
                'content_title': title_fn(c),
                'content_pk': content_obj.pk,
                'created_at': c.created_at,
                'is_banned': getattr(profile, 'is_comment_banned', False),
                'reference_id': getattr(profile, 'reference_id', ''),
            })

    unified.sort(key=lambda x: x['created_at'], reverse=True)
    paginator = Paginator(unified, 25)
    page = request.GET.get('page')
    comments_page = paginator.get_page(page)
    return render(request, 'custom_admin/comments/list.html', {
        'comments': comments_page,
        'total_all': total_all,
        'type_counts': type_counts,
        'current_filter': content_filter,
        'search_query': search_query,
    })


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@require_POST
def comment_delete(request, pk):
    """Delete a specific comment of any type."""
    comment_type = request.POST.get('comment_type', 'article')
    model = COMMENT_MODEL_MAP.get(comment_type)
    if not model:
        messages.error(request, 'Invalid comment type.')
        return redirect('custom_admin:comments_list')
    comment = get_object_or_404(model, pk=pk)
    user_field = 'author' if comment_type == 'discussion' else 'user'
    username = getattr(comment, user_field).username
    comment.delete()
    messages.success(request, f'Deleted {comment_type} comment by {username}.')
    return redirect('custom_admin:comments_list')


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@require_POST
def comment_bulk_delete(request):
    """Bulk delete selected comments across all types."""
    deleted_count = 0
    for type_key, model in COMMENT_MODEL_MAP.items():
        ids = request.POST.getlist(f'{type_key}_ids')
        if ids:
            pks = [int(x) for x in ids if x.isdigit()]
            count, _ = model.objects.filter(pk__in=pks).delete()
            deleted_count += count
    if deleted_count:
        messages.success(request, f'{deleted_count} comment(s) deleted successfully.')
    else:
        messages.warning(request, 'No comments were selected for deletion.')
    return redirect('custom_admin:comments_list')


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@require_POST
def comment_toggle_ban(request, user_pk):
    """Toggle comment ban on a user from the comments management page."""
    target_user = get_object_or_404(User, pk=user_pk)
    profile = target_user.profile

    if profile.is_comment_banned:
        old_strikes = profile.profanity_strikes
        profile.is_comment_banned = False
        profile.comment_banned_at = None
        profile.profanity_strikes = 0
        profile.save(update_fields=['is_comment_banned', 'comment_banned_at', 'profanity_strikes'])
        if profile.device_id:
            DeviceBan.objects.filter(device_id=profile.device_id, is_active=True).update(
                is_active=False,
                unbanned_at=timezone.now(),
                unbanned_by=request.user,
            )
        log_admin_action(
            request, 'status_change', 'User', object_id=user_pk,
            object_repr=target_user.username,
            changes={
                'is_comment_banned': {'old': 'True', 'new': 'False'},
                'profanity_strikes': {'old': str(old_strikes), 'new': '0'},
            }
        )
        messages.success(request, f'Comment ban lifted for "{target_user.username}". Strikes reset to 0.')
    else:
        profile.is_comment_banned = True
        profile.comment_banned_at = timezone.now()
        profile.save(update_fields=['is_comment_banned', 'comment_banned_at'])
        if profile.device_id:
            DeviceBan.objects.get_or_create(
                device_id=profile.device_id,
                defaults={
                    'user': target_user,
                    'reason': f'Manual ban by admin {request.user.username}',
                },
            )
        log_admin_action(
            request, 'status_change', 'User', object_id=user_pk,
            object_repr=target_user.username,
            changes={'is_comment_banned': {'old': 'False', 'new': 'True'}}
        )
        messages.success(request, f'User "{target_user.username}" has been banned from commenting.')

    return redirect('custom_admin:comments_list')


@login_required(login_url='/admin/')
@user_passes_test(lambda u: u.is_staff)
def error_tracking_dashboard(request):
    """Sentry error tracking dashboard - shows issues from Sentry API."""
    from django.conf import settings as django_settings

    sentry_configured = bool(
        getattr(django_settings, 'SENTRY_AUTH_TOKEN', '') and
        getattr(django_settings, 'SENTRY_ORG', '') and
        getattr(django_settings, 'SENTRY_PROJECT', '')
    )

    return render(request, 'custom_admin/error_tracking.html', {
        'sentry_configured': sentry_configured,
        'sentry_dsn_set': bool(getattr(django_settings, 'SENTRY_DSN', '')),
    })


@login_required(login_url='/admin/')
@user_passes_test(lambda u: u.is_staff)
def error_tracking_api(request):
    """Proxy Sentry API calls to avoid exposing auth token to frontend."""
    import urllib.request
    import urllib.error
    import json
    from django.conf import settings as django_settings

    auth_token = getattr(django_settings, 'SENTRY_AUTH_TOKEN', '')
    org = getattr(django_settings, 'SENTRY_ORG', '')
    project = getattr(django_settings, 'SENTRY_PROJECT', '')
    api_base = getattr(django_settings, 'SENTRY_API_BASE', 'https://de.sentry.io/api/0')

    if not all([auth_token, org, project]):
        return JsonResponse({'error': 'Sentry API not configured. Set SENTRY_AUTH_TOKEN, SENTRY_ORG, and SENTRY_PROJECT environment variables.'}, status=400)

    # Which endpoint to proxy
    endpoint = request.GET.get('endpoint', 'issues')
    query = request.GET.get('query', 'is:unresolved')
    cursor = request.GET.get('cursor', '')
    sort = request.GET.get('sort', 'date')

    # Handle different actions (resolve, ignore)
    if request.method == 'POST':
        action = request.POST.get('action', '')
        issue_id = request.POST.get('issue_id', '')
        if action and issue_id:
            try:
                url = f'{api_base}/issues/{issue_id}/'
                if action == 'resolve':
                    data = json.dumps({'status': 'resolved'}).encode()
                elif action == 'ignore':
                    data = json.dumps({'status': 'ignored'}).encode()
                elif action == 'unresolve':
                    data = json.dumps({'status': 'unresolved'}).encode()
                else:
                    return JsonResponse({'error': 'Invalid action'}, status=400)

                req = urllib.request.Request(url, data=data, method='PUT')
                req.add_header('Authorization', f'Bearer {auth_token}')
                req.add_header('Content-Type', 'application/json')
                with urllib.request.urlopen(req, timeout=10) as resp:
                    result = json.loads(resp.read())
                log_admin_action(request, 'sentry_action', 'ErrorTracking',
                    object_repr=f'Issue {issue_id}: {action}')
                return JsonResponse({'success': True, 'status': result.get('status', '')})
            except Exception as e:
                return JsonResponse({'error': str(e)}, status=500)

    # Build Sentry API URL
    if endpoint == 'issues':
        url = f'{api_base}/projects/{org}/{project}/issues/?query={urllib.parse.quote(query)}&sort={sort}'
        if cursor:
            url += f'&cursor={cursor}'
    elif endpoint == 'stats':
        stat_type = request.GET.get('stat', 'received')
        url = f'{api_base}/projects/{org}/{project}/stats/?stat={stat_type}&resolution=1d'
    elif endpoint == 'issue_events':
        issue_id = request.GET.get('issue_id', '')
        url = f'{api_base}/issues/{issue_id}/events/'
    else:
        return JsonResponse({'error': 'Invalid endpoint'}, status=400)

    try:
        req = urllib.request.Request(url)
        req.add_header('Authorization', f'Bearer {auth_token}')
        with urllib.request.urlopen(req, timeout=15) as resp:
            data = json.loads(resp.read())
            # Parse Link header for pagination
            link_header = resp.getheader('Link', '')
            pagination = {}
            if link_header:
                for part in link_header.split(','):
                    part = part.strip()
                    if 'rel="next"' in part and 'results="true"' in part:
                        # Extract cursor from URL
                        import re
                        cursor_match = re.search(r'cursor=([^&>]+)', part)
                        if cursor_match:
                            pagination['next_cursor'] = cursor_match.group(1)
                    elif 'rel="previous"' in part and 'results="true"' in part:
                        import re
                        cursor_match = re.search(r'cursor=([^&>]+)', part)
                        if cursor_match:
                            pagination['prev_cursor'] = cursor_match.group(1)

            return JsonResponse({'data': data, 'pagination': pagination})
    except urllib.error.HTTPError as e:
        error_body = e.read().decode() if e.fp else str(e)
        return JsonResponse({'error': f'Sentry API error ({e.code}): {error_body}'}, status=e.code)
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)


@login_required(login_url='/admin/')
@user_passes_test(lambda u: u.is_staff)
def auto_translate(request):
    """Auto-translate text between EN and FR using free translation APIs.
    Uses MyMemory API (free, no key) with LibreTranslate fallback.
    """
    if request.method != 'POST':
        return JsonResponse({'error': 'POST required'}, status=405)

    import urllib.request
    import urllib.parse
    import json

    text = request.POST.get('text', '').strip()
    source_lang = request.POST.get('source', 'en')
    target_lang = request.POST.get('target', 'fr')

    if not text:
        return JsonResponse({'error': 'No text provided'}, status=400)

    if source_lang not in ('en', 'fr') or target_lang not in ('en', 'fr'):
        return JsonResponse({'error': 'Only EN and FR are supported'}, status=400)

    def _translate_chunk(chunk, sl, tl):
        """Try multiple free translation APIs in order."""

        # 1) Google Translate (gtx client — free, no key)
        try:
            encoded = urllib.parse.quote(chunk)
            url = f'https://translate.googleapis.com/translate_a/single?client=gtx&sl={sl}&tl={tl}&dt=t&q={encoded}'
            req = urllib.request.Request(url)
            req.add_header('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36')
            with urllib.request.urlopen(req, timeout=8) as resp:
                data = json.loads(resp.read())
            if data and data[0]:
                result = ''.join(seg[0] for seg in data[0] if seg and seg[0])
                if result and result.strip():
                    return result
        except Exception:
            pass

        # 2) Lingva Translate (Google Translate proxy)
        try:
            encoded = urllib.parse.quote(chunk)
            url = f'https://lingva.ml/api/v1/{sl}/{tl}/{encoded}'
            req = urllib.request.Request(url)
            req.add_header('User-Agent', 'Mozilla/5.0')
            with urllib.request.urlopen(req, timeout=8) as resp:
                data = json.loads(resp.read())
            result = data.get('translation', '')
            if result and result.strip():
                return result
        except Exception:
            pass

        # 3) MyMemory API — check both translatedText and matches
        try:
            encoded = urllib.parse.quote(chunk)
            url = f'https://api.mymemory.translated.net/get?q={encoded}&langpair={sl}|{tl}'
            req = urllib.request.Request(url)
            req.add_header('User-Agent', 'Mozilla/5.0')
            with urllib.request.urlopen(req, timeout=8) as resp:
                data = json.loads(resp.read())
            result = data.get('responseData', {}).get('translatedText', '')
            if result and result.strip():
                return result
            # Fallback: use best match from matches array
            matches = data.get('matches', [])
            for m in matches:
                t = m.get('translation', '')
                if t and t.strip():
                    return t
        except Exception:
            pass

        return None

    try:
        # Split long texts into ~450 char chunks at sentence boundaries
        if len(text) <= 450:
            chunks = [text]
        else:
            chunks = []
            remaining = text
            while remaining:
                if len(remaining) <= 450:
                    chunks.append(remaining)
                    break
                # Find last sentence break before 450 chars
                cut = 450
                for sep in ['. ', '.\n', '! ', '? ', '\n']:
                    pos = remaining[:cut].rfind(sep)
                    if pos > 100:
                        cut = pos + len(sep)
                        break
                chunks.append(remaining[:cut])
                remaining = remaining[cut:]

        translated_parts = []
        for chunk in chunks:
            result = _translate_chunk(chunk, source_lang, target_lang)
            if result:
                translated_parts.append(result)
            else:
                return JsonResponse({'error': 'Translation service unavailable. Please try again later.'}, status=502)

        translated = ''.join(translated_parts)
        return JsonResponse({'translated': translated})

    except Exception as e:
        return JsonResponse({'error': f'Translation failed: {str(e)}'}, status=500)


# ═══════════════════════════════════════════════════════════════
#  NEWSLETTER EDITIONS (browse past newsletters + manual send)
# ═══════════════════════════════════════════════════════════════

@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def newsletter_editions_list(request):
    editions = NewsletterEdition.objects.all().order_by('-created_at')
    paginator = Paginator(editions, 20)
    page = paginator.get_page(request.GET.get('page', 1))
    return render(request, 'custom_admin/newsletters/list.html', {
        'editions': page,
    })


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def newsletter_edition_preview(request, pk):
    edition = get_object_or_404(NewsletterEdition, pk=pk)
    return render(request, 'custom_admin/newsletters/preview.html', {
        'edition': edition,
    })


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@require_POST
def newsletter_send_now(request):
    """Manually trigger the weekly newsletter (synchronous)."""
    from core.tasks import send_weekly_newsletter
    try:
        sent = send_weekly_newsletter()
        if sent:
            messages.success(request, f'Newsletter sent to {sent} subscriber(s).')
        else:
            messages.info(request, 'No newsletter sent — either no content this week or no subscribers.')
    except Exception as e:
        messages.error(request, f'Newsletter send failed: {e}')
    return redirect('custom_admin:newsletter_editions_list')


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def newsletter_subscribers_list(request):
    """Browse monthly newsletter subscribers."""
    from core.models import NewsletterSubscriber
    q = request.GET.get('q', '').strip()
    qs = NewsletterSubscriber.objects.all()
    if q:
        qs = qs.filter(
            models.Q(name__icontains=q) |
            models.Q(email__icontains=q) |
            models.Q(phone_number__icontains=q)
        )
    paginator = Paginator(qs, 50)
    page = paginator.get_page(request.GET.get('page', 1))
    return render(request, 'custom_admin/newsletters/subscribers.html', {
        'subscribers': page,
        'search_query': q,
        'total_active': NewsletterSubscriber.objects.filter(is_active=True).count(),
        'total_all': NewsletterSubscriber.objects.count(),
    })


# ─── Media Library (Browse existing Spaces images) ──────────────
@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@_catch_upload_errors
def media_library_api(request):
    """Return JSON list of images in DO Spaces / local media, grouped by folder."""
    folder_filter = request.GET.get('folder', '').strip()
    search_query = request.GET.get('q', '').strip().lower()

    image_extensions = {'.jpg', '.jpeg', '.png', '.gif', '.webp'}
    results = {}

    try:
        storage = default_storage

        def _scan_directory(prefix):
            """Recursively list files using storage.listdir (works for S3 and local)."""
            try:
                dirs, files = storage.listdir(prefix)
            except Exception as e:
                logger.warning('listdir(%s) failed: %s', prefix, e)
                return

            for filename in files:
                ext = os.path.splitext(filename)[1].lower()
                if ext not in image_extensions:
                    continue
                if search_query and search_query not in filename.lower():
                    continue
                rel_path = os.path.join(prefix, filename) if prefix else filename
                folder = prefix if prefix else 'root'
                if folder_filter and folder != folder_filter and not folder.startswith(folder_filter + '/'):
                    continue
                try:
                    url = storage.url(rel_path)
                except Exception:
                    url = f'{settings.MEDIA_URL}{rel_path}'
                try:
                    size = storage.size(rel_path)
                except Exception:
                    size = 0
                results.setdefault(folder, []).append({
                    'path': rel_path,
                    'filename': filename,
                    'url': url,
                    'size': size,
                })

            for d in dirs:
                sub_prefix = os.path.join(prefix, d) if prefix else d
                if folder_filter and not folder_filter.startswith(sub_prefix) and not sub_prefix.startswith(folder_filter):
                    continue
                _scan_directory(sub_prefix)

        _scan_directory('')

    except Exception as e:
        logger.exception('Media library API error')
        return JsonResponse({'error': str(e)}, status=500)

    # Sort folders and files
    sorted_results = {}
    for folder in sorted(results.keys()):
        sorted_results[folder] = sorted(results[folder], key=lambda x: x['filename'])

    return JsonResponse({
        'folders': sorted_results,
        'folder_names': list(sorted_results.keys()),
    })


# ═══════════════════════════════════════════════════════════════
#  YOUTH DIALOGUE (Multi-Event)
# ═══════════════════════════════════════════════════════════════

@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def youth_dialogue_events_list(request):
    """Landing page: list all Continental Dialogue events."""
    events = YouthDialogueEvent.objects.annotate(
        app_count=Count('applications'),
    ).order_by('-is_active', '-created_at')
    return render(request, 'custom_admin/youth_dialogue/events_list.html', {
        'events': events,
    })


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@_catch_upload_errors
def youth_dialogue_event_form(request, event_pk=None):
    """Create or edit a Continental Dialogue event (settings + form fields)."""
    yd_event = None
    if event_pk:
        yd_event = get_object_or_404(YouthDialogueEvent, pk=event_pk)

    if request.method == 'POST':
        if not yd_event:
            yd_event = YouthDialogueEvent()

        yd_event.programme_title = request.POST.get('programme_title', yd_event.programme_title)
        yd_event.programme_title_fr = request.POST.get('programme_title_fr', '')
        yd_event.description = request.POST.get('description', '')
        yd_event.description_fr = request.POST.get('description_fr', '')
        # Event identity
        slug = request.POST.get('slug', '').strip()
        if slug:
            yd_event.slug = slug
        elif not yd_event.slug:
            from django.utils.text import slugify as django_slugify
            yd_event.slug = django_slugify(yd_event.programme_title)[:120] or 'yd-event'
        yd_event.is_active = request.POST.get('is_active') == 'on'
        yd_event.location = request.POST.get('location', '')
        start_date = request.POST.get('start_date', '').strip()
        end_date = request.POST.get('end_date', '').strip()
        yd_event.start_date = start_date or None
        yd_event.end_date = end_date or None
        # Visibility & Quick Access
        yd_event.is_visible = request.POST.get('is_visible') == 'on'
        yd_event.is_registration_open = request.POST.get('is_registration_open') == 'on'
        yd_event.quick_access_title_en = request.POST.get('quick_access_title_en', 'Continental Dialogue')
        yd_event.quick_access_title_fr = request.POST.get('quick_access_title_fr', '')
        yd_event.registration_closed_message = request.POST.get('registration_closed_message', '')
        yd_event.registration_closed_message_fr = request.POST.get('registration_closed_message_fr', '')
        yd_event.support_email = request.POST.get('support_email', '')
        yd_event.support_phone = request.POST.get('support_phone', '')
        yd_event.live_chat_url = request.POST.get('live_chat_url', '')
        yd_event.support_note = request.POST.get('support_note', '')
        yd_event.support_note_fr = request.POST.get('support_note_fr', '')
        # Landing page content
        yd_event.event_tagline = request.POST.get('event_tagline', '')
        yd_event.event_tagline_fr = request.POST.get('event_tagline_fr', '')
        yd_event.venue_name = request.POST.get('venue_name', '')
        yd_event.venue_name_fr = request.POST.get('venue_name_fr', '')
        yd_event.venue_address = request.POST.get('venue_address', '')
        yd_event.venue_address_fr = request.POST.get('venue_address_fr', '')
        yd_event.key_highlights = request.POST.get('key_highlights', '')
        yd_event.key_highlights_fr = request.POST.get('key_highlights_fr', '')
        yd_event.eligibility_criteria = request.POST.get('eligibility_criteria', '')
        yd_event.eligibility_criteria_fr = request.POST.get('eligibility_criteria_fr', '')
        yd_event.side_events_info = request.POST.get('side_events_info', '')
        yd_event.side_events_info_fr = request.POST.get('side_events_info_fr', '')
        yd_event.privacy_policy = request.POST.get('privacy_policy', '')
        yd_event.privacy_policy_fr = request.POST.get('privacy_policy_fr', '')
        if request.FILES.get('logo_light'):
            yd_event.logo_light = request.FILES['logo_light']
        if request.FILES.get('logo_light_fr'):
            yd_event.logo_light_fr = request.FILES['logo_light_fr']
        if request.FILES.get('logo_dark'):
            yd_event.logo_dark = request.FILES['logo_dark']
        if request.FILES.get('logo_dark_fr'):
            yd_event.logo_dark_fr = request.FILES['logo_dark_fr']
        if request.FILES.get('secondary_logo'):
            yd_event.secondary_logo = request.FILES['secondary_logo']
        if request.FILES.get('quick_access_icon'):
            yd_event.quick_access_icon = request.FILES['quick_access_icon']
        if request.FILES.get('banner_image'):
            yd_event.banner_image = request.FILES['banner_image']
        # Parse required documents from form
        req_docs = []
        idx = 0
        while True:
            key = request.POST.get(f'doc_{idx}_key', '').strip()
            if not key:
                break
            req_docs.append({
                'key': key,
                'label': request.POST.get(f'doc_{idx}_label', '').strip(),
                'label_fr': request.POST.get(f'doc_{idx}_label_fr', '').strip(),
                'camera_only': bool(request.POST.get(f'doc_{idx}_camera_only')),
            })
            idx += 1
        yd_event.required_documents = req_docs
        yd_event.save()
        _save_yd_form_fields(request, yd_event)
        _save_yd_roles(request, yd_event)
        messages.success(request, f'Continental Dialogue event {"updated" if event_pk else "created"} successfully!')
        return redirect('custom_admin:youth_dialogue_event_edit', event_pk=yd_event.pk)

    # Prepare form field data for template JS
    existing_fields = []
    if yd_event:
        existing_fields = list(yd_event.form_fields.values(
            'id', 'field_type', 'field_label', 'field_label_fr', 'field_name',
            'placeholder', 'placeholder_fr', 'is_required', 'is_active',
            'options', 'validation_regex', 'help_text', 'help_text_fr', 'order',
        ))
    field_type_choices = list(YouthDialogueFormField.FIELD_TYPE_CHOICES)

    # Prepare roles data for template JS
    existing_roles = []
    if yd_event:
        existing_roles = list(yd_event.roles.values('id', 'name', 'name_fr', 'color', 'order'))

    return render(request, 'custom_admin/youth_dialogue/event_form.html', {
        'yd_event': yd_event,
        'is_edit': event_pk is not None,
        'existing_fields_json': json.dumps(existing_fields).replace('<', '\\u003c'),
        'field_type_choices': json.dumps(field_type_choices).replace('<', '\\u003c'),
        'existing_roles_json': json.dumps(existing_roles).replace('<', '\\u003c'),
    })


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@require_POST
def youth_dialogue_toggle_active(request, event_pk):
    """Set an event as the active event (deactivates others)."""
    event = get_object_or_404(YouthDialogueEvent, pk=event_pk)
    event.is_active = True
    event.save()  # save() deactivates others
    messages.success(request, f'"{event.programme_title}" is now the active event.')
    return redirect('custom_admin:youth_dialogue_list')


def _save_yd_form_fields(request, yd_settings):
    """Parse and save inline form fields from the Continental Dialogue settings form."""
    existing_ids = set(yd_settings.form_fields.values_list('id', flat=True))
    kept_ids = set()
    idx = 0
    while True:
        prefix = f'field_{idx}_'
        field_type = request.POST.get(f'{prefix}type')
        if field_type is None:
            break
        field_id = request.POST.get(f'{prefix}id')
        field_label = request.POST.get(f'{prefix}label', '')
        field_label_fr = request.POST.get(f'{prefix}label_fr', '')
        field_name = request.POST.get(f'{prefix}name', '')
        placeholder = request.POST.get(f'{prefix}placeholder', '')
        placeholder_fr = request.POST.get(f'{prefix}placeholder_fr', '')
        is_required = request.POST.get(f'{prefix}required') == 'on'
        is_active = request.POST.get(f'{prefix}active') == 'on'
        help_text_val = request.POST.get(f'{prefix}help_text', '')
        help_text_fr = request.POST.get(f'{prefix}help_text_fr', '')
        options_str = request.POST.get(f'{prefix}options', '')
        validation_regex = request.POST.get(f'{prefix}validation_regex', '')
        order = idx

        options = []
        if options_str.strip():
            try:
                options = json.loads(options_str)
            except (ValueError, TypeError):
                options = [o.strip() for o in options_str.split(',') if o.strip()]

        data = {
            'settings': yd_settings,
            'field_type': field_type,
            'field_label': field_label,
            'field_label_fr': field_label_fr,
            'field_name': field_name,
            'placeholder': placeholder,
            'placeholder_fr': placeholder_fr,
            'is_required': is_required,
            'is_active': is_active,
            'options': options,
            'help_text': help_text_val,
            'help_text_fr': help_text_fr,
            'validation_regex': validation_regex,
            'order': order,
        }

        if field_id and field_id.isdigit():
            fid = int(field_id)
            YouthDialogueFormField.objects.filter(pk=fid, settings=yd_settings).update(**{
                k: v for k, v in data.items() if k != 'settings'
            })
            kept_ids.add(fid)
        else:
            obj = YouthDialogueFormField.objects.create(**data)
            kept_ids.add(obj.pk)
        idx += 1

    to_delete = existing_ids - kept_ids
    if to_delete:
        YouthDialogueFormField.objects.filter(pk__in=to_delete).delete()


def _save_yd_roles(request, yd_event):
    """Parse and save inline roles from the Continental Dialogue event form."""
    existing_ids = set(yd_event.roles.values_list('id', flat=True))
    kept_ids = set()
    idx = 0
    while True:
        name = request.POST.get(f'role_{idx}_name')
        if name is None:
            break
        name = name.strip()
        if not name:
            idx += 1
            continue
        role_id = request.POST.get(f'role_{idx}_id', '').strip()
        name_fr = request.POST.get(f'role_{idx}_name_fr', '').strip()
        color = request.POST.get(f'role_{idx}_color', '#4CAF50').strip()
        order = idx

        data = {
            'name': name,
            'name_fr': name_fr,
            'color': color,
            'order': order,
            'is_active': True,
        }

        if role_id and role_id.isdigit():
            rid = int(role_id)
            YouthDialogueRole.objects.filter(pk=rid, event=yd_event).update(**data)
            kept_ids.add(rid)
        else:
            obj = YouthDialogueRole.objects.create(event=yd_event, **data)
            kept_ids.add(obj.pk)
        idx += 1

    to_delete = existing_ids - kept_ids
    if to_delete:
        YouthDialogueRole.objects.filter(pk__in=to_delete).delete()


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def youth_dialogue_media_list(request, event_pk):
    """List all Continental Dialogue media items for an event."""
    yd_event = get_object_or_404(YouthDialogueEvent, pk=event_pk)
    media_items = YouthDialogueMedia.objects.filter(settings=yd_event).order_by('display_order', '-created_at')
    return render(request, 'custom_admin/youth_dialogue/media_list.html', {
        'media_items': media_items,
        'yd_event': yd_event,
    })


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def youth_dialogue_media_form(request, event_pk, pk=None):
    """Create or edit a Continental Dialogue media item."""
    yd_event = get_object_or_404(YouthDialogueEvent, pk=event_pk)
    media = None
    if pk:
        media = get_object_or_404(YouthDialogueMedia, pk=pk, settings=yd_event)

    if request.method == 'POST':
        if not media:
            media = YouthDialogueMedia(settings=yd_event)

        media.media_type = request.POST.get('media_type', 'photo')
        media.title = request.POST.get('title', '')
        media.title_fr = request.POST.get('title_fr', '')
        media.caption = request.POST.get('caption', '')
        media.caption_fr = request.POST.get('caption_fr', '')
        media.edition_tag = request.POST.get('edition_tag', '')
        media.external_url = request.POST.get('external_url', '')
        media.is_promotional = request.POST.get('is_promotional') == 'on'
        media.is_published = request.POST.get('is_published') == 'on'
        media.display_order = int(request.POST.get('display_order', 0))

        if request.FILES.get('file'):
            media.file = request.FILES['file']
        if request.FILES.get('thumbnail'):
            media.thumbnail = request.FILES['thumbnail']

        media.save()
        messages.success(request, f'Media item {"updated" if pk else "created"} successfully.')
        return redirect('custom_admin:youth_dialogue_media_list', event_pk=event_pk)

    return render(request, 'custom_admin/youth_dialogue/media_form.html', {
        'media': media,
        'is_edit': pk is not None,
        'yd_event': yd_event,
    })


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@require_POST
def youth_dialogue_media_delete(request, event_pk, pk):
    """Delete a Continental Dialogue media item."""
    yd_event = get_object_or_404(YouthDialogueEvent, pk=event_pk)
    media = get_object_or_404(YouthDialogueMedia, pk=pk, settings=yd_event)
    media.delete()
    messages.success(request, 'Media item deleted.')
    return redirect('custom_admin:youth_dialogue_media_list', event_pk=event_pk)


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def youth_dialogue_applications_list(request, event_pk):
    """Applications for a specific Continental Dialogue event."""
    yd_event = get_object_or_404(YouthDialogueEvent, pk=event_pk)
    qs = YouthDialogueApplication.objects.filter(event=yd_event).select_related('user').order_by('-created_at')

    status_filter = request.GET.get('status')
    if status_filter == 'pending_review':
        qs = qs.filter(status__in=['submitted', 'under_review'])
    elif status_filter == 'accepted':
        qs = qs.filter(status__in=['accepted', 'documents_pending', 'documents_submitted', 'documents_under_review'])
    elif status_filter == 'documents':
        qs = qs.filter(status__in=['documents_pending', 'documents_submitted', 'documents_under_review'])
    elif status_filter == 'credentials':
        qs = qs.filter(status='credential_issued')
    elif status_filter == 'rejected':
        qs = qs.filter(status__in=['rejected', 'documents_rejected'])
    elif status_filter:
        qs = qs.filter(status=status_filter)

    search_q = request.GET.get('q', '').strip()
    if search_q:
        qs = qs.filter(
            Q(first_name__icontains=search_q) |
            Q(last_name__icontains=search_q) |
            Q(email__icontains=search_q) |
            Q(participant_code__icontains=search_q)
        )

    event_apps = YouthDialogueApplication.objects.filter(event=yd_event)
    total_count = event_apps.count()
    pending_review_count = event_apps.filter(status__in=['submitted', 'under_review']).count()
    accepted_count = event_apps.filter(
        status__in=['accepted', 'documents_pending', 'documents_submitted', 'documents_under_review']
    ).count()
    credential_count = event_apps.filter(status='credential_issued').count()
    rejected_count = event_apps.filter(status__in=['rejected', 'documents_rejected']).count()

    paginator = Paginator(qs, 20)
    page = request.GET.get('page')
    applications = paginator.get_page(page)

    return render(request, 'custom_admin/youth_dialogue/list.html', {
        'applications': applications,
        'yd_event': yd_event,
        'total_count': total_count,
        'pending_review_count': pending_review_count,
        'accepted_count': accepted_count,
        'credential_count': credential_count,
        'rejected_count': rejected_count,
        'current_filter': status_filter or '',
        'search_query': search_q,
    })


def _auto_finalize_docs(request, application):
    """After individually reviewing docs, check if all are done and auto-update status.

    Only considers the LATEST document per type (highest id = most recent submission).
    Old rejected docs are ignored if a newer version has been submitted.

    - All approved, none pending → issue credential
    - Has rejected, none pending → set documents_rejected + notify
    - Still has pending → do nothing (wait for more reviews)
    """
    from django.db.models import Max
    from core.models import YouthDialogueDocument

    # Deduplicate: only look at the most recent document per type
    latest_doc_ids = list(
        application.documents
        .values('document_type')
        .annotate(latest_id=Max('id'))
        .values_list('latest_id', flat=True)
    )
    latest_docs = application.documents.filter(id__in=latest_doc_ids)

    pending_count = latest_docs.filter(status='pending').count()
    if pending_count > 0:
        return  # Still have docs to review

    has_rejected = latest_docs.filter(status='rejected').exists()
    all_approved = not has_rejected

    if has_rejected:
        # Build rejection notes from rejected docs (latest versions only)
        rejected_docs = latest_docs.filter(status='rejected')
        rejection_details = []
        for doc in rejected_docs:
            reason = doc.rejection_reason or 'No reason specified'
            rejection_details.append(f'• {doc.get_document_type_display()}: {reason}')
        auto_notes = '\n'.join(rejection_details)

        application.status = 'documents_rejected'
        application.documents_rejection_notes = auto_notes
        application.documents_reviewed_by = request.user
        application.documents_reviewed_at = timezone.now()
        application.save()
        log_admin_action(
            request, 'reject', 'YouthDialogueApplication', object_id=application.pk,
            object_repr=f'{application.first_name} {application.last_name}',
            changes={'status': {'old': 'documents_under_review', 'new': 'documents_rejected'}},
        )
        from core.views import _notify_yd
        _notify_yd(application, 'documents_rejected')
        messages.info(request, 'All documents reviewed — applicant notified about rejected documents.')

    elif all_approved:
        # All latest docs approved — auto-issue credential if all required types present
        approved_types = set(
            latest_docs.filter(status='approved')
            .values_list('document_type', flat=True)
        )
        # Check against configured required docs
        event = application.event
        if event and event.required_documents:
            required_types = {d.get('key', '') for d in event.required_documents if d.get('key')}
        else:
            required_types = {'passport', 'national_id', 'photo', 'cv'}
        missing_types = required_types - approved_types

        if not missing_types:
            application.generate_participant_code()
            application.generate_qr_hash()
            application.status = 'credential_issued'
            application.credential_issued_at = timezone.now()
            application.documents_reviewed_by = request.user
            application.documents_reviewed_at = timezone.now()
            application.save()
            log_admin_action(
                request, 'issue_credential', 'YouthDialogueApplication', object_id=application.pk,
                object_repr=f'{application.first_name} {application.last_name}',
                changes={'status': {'old': 'documents_under_review', 'new': 'credential_issued'}},
            )
            from core.views import _notify_yd
            _notify_yd(application, 'credential_issued')
            messages.success(request, f'All documents approved — credential issued for {application.first_name} {application.last_name}!')
        else:
            # All reviewed docs approved but some required types missing
            application.status = 'documents_under_review'
            application.documents_reviewed_by = request.user
            application.documents_reviewed_at = timezone.now()
            application.save()
            labels = dict(YouthDialogueDocument.DOCUMENT_TYPE_CHOICES)
            missing_names = [labels.get(m, m) for m in missing_types]
            messages.warning(request, f'All documents approved but missing required types: {", ".join(missing_names)}')


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def youth_dialogue_review(request, pk):
    application = get_object_or_404(
        YouthDialogueApplication.objects.select_related('user', 'reviewed_by', 'documents_reviewed_by', 'event'),
        pk=pk,
    )
    documents = application.documents.select_related('reviewed_by').order_by('uploaded_at')
    activity_logs = application.activity_logs.order_by('-timestamp')[:20]

    if request.method == 'POST':
        action = request.POST.get('action')
        old_status = application.status

        if action == 'accept' and application.status in ('submitted', 'under_review'):
            application.status = 'accepted'
            application.reviewed_by = request.user
            application.reviewed_at = timezone.now()
            application.save()
            log_admin_action(
                request, 'approve', 'YouthDialogueApplication', object_id=pk,
                object_repr=f'{application.first_name} {application.last_name}',
                changes={'status': {'old': old_status, 'new': 'accepted'}},
            )
            from core.views import _notify_yd
            _notify_yd(application, 'accepted')
            messages.success(request, f'Application from {application.first_name} {application.last_name} accepted.')

        elif action == 'reject' and application.status in ('submitted', 'under_review'):
            reason = request.POST.get('rejection_reason', '')
            application.status = 'rejected'
            application.rejection_reason = reason
            application.reviewed_by = request.user
            application.reviewed_at = timezone.now()
            application.save()
            log_admin_action(
                request, 'reject', 'YouthDialogueApplication', object_id=pk,
                object_repr=f'{application.first_name} {application.last_name}',
                changes={'status': {'old': old_status, 'new': 'rejected'}, 'reason': reason},
            )
            from core.views import _notify_yd
            _notify_yd(application, 'rejected')
            messages.success(request, f'Application from {application.first_name} {application.last_name} rejected.')

        elif action == 'approve_document':
            doc_id = request.POST.get('document_id')
            try:
                doc = YouthDialogueDocument.objects.get(pk=doc_id, application=application)
                if doc.status == 'pending':
                    doc.status = 'approved'
                    doc.reviewed_by = request.user
                    doc.reviewed_at = timezone.now()
                    doc.save()
                    # Auto-copy photo doc to id_photo field
                    if doc.document_type == 'photo' and doc.file:
                        application.id_photo = doc.file
                        application.save(update_fields=['id_photo'])
                    messages.success(request, f'Document "{doc.get_document_type_display()}" approved.')
                    # Auto-check: if all docs are now reviewed, update application status
                    _auto_finalize_docs(request, application)
            except YouthDialogueDocument.DoesNotExist:
                messages.error(request, 'Document not found.')

        elif action == 'reject_document':
            doc_id = request.POST.get('document_id')
            doc_reason = request.POST.get('doc_rejection_reason', '')
            try:
                doc = YouthDialogueDocument.objects.get(pk=doc_id, application=application)
                if doc.status == 'pending':
                    doc.status = 'rejected'
                    doc.rejection_reason = doc_reason
                    doc.reviewed_by = request.user
                    doc.reviewed_at = timezone.now()
                    doc.save()
                    messages.success(request, f'Document "{doc.get_document_type_display()}" rejected.')
                    # Auto-check: if all docs are now reviewed, update application status
                    _auto_finalize_docs(request, application)
            except YouthDialogueDocument.DoesNotExist:
                messages.error(request, 'Document not found.')

        elif action == 'approve_all_documents':
            # Copy photo to id_photo before bulk update
            photo_doc = application.documents.filter(status='pending', document_type='photo').first()
            if photo_doc and photo_doc.file:
                application.id_photo = photo_doc.file
                application.save(update_fields=['id_photo'])

            pending_docs = application.documents.filter(status='pending')
            count = pending_docs.update(
                status='approved',
                reviewed_by=request.user,
                reviewed_at=timezone.now(),
            )
            messages.success(request, f'{count} document(s) approved.')
            # Auto-finalize: check if credential can be issued
            _auto_finalize_docs(request, application)

        elif action == 'reject_all_documents':
            # Reject ALL documents (pending + approved) at once
            doc_reason = request.POST.get('documents_rejection_notes', '').strip() or 'Documents rejected by reviewer'
            all_docs = application.documents.all()
            rejection_details = []
            for doc in all_docs:
                if doc.status != 'rejected':
                    doc.status = 'rejected'
                    doc.rejection_reason = doc_reason
                    doc.reviewed_by = request.user
                    doc.reviewed_at = timezone.now()
                    doc.save()
                rejection_details.append(f'• {doc.get_document_type_display()}: {doc.rejection_reason or doc_reason}')

            application.status = 'documents_rejected'
            application.documents_rejection_notes = '\n'.join(rejection_details)
            application.documents_reviewed_by = request.user
            application.documents_reviewed_at = timezone.now()
            application.save()
            log_admin_action(
                request, 'reject', 'YouthDialogueApplication', object_id=pk,
                object_repr=f'{application.first_name} {application.last_name}',
                changes={'status': {'old': old_status, 'new': 'documents_rejected'}},
            )
            from core.views import _notify_yd
            _notify_yd(application, 'documents_rejected')
            messages.success(request, f'All documents rejected. Applicant notified.')

        elif action == 'reject_documents':
            # Finalize with existing rejections — also reject any remaining pending docs
            # First reject any still-pending docs with a generic reason
            pending_docs = application.documents.filter(status='pending')
            if pending_docs.exists():
                pending_docs.update(
                    status='rejected',
                    rejection_reason='Not approved during review',
                    reviewed_by=request.user,
                    reviewed_at=timezone.now(),
                )

            rejected_docs = application.documents.filter(status='rejected')
            if not rejected_docs.exists():
                messages.error(request, 'No rejected documents found.')
                return redirect('custom_admin:youth_dialogue_review', pk=pk)

            # Auto-build rejection message listing each rejected doc + its reason
            rejection_details = []
            for doc in rejected_docs:
                reason = doc.rejection_reason or 'No reason specified'
                rejection_details.append(f'• {doc.get_document_type_display()}: {reason}')
            auto_notes = '\n'.join(rejection_details)

            general_notes = request.POST.get('documents_rejection_notes', '').strip()
            full_notes = auto_notes
            if general_notes:
                full_notes += f'\n\nAdditional notes: {general_notes}'

            application.status = 'documents_rejected'
            application.documents_rejection_notes = full_notes
            application.documents_reviewed_by = request.user
            application.documents_reviewed_at = timezone.now()
            application.save()
            log_admin_action(
                request, 'reject', 'YouthDialogueApplication', object_id=pk,
                object_repr=f'{application.first_name} {application.last_name}',
                changes={'status': {'old': old_status, 'new': 'documents_rejected'}},
            )
            from core.views import _notify_yd
            _notify_yd(application, 'documents_rejected')
            messages.success(request, 'Documents rejected. Applicant notified.')

        elif action == 'save_admin_notes':
            application.admin_notes = request.POST.get('admin_notes', '')
            application.save(update_fields=['admin_notes'])
            messages.success(request, 'Admin notes saved.')
            return redirect('custom_admin:youth_dialogue_review', pk=pk)

        elif action == 'issue_credential':
            all_docs_approved = not application.documents.filter(status='pending').exists()
            has_rejected = application.documents.filter(status='rejected').exists()
            # Verify all 4 required document types exist and are approved
            approved_types = set(
                application.documents.filter(status='approved')
                .values_list('document_type', flat=True)
            )
            required_types = {'passport', 'national_id', 'photo', 'cv'}
            missing_types = required_types - approved_types
            if missing_types and application.status in ('accepted', 'documents_submitted', 'documents_under_review'):
                labels = dict(YouthDialogueDocument.DOCUMENT_TYPE_CHOICES)
                missing_names = [labels.get(m, m) for m in missing_types]
                messages.error(request, f'Cannot issue credential. Missing approved documents: {", ".join(missing_names)}')
                return redirect('custom_admin:youth_dialogue_review', pk=pk)
            if application.status in ('accepted', 'documents_submitted', 'documents_under_review') and all_docs_approved and not has_rejected and not missing_types:
                application.generate_participant_code()
                application.generate_qr_hash()
                application.status = 'credential_issued'
                application.credential_issued_at = timezone.now()
                application.save()
                log_admin_action(
                    request, 'approve', 'YouthDialogueApplication', object_id=pk,
                    object_repr=f'{application.first_name} {application.last_name}',
                    changes={'status': {'old': old_status, 'new': 'credential_issued'}, 'participant_code': application.participant_code},
                )
                # Copy approved photo doc to id_photo field
                try:
                    photo_doc = application.documents.filter(document_type='photo', status='approved').last()
                    if photo_doc and photo_doc.file:
                        application.id_photo = photo_doc.file
                        application.save(update_fields=['id_photo'])
                except Exception:
                    pass
                from core.views import _notify_yd
                _notify_yd(application, 'credential_issued')
                messages.success(request, f'Credential issued: {application.participant_code}')
            else:
                messages.error(request, 'Cannot issue credential. Ensure all documents are approved and none are rejected.')

        elif action == 'revoke_credential':
            if application.status == 'credential_issued' and not application.is_revoked:
                reason = request.POST.get('revoke_reason', '').strip()
                application.is_revoked = True
                application.revoked_at = timezone.now()
                application.revoked_reason = reason
                application.save(update_fields=['is_revoked', 'revoked_at', 'revoked_reason'])
                log_admin_action(
                    request, 'revoke', 'YouthDialogueApplication', object_id=pk,
                    object_repr=f'{application.first_name} {application.last_name}',
                    changes={'is_revoked': True, 'reason': reason},
                )
                from core.views import _notify_yd
                _notify_yd(application, 'credential_revoked')
                messages.success(request, f'Credential {application.participant_code} has been revoked.')
            else:
                messages.error(request, 'Cannot revoke: credential not issued or already revoked.')

        return redirect('custom_admin:youth_dialogue_review', pk=pk)

    return render(request, 'custom_admin/youth_dialogue/review.html', {
        'application': application,
        'documents': documents,
        'activity_logs': activity_logs,
    })


def _yd_email_html(application, heading, badge_color, body_html):
    """Build branded HTML email for Continental Dialogue notifications."""
    return f'''<!DOCTYPE html>
<html><head><meta charset="utf-8"></head>
<body style="margin:0;padding:0;background:#f4f6f9;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;">
<div style="max-width:600px;margin:0 auto;padding:40px 20px;">
  <div style="background:white;border-radius:16px;overflow:hidden;box-shadow:0 4px 24px rgba(0,0,0,0.08);">
    <div style="background:linear-gradient(135deg,#101c2e 0%,#1a2d47 100%);padding:40px 32px;text-align:center;">
      <div style="width:60px;height:60px;background:white;border-radius:12px;margin:0 auto 16px;display:flex;align-items:center;justify-content:center;">
        <span style="font-size:28px;font-weight:900;color:#101c2e;">B</span>
      </div>
      <h1 style="color:white;font-size:22px;margin:0 0 8px;">{heading}</h1>
      <p style="color:#a0aec0;font-size:14px;margin:0;">Continental Dialogue Programme</p>
    </div>
    <div style="padding:32px;">
      <div style="display:inline-block;background:{badge_color};color:white;padding:4px 16px;border-radius:20px;font-size:12px;font-weight:700;margin:0 0 20px;">{application.get_status_display().upper()}</div>
      <p style="color:#2d3748;font-size:16px;margin:0 0 20px;">Dear <strong>{application.first_name}</strong>,</p>
      {body_html}
    </div>
    <div style="background:#f7fafc;padding:20px 32px;text-align:center;">
      <p style="color:#a0aec0;font-size:12px;margin:0;">Be 4 Africa 2026</p>
    </div>
  </div>
</div>
</body></html>'''


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@require_POST
def youth_dialogue_export_csv(request, event_pk):
    yd_event = get_object_or_404(YouthDialogueEvent, pk=event_pk)
    qs = YouthDialogueApplication.objects.filter(event=yd_event).select_related('user').order_by('-created_at')

    safe_title = yd_event.slug or 'youth_dialogue'
    response = HttpResponse(content_type='text/csv')
    response['Content-Disposition'] = f'attachment; filename="{safe_title}_applications.csv"'

    writer = csv.writer(response)
    writer.writerow([
        'Name', 'Email', 'Nationality', 'Organization', 'Position',
        'Status', 'Participant Code', 'Created At', 'Documents Status',
    ])

    for app in qs:
        total_docs = app.documents.count()
        approved_docs = app.documents.filter(status='approved').count()
        docs_status = f'{approved_docs}/{total_docs} approved' if total_docs else 'No documents'
        writer.writerow(_sanitize_csv_row([
            f'{app.first_name} {app.last_name}',
            app.email,
            app.get_nationality_display() if app.nationality else '',
            app.organization,
            app.position,
            app.get_status_display(),
            app.participant_code or '',
            app.created_at.strftime('%Y-%m-%d %H:%M:%S') if app.created_at else '',
            docs_status,
        ]))

    log_admin_action(request, 'export', 'YouthDialogueApplication', object_repr=f'CSV export of {qs.count()} applications')

    return response


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def youth_dialogue_id_card_pdf(request, pk):
    """Generate a printable PDF ID card for a Continental Dialogue participant."""
    app = get_object_or_404(YouthDialogueApplication, pk=pk)
    if app.status != 'credential_issued' or not app.participant_code:
        return HttpResponse('Credential not issued yet.', status=400)

    try:
        from reportlab.lib.pagesizes import inch
        from reportlab.lib import colors as rl_colors
        from reportlab.pdfgen import canvas as rl_canvas
        from reportlab.lib.utils import ImageReader
    except ImportError:
        return HttpResponse('reportlab is not installed.', status=500)

    buf = io.BytesIO()
    card_w = 3.375 * inch
    card_h = 2.125 * inch
    c = rl_canvas.Canvas(buf, pagesize=(card_w, card_h))

    # Green header
    header_h = 0.65 * inch
    c.setFillColor(rl_colors.HexColor('#409843'))
    c.rect(0, card_h - header_h, card_w, header_h, fill=1, stroke=0)
    c.setFillColor(rl_colors.white)
    c.setFont('Helvetica-Bold', 8)
    c.drawCentredString(card_w / 2, card_h - 0.25 * inch, 'YOUTH DIALOGUE PARTICIPANT')
    c.setFont('Helvetica', 6)
    c.drawCentredString(card_w / 2, card_h - 0.40 * inch, 'Be 4 Africa 2026')

    # Photo
    photo_x = 0.15 * inch
    photo_y = card_h - header_h - 0.85 * inch
    photo_size = 0.7 * inch
    if app.id_photo:
        try:
            img = ImageReader(app.id_photo.path)
            c.drawImage(img, photo_x, photo_y, photo_size, photo_size, preserveAspectRatio=True, mask='auto')
        except Exception:
            c.setFillColor(rl_colors.HexColor('#e0e0e0'))
            c.rect(photo_x, photo_y, photo_size, photo_size, fill=1, stroke=0)
    else:
        c.setFillColor(rl_colors.HexColor('#e0e0e0'))
        c.rect(photo_x, photo_y, photo_size, photo_size, fill=1, stroke=0)

    # Name & details
    text_x = photo_x + photo_size + 0.15 * inch
    text_y = card_h - header_h - 0.2 * inch
    c.setFillColor(rl_colors.black)
    c.setFont('Helvetica-Bold', 9)
    c.drawString(text_x, text_y, f'{app.first_name} {app.last_name}')
    c.setFont('Helvetica', 7)
    text_y -= 0.15 * inch
    if app.organization:
        c.drawString(text_x, text_y, app.organization)
        text_y -= 0.13 * inch
    if app.nationality:
        c.drawString(text_x, text_y, f'Nationality: {app.get_nationality_display()}')
        text_y -= 0.13 * inch

    # Participant code
    c.setFont('Courier-Bold', 10)
    c.setFillColor(rl_colors.HexColor('#409843'))
    c.drawString(text_x, text_y - 0.05 * inch, app.participant_code)

    # QR data footer
    c.setFillColor(rl_colors.HexColor('#888888'))
    c.setFont('Helvetica', 5)
    c.drawCentredString(card_w / 2, 0.1 * inch, f'{app.participant_code}:{app.qr_hash}')
    c.setStrokeColor(rl_colors.HexColor('#409843'))
    c.setLineWidth(1)
    c.line(0, 0.25 * inch, card_w, 0.25 * inch)

    c.showPage()
    c.save()
    buf.seek(0)

    response = HttpResponse(buf, content_type='application/pdf')
    response['Content-Disposition'] = f'attachment; filename="YD-IDCard-{app.participant_code}.pdf"'
    return response


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def youth_dialogue_verify_qr(request):
    """QR code verification page for check-in staff."""
    result = None
    query = request.GET.get('q', '').strip()

    if query:
        # Parse QR data format: "YD-2026-0001:abc123hash"
        parts = query.split(':', 1)
        code = parts[0].strip()
        qr_hash = parts[1].strip() if len(parts) > 1 else ''

        if code and qr_hash:
            try:
                app = YouthDialogueApplication.objects.get(
                    participant_code=code, qr_hash=qr_hash,
                )
                result = {
                    'found': True,
                    'application': app,
                    'status': 'REVOKED' if app.is_revoked else 'VALID',
                }
            except YouthDialogueApplication.DoesNotExist:
                result = {'found': False}
        elif code:
            # Try lookup by participant code only
            try:
                app = YouthDialogueApplication.objects.get(participant_code=code)
                result = {
                    'found': True,
                    'application': app,
                    'status': 'REVOKED' if app.is_revoked else 'VALID',
                    'partial_match': True,
                }
            except YouthDialogueApplication.DoesNotExist:
                result = {'found': False}
        else:
            result = {'found': False}

    return render(request, 'custom_admin/youth_dialogue/verify.html', {
        'result': result,
        'query': query,
    })


# ═══════════════════════════════════════════════════════════════
#  COMMENT BAN MANAGEMENT
# ═══════════════════════════════════════════════════════════════

@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@require_POST
def user_toggle_comment_ban(request, pk):
    """Toggle comment ban on a user. Also creates/lifts associated device ban."""
    target_user = get_object_or_404(User, pk=pk)
    profile = target_user.profile

    if profile.is_comment_banned:
        # Unban: reset strikes and lift ban
        old_strikes = profile.profanity_strikes
        profile.is_comment_banned = False
        profile.comment_banned_at = None
        profile.profanity_strikes = 0
        profile.save(update_fields=['is_comment_banned', 'comment_banned_at', 'profanity_strikes'])
        # Lift device ban if exists
        if profile.device_id:
            DeviceBan.objects.filter(device_id=profile.device_id, is_active=True).update(
                is_active=False,
                unbanned_at=timezone.now(),
                unbanned_by=request.user,
            )
        log_admin_action(
            request, 'status_change', 'User', object_id=pk,
            object_repr=target_user.username,
            changes={
                'is_comment_banned': {'old': 'True', 'new': 'False'},
                'profanity_strikes': {'old': str(old_strikes), 'new': '0'},
            }
        )
        messages.success(request, f'Comment ban lifted for "{target_user.username}". Strikes reset to 0.')
    else:
        # Ban: set ban and create device ban
        profile.is_comment_banned = True
        profile.comment_banned_at = timezone.now()
        profile.save(update_fields=['is_comment_banned', 'comment_banned_at'])
        if profile.device_id:
            DeviceBan.objects.get_or_create(
                device_id=profile.device_id,
                defaults={
                    'user': target_user,
                    'reason': f'Manual ban by admin {request.user.username}',
                },
            )
        log_admin_action(
            request, 'status_change', 'User', object_id=pk,
            object_repr=target_user.username,
            changes={'is_comment_banned': {'old': 'False', 'new': 'True'}}
        )
        messages.success(request, f'User "{target_user.username}" has been banned from commenting.')

    return redirect('custom_admin:user_edit', pk=pk)


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def device_bans_list(request):
    """List all device bans with unban buttons."""
    bans = DeviceBan.objects.select_related('user', 'unbanned_by').all()
    q = request.GET.get('q', '').strip()
    if q:
        bans = bans.filter(
            Q(device_id__icontains=q) | Q(user__username__icontains=q) | Q(reason__icontains=q)
        )
    status_filter = request.GET.get('status', '')
    if status_filter == 'active':
        bans = bans.filter(is_active=True)
    elif status_filter == 'lifted':
        bans = bans.filter(is_active=False)

    paginator = Paginator(bans, 50)
    page = paginator.get_page(request.GET.get('page', 1))

    return render(request, 'custom_admin/device_bans/list.html', {
        'page': page,
        'q': q,
        'status_filter': status_filter,
    })


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@require_POST
def device_ban_unban(request, pk):
    """Lift a device ban."""
    ban = get_object_or_404(DeviceBan, pk=pk)
    if not ban.is_active:
        messages.info(request, 'This device ban has already been lifted.')
        return redirect('custom_admin:device_bans_list')

    ban.is_active = False
    ban.unbanned_at = timezone.now()
    ban.unbanned_by = request.user
    ban.save(update_fields=['is_active', 'unbanned_at', 'unbanned_by'])

    # Also unban any user profiles linked to this device
    UserProfile.objects.filter(device_id=ban.device_id, is_comment_banned=True).update(
        is_comment_banned=False,
        comment_banned_at=None,
        profanity_strikes=0,
    )

    log_admin_action(
        request, 'status_change', 'DeviceBan', object_id=pk,
        object_repr=f'Device {ban.device_id[:12]}...',
        changes={'is_active': {'old': 'True', 'new': 'False'}}
    )
    messages.success(request, f'Device ban lifted for {ban.device_id[:12]}...')
    return redirect('custom_admin:device_bans_list')

