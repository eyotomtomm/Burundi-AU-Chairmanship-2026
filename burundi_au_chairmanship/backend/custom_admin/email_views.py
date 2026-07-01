"""Email-related admin views: templates, campaigns (marketing), logs, inbox.

Extracted from ``custom_admin/views.py`` to keep that file manageable.
All function names remain unchanged so ``urls.py`` works without edits —
they are re-exported by ``views.py`` via ``from .email_views import *``.
"""
import logging

from django.conf import settings
from django.contrib import messages
from django.contrib.auth.decorators import login_required, user_passes_test
from django.core.paginator import Paginator
from django.db.models import Q
from django.http import JsonResponse
from django.shortcuts import get_object_or_404, redirect, render
from django.utils import timezone
from django.views.decorators.http import require_POST

from core.models import (
    EmailCampaign,
    EmailLog,
    EmailTemplate,
    User,
)
from core.utils import log_admin_action

from ._helpers import is_staff

logger = logging.getLogger(__name__)


# ═══════════════════════════════════════════════════════════════
#  CAMPAIGN SMTP CONNECTION (newsletter@burundichairship.africa)
# ═══════════════════════════════════════════════════════════════

def _get_campaign_smtp_connection():
    """Return a dedicated SMTP connection for campaign emails.

    Uses CAMPAIGN_EMAIL_* settings so campaigns go through
    newsletter@burundichairship.africa while OTP / system emails
    continue using the default info@burundi4africa.com account.
    """
    from django.core.mail import get_connection
    return get_connection(
        host=settings.CAMPAIGN_EMAIL_HOST,
        port=settings.CAMPAIGN_EMAIL_PORT,
        username=settings.CAMPAIGN_EMAIL_HOST_USER,
        password=settings.CAMPAIGN_EMAIL_HOST_PASSWORD,
        use_tls=settings.CAMPAIGN_EMAIL_USE_TLS,
        use_ssl=settings.CAMPAIGN_EMAIL_USE_SSL,
    )


# ═══════════════════════════════════════════════════════════════
#  BRANDED EMAIL WRAPPER
# ═══════════════════════════════════════════════════════════════

def _wrap_campaign_html(body_html, user_name=''):
    """Wrap raw campaign body HTML in a branded, responsive email template.

    Uses only inline CSS for maximum email-client compatibility (Gmail,
    Outlook, Apple Mail, Yahoo, etc.).  No JavaScript — email clients
    strip it.
    """
    greeting = ''
    if user_name:
        greeting = (
            f'<tr><td style="padding:0 40px 0 40px;font-size:16px;'
            f'line-height:1.6;color:#334155;">'
            f'Hello <strong>{user_name}</strong>,</td></tr>'
            f'<tr><td style="height:16px;"></td></tr>'
        )

    return f'''<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Be 4 Africa</title>
</head>
<body style="margin:0;padding:0;background-color:#f1f5f9;font-family:Arial,Helvetica,sans-serif;-webkit-font-smoothing:antialiased;">

<!-- Outer wrapper -->
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#f1f5f9;padding:32px 16px;">
<tr><td align="center">

<!-- Inner card -->
<table role="presentation" width="600" cellpadding="0" cellspacing="0" style="max-width:600px;width:100%;background-color:#ffffff;border-radius:16px;overflow:hidden;box-shadow:0 4px 24px rgba(0,0,0,0.08);">

  <!-- Header -->
  <tr>
    <td style="background:linear-gradient(135deg,#166534 0%,#15803d 50%,#1d8348 100%);padding:32px 40px;text-align:center;">
      <table role="presentation" width="100%" cellpadding="0" cellspacing="0">
        <tr>
          <td align="center">
            <div style="width:56px;height:56px;background-color:rgba(255,255,255,0.2);border-radius:50%;display:inline-block;line-height:56px;text-align:center;font-size:28px;margin-bottom:12px;">
              &#127757;
            </div>
          </td>
        </tr>
        <tr>
          <td align="center" style="font-size:24px;font-weight:bold;color:#ffffff;letter-spacing:0.5px;padding-top:8px;">
            Be 4 Africa
          </td>
        </tr>
        <tr>
          <td align="center" style="font-size:13px;color:rgba(255,255,255,0.8);padding-top:4px;letter-spacing:1px;text-transform:uppercase;">
            Burundi AU Chairmanship 2025-2026
          </td>
        </tr>
      </table>
    </td>
  </tr>

  <!-- Spacer -->
  <tr><td style="height:32px;"></td></tr>

  <!-- Greeting -->
  {greeting}

  <!-- Body content -->
  <tr>
    <td style="padding:0 40px;font-size:15px;line-height:1.7;color:#334155;">
      {body_html}
    </td>
  </tr>

  <!-- Spacer -->
  <tr><td style="height:32px;"></td></tr>

  <!-- Divider -->
  <tr>
    <td style="padding:0 40px;">
      <div style="border-top:1px solid #e2e8f0;"></div>
    </td>
  </tr>

  <!-- Footer -->
  <tr>
    <td style="padding:24px 40px 32px 40px;text-align:center;">
      <p style="margin:0 0 8px 0;font-size:13px;color:#64748b;">
        Sent by <strong style="color:#166534;">Be 4 Africa</strong> &mdash; Burundi AU Chairmanship
      </p>
      <p style="margin:0 0 8px 0;font-size:12px;color:#94a3b8;">
        newsletter@burundichairship.africa
      </p>
      <p style="margin:0;font-size:11px;color:#cbd5e1;">
        &copy; 2025-2026 Be 4 Africa. All rights reserved.
      </p>
    </td>
  </tr>

</table>
<!-- /Inner card -->

</td></tr>
</table>
<!-- /Outer wrapper -->

</body>
</html>'''


# ═══════════════════════════════════════════════════════════════
#  EMAIL TEMPLATES
# ═══════════════════════════════════════════════════════════════

@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def email_templates_list(request):
    templates = EmailTemplate.objects.all().order_by('key')
    return render(request, 'custom_admin/email_templates/list.html', {'templates': templates})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def email_template_edit(request, pk):
    import re as re_module
    template = get_object_or_404(EmailTemplate, pk=pk)
    if request.method == 'POST':
        # Check if this is a test email send request
        if request.POST.get('send_test'):
            test_email = request.POST.get('test_email', request.user.email)
            body_html = request.POST.get('body_html', template.body_html)
            subject = request.POST.get('subject', template.subject)
            # Replace template variables with sample data
            sample_data = {
                'user_name': request.user.get_full_name() or request.user.username,
                'user_email': request.user.email,
                'app_name': 'Be 4 Africa',
                'action_url': 'https://burundi4africa.com',
                'otp_code': '123456',
                'event_name': 'Sample Event',
                'event_date': 'January 15, 2026',
            }
            for key, val in sample_data.items():
                body_html = re_module.sub(r'\{\{\s*' + key + r'\s*\}\}', val, body_html)
                subject = re_module.sub(r'\{\{\s*' + key + r'\s*\}\}', val, subject)
            try:
                from django.core.mail import send_mail
                send_mail(
                    subject=f'[TEST] {subject}',
                    message='',
                    html_message=body_html,
                    from_email=None,
                    recipient_list=[test_email],
                    fail_silently=False,
                )
                return JsonResponse({'success': True})
            except Exception as e:
                return JsonResponse({'success': False, 'error': str(e)})

        template.subject = request.POST.get('subject')
        template.subject_fr = request.POST.get('subject_fr', '')
        template.body_html = request.POST.get('body_html')
        template.body_html_fr = request.POST.get('body_html_fr', '')
        template.is_active = request.POST.get('is_active') == 'on'
        template.save()
        messages.success(request, 'Email template updated successfully!')
        return redirect('custom_admin:email_templates_list')
    return render(request, 'custom_admin/email_templates/form.html', {'template': template})


# ═══════════════════════════════════════════════════════════════
#  EMAIL TEMPLATE PREVIEW & SEND TEST (AJAX endpoints)
# ═══════════════════════════════════════════════════════════════

@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@require_POST
def email_template_preview(request, pk):
    """POST returns rendered HTML with sample data for live preview."""
    import re as re_module

    template = get_object_or_404(EmailTemplate, pk=pk)
    body_html = request.POST.get('body_html', template.body_html)

    sample_context = {
        'username': 'John Doe',
        'user_name': 'John Doe',
        'user_email': 'john@example.com',
        'otp_code': '123456',
        'expiry_minutes': '10',
        'app_name': 'Be 4 Africa',
        'badge_type': 'Gold',
        'event_name': 'Sample Event',
        'event_date': 'April 15, 2026',
        'ticket_number': 'TK-001',
        'reset_link': 'https://burundi4africa.com/reset',
        'action_url': 'https://burundi4africa.com',
    }

    rendered = body_html
    for key, val in sample_context.items():
        rendered = re_module.sub(r'\{\{\s*' + key + r'\s*\}\}', val, rendered)

    return JsonResponse({
        'html': rendered,
        'subject': template.subject,
    })


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@require_POST
def email_template_send_test(request, pk):
    """POST sends a test email to specified address using template with sample data."""
    import re as re_module

    template = get_object_or_404(EmailTemplate, pk=pk)
    recipient_email = request.POST.get('recipient_email', request.user.email)

    if not recipient_email:
        return JsonResponse({'success': False, 'error': 'No recipient email provided'}, status=400)

    sample_context = {
        'username': request.user.get_full_name() or request.user.username,
        'user_name': request.user.get_full_name() or request.user.username,
        'user_email': request.user.email,
        'otp_code': '123456',
        'expiry_minutes': '10',
        'app_name': 'Be 4 Africa',
        'badge_type': 'Gold',
        'event_name': 'AU Summit 2026',
        'event_date': 'April 15, 2026',
        'ticket_number': 'TK-001',
        'reset_link': 'https://burundi4africa.com/reset',
        'action_url': 'https://burundi4africa.com',
    }

    body_html = template.body_html
    subject = template.subject
    for key, val in sample_context.items():
        body_html = re_module.sub(r'\{\{\s*' + key + r'\s*\}\}', val, body_html)
        subject = re_module.sub(r'\{\{\s*' + key + r'\s*\}\}', val, subject)

    try:
        from django.core.mail import send_mail
        send_mail(
            subject=f'[TEST] {subject}',
            message='',
            html_message=body_html,
            from_email=None,
            recipient_list=[recipient_email],
            fail_silently=False,
        )
        return JsonResponse({'success': True, 'message': f'Test email sent to {recipient_email}'})
    except Exception as e:
        return JsonResponse({'success': False, 'error': str(e)})


# ═══════════════════════════════════════════════════════════════
#  EMAIL CAMPAIGNS (Marketing Blasts)
# ═══════════════════════════════════════════════════════════════

def _campaign_audience_queryset(campaign):
    """Return a list of (email, full_name) tuples for the campaign audience."""
    if campaign.audience_type == 'custom':
        raw = (campaign.custom_recipients or '').replace('\r', '\n').replace(',', '\n')
        emails = [e.strip() for e in raw.split('\n') if e.strip() and '@' in e]
        return [(e, '') for e in emails]

    qs = User.objects.filter(is_active=True).exclude(email='')

    if campaign.audience_type == 'language':
        qs = qs.filter(profile__preferred_language=campaign.audience_language or 'en')
    elif campaign.audience_type == 'nationality':
        qs = qs.filter(profile__nationality=campaign.audience_nationality or '')
    elif campaign.audience_type == 'verified':
        qs = qs.filter(profile__is_verified=True)
    elif campaign.audience_type == 'newsletter':
        qs = qs.filter(profile__receives_newsletter=True)
    elif campaign.audience_type == 'staff':
        qs = qs.filter(is_staff=True)
    # 'all' → no further filter

    return [
        (u.email, u.get_full_name() or u.email.split('@')[0])
        for u in qs.select_related('profile').only('email', 'first_name', 'last_name')
    ]


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def email_campaigns_list(request):
    campaigns = EmailCampaign.objects.all().order_by('-created_at')
    paginator = Paginator(campaigns, 20)
    page = paginator.get_page(request.GET.get('page', 1))
    return render(request, 'custom_admin/email_campaigns/list.html', {
        'campaigns': page,
    })


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def email_campaign_create(request):
    if request.method == 'POST':
        campaign = EmailCampaign.objects.create(
            name=request.POST.get('name', '').strip() or 'Untitled Campaign',
            subject=request.POST.get('subject', '').strip(),
            subject_fr=request.POST.get('subject_fr', '').strip(),
            body_html=request.POST.get('body_html', ''),
            body_html_fr=request.POST.get('body_html_fr', ''),
            audience_type=request.POST.get('audience_type', 'all'),
            audience_language=request.POST.get('audience_language', ''),
            audience_nationality=request.POST.get('audience_nationality', '').upper(),
            custom_recipients=request.POST.get('custom_recipients', ''),
            status='draft',
            created_by=request.user,
        )
        campaign.recipient_count = len(_campaign_audience_queryset(campaign))
        campaign.save(update_fields=['recipient_count'])
        log_admin_action(request, 'create', 'EmailCampaign', object_id=campaign.pk, object_repr=campaign.name)

        # If "Save & Send" was clicked, redirect to send immediately
        if request.POST.get('_action') == 'send':
            return redirect('custom_admin:email_campaign_send_confirm', pk=campaign.pk)

        messages.success(request, f'Campaign "{campaign.name}" saved as draft.')
        return redirect('custom_admin:email_campaigns_list')
    return render(request, 'custom_admin/email_campaigns/form.html', {'action': 'Create'})


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def email_campaign_edit(request, pk):
    campaign = get_object_or_404(EmailCampaign, pk=pk)
    if request.method == 'POST':
        campaign.name = request.POST.get('name', campaign.name).strip()
        campaign.subject = request.POST.get('subject', '').strip()
        campaign.subject_fr = request.POST.get('subject_fr', '').strip()
        campaign.body_html = request.POST.get('body_html', '')
        campaign.body_html_fr = request.POST.get('body_html_fr', '')
        campaign.audience_type = request.POST.get('audience_type', 'all')
        campaign.audience_language = request.POST.get('audience_language', '')
        campaign.audience_nationality = request.POST.get('audience_nationality', '').upper()
        campaign.custom_recipients = request.POST.get('custom_recipients', '')
        campaign.recipient_count = len(_campaign_audience_queryset(campaign))
        campaign.save()
        log_admin_action(request, 'update', 'EmailCampaign', object_id=campaign.pk, object_repr=campaign.name)

        if request.POST.get('_action') == 'send':
            return redirect('custom_admin:email_campaign_send_confirm', pk=campaign.pk)

        messages.success(request, f'Campaign "{campaign.name}" updated.')
        return redirect('custom_admin:email_campaigns_list')
    return render(request, 'custom_admin/email_campaigns/form.html', {
        'campaign': campaign,
        'action': 'Edit',
    })


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def email_campaign_send_confirm(request, pk):
    """Show a confirmation page with preview before sending."""
    import re as _re
    campaign = get_object_or_404(EmailCampaign, pk=pk)
    recipients = _campaign_audience_queryset(campaign)

    # Build a sample preview with the first recipient or the logged-in admin
    sample_name = 'John Doe'
    sample_email = 'john@example.com'
    if recipients:
        sample_email, sample_name = recipients[0]
        sample_name = sample_name or sample_email.split('@')[0]

    ctx = {
        'user_name': sample_name,
        'user_email': sample_email,
        'app_name': 'Be 4 Africa',
    }
    preview_body = campaign.body_html
    for k, v in ctx.items():
        preview_body = _re.sub(r'\{\{\s*' + k + r'\s*\}\}', str(v), preview_body)
    preview_html = _wrap_campaign_html(preview_body, user_name=sample_name)

    return render(request, 'custom_admin/email_campaigns/send_confirm.html', {
        'campaign': campaign,
        'recipient_count': len(recipients),
        'preview_html': preview_html,
    })


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@require_POST
def email_campaign_send(request, pk):
    """Send the campaign to its resolved audience. Inline / synchronous —
    fine for audiences up to a few thousand. Each message is logged via
    LoggingEmailBackend (EmailLog rows). Wraps body in branded template."""
    campaign = get_object_or_404(EmailCampaign, pk=pk)

    if campaign.status == 'sending':
        messages.warning(request, 'Campaign is already sending.')
        return redirect('custom_admin:email_campaigns_list')

    recipients = _campaign_audience_queryset(campaign)
    if not recipients:
        messages.error(request, 'No recipients resolved for this audience. Check your audience settings.')
        return redirect('custom_admin:email_campaign_edit', pk=pk)

    campaign.status = 'sending'
    campaign.recipient_count = len(recipients)
    campaign.sent_count = 0
    campaign.failed_count = 0
    campaign.last_error = ''
    campaign.save(update_fields=['status', 'recipient_count', 'sent_count', 'failed_count', 'last_error'])

    from django.core.mail import EmailMultiAlternatives
    import re as _re

    def _render(tpl, ctx):
        out = tpl
        for k, v in ctx.items():
            out = _re.sub(r'\{\{\s*' + k + r'\s*\}\}', str(v), out)
        return out

    # Use dedicated newsletter SMTP connection
    campaign_from = settings.CAMPAIGN_FROM_EMAIL
    connection = _get_campaign_smtp_connection()

    sent_ok = 0
    sent_fail = 0
    last_error = ''

    try:
        connection.open()
        for email, name in recipients:
            user_name = name or email.split('@')[0]
            ctx = {
                'user_name': user_name,
                'user_email': email,
                'app_name': 'Be 4 Africa',
            }
            subject = _render(campaign.subject, ctx)
            raw_body = _render(campaign.body_html, ctx)
            # Wrap in branded template with personalised greeting
            full_html = _wrap_campaign_html(raw_body, user_name=user_name)
            try:
                msg = EmailMultiAlternatives(
                    subject=subject,
                    body=f'Hello {user_name},\n\n'
                         f'{raw_body[:500]}\n\n'
                         f'-- Be 4 Africa | Burundi AU Chairmanship',
                    from_email=campaign_from,
                    to=[email],
                    connection=connection,
                )
                msg.attach_alternative(full_html, 'text/html')
                msg.send(fail_silently=False)
                sent_ok += 1
                # Tag the most-recent EmailLog row with this campaign.
                try:
                    latest = EmailLog.objects.filter(
                        recipients=email
                    ).order_by('-created_at').first()
                    if latest and latest.campaign_id is None:
                        latest.campaign = campaign
                        latest.category = 'campaign'
                        latest.save(update_fields=['campaign', 'category'])
                except Exception:
                    logger.warning('Failed to tag EmailLog for %s', email, exc_info=True)
            except Exception as e:
                sent_fail += 1
                last_error = str(e)[:2000]
    finally:
        try:
            connection.close()
        except Exception:
            pass

    campaign.status = 'sent' if sent_fail == 0 else ('failed' if sent_ok == 0 else 'sent')
    campaign.sent_count = sent_ok
    campaign.failed_count = sent_fail
    campaign.last_error = last_error
    campaign.sent_at = timezone.now()
    campaign.save(update_fields=['status', 'sent_count', 'failed_count', 'last_error', 'sent_at'])

    log_admin_action(request, 'send', 'EmailCampaign', object_id=campaign.pk, object_repr=campaign.name)
    if sent_fail == 0:
        messages.success(request, f'Campaign "{campaign.name}" sent to {sent_ok} recipient(s).')
    else:
        messages.warning(request, f'Campaign "{campaign.name}" sent to {sent_ok}, failed {sent_fail}. Last error: {last_error[:200]}')
    return redirect('custom_admin:email_campaigns_list')


@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
@require_POST
def email_campaign_delete(request, pk):
    campaign = get_object_or_404(EmailCampaign, pk=pk)
    name = campaign.name
    campaign.delete()
    log_admin_action(request, 'delete', 'EmailCampaign', object_repr=name)
    messages.success(request, f'Campaign "{name}" deleted.')
    return redirect('custom_admin:email_campaigns_list')


# ═══════════════════════════════════════════════════════════════
#  EMAIL LOGS (Sent / Failed history)
# ═══════════════════════════════════════════════════════════════

@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def email_logs_list(request):
    status = request.GET.get('status', '').strip()
    category = request.GET.get('category', '').strip()
    search = request.GET.get('q', '').strip()

    logs = EmailLog.objects.all().order_by('-created_at')
    if status in ('sent', 'failed'):
        logs = logs.filter(status=status)
    if category:
        logs = logs.filter(category=category)
    if search:
        logs = logs.filter(
            Q(subject__icontains=search) |
            Q(recipients__icontains=search) |
            Q(error__icontains=search)
        )

    total = logs.count()
    sent_count = EmailLog.objects.filter(status='sent').count()
    failed_count = EmailLog.objects.filter(status='failed').count()

    paginator = Paginator(logs, 50)
    page = paginator.get_page(request.GET.get('page', 1))

    return render(request, 'custom_admin/email_logs/list.html', {
        'logs': page,
        'total': total,
        'sent_count': sent_count,
        'failed_count': failed_count,
        'status_filter': status,
        'category_filter': category,
        'search_query': search,
        'category_choices': EmailLog.CATEGORY_CHOICES,
    })


# ═══════════════════════════════════════════════════════════════
#  EMAIL INBOX (Read-only IMAP viewer)
# ═══════════════════════════════════════════════════════════════

@login_required(login_url='custom_admin:login')
@user_passes_test(is_staff, login_url='custom_admin:login')
def email_inbox(request):
    """Read-only IMAP viewer so admins can see incoming mail without opening Gmail."""
    import imaplib
    import email as email_lib
    from email.header import decode_header

    host = getattr(settings, 'IMAP_HOST', '')
    port = getattr(settings, 'IMAP_PORT', 993)
    use_ssl = getattr(settings, 'IMAP_USE_SSL', True)
    user = getattr(settings, 'IMAP_USER', '')
    password = getattr(settings, 'IMAP_PASSWORD', '')
    mailbox = getattr(settings, 'IMAP_MAILBOX', 'INBOX')

    messages_list = []
    error = None
    configured = bool(host and user and password)

    def _decode(value):
        if not value:
            return ''
        try:
            parts = decode_header(value)
            out = ''
            for text, enc in parts:
                if isinstance(text, bytes):
                    try:
                        out += text.decode(enc or 'utf-8', errors='replace')
                    except (LookupError, TypeError):
                        out += text.decode('utf-8', errors='replace')
                else:
                    out += text
            return out
        except Exception:
            return str(value)

    if configured:
        try:
            if use_ssl:
                imap = imaplib.IMAP4_SSL(host, port)
            else:
                imap = imaplib.IMAP4(host, port)
            imap.login(user, password)
            imap.select(mailbox, readonly=True)

            # Fetch the most recent 25 messages
            status, data = imap.search(None, 'ALL')
            if status != 'OK':
                error = 'IMAP search failed.'
            else:
                ids = data[0].split()
                latest = ids[-25:][::-1]  # newest first
                for msg_id in latest:
                    status, msg_data = imap.fetch(msg_id, '(RFC822.HEADER)')
                    if status != 'OK' or not msg_data or not msg_data[0]:
                        continue
                    raw = msg_data[0][1]
                    msg = email_lib.message_from_bytes(raw)
                    messages_list.append({
                        'id': msg_id.decode('ascii', errors='replace'),
                        'from': _decode(msg.get('From', '')),
                        'to': _decode(msg.get('To', '')),
                        'subject': _decode(msg.get('Subject', '(no subject)')),
                        'date': msg.get('Date', ''),
                    })

            try:
                imap.close()
            except Exception:
                pass
            imap.logout()
        except Exception as e:
            error = f'IMAP error: {e}'

    return render(request, 'custom_admin/email_inbox/list.html', {
        'configured': configured,
        'messages_list': messages_list,
        'error': error,
        'imap_host': host,
        'imap_user': user,
        'mailbox': mailbox,
    })
