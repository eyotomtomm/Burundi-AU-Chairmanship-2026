"""
Utility functions for the Burundi Chairmanship app.
"""

import logging
import re

logger = logging.getLogger(__name__)


# ── Privacy-safe user handle ─────────────────────────────────
# Django `User.username` is set to the user's email on registration, so we
# MUST never expose it raw to other users. This helper produces a stable,
# non-leaking handle derived from the local part (before the @) of the email,
# stripped of anything that isn't safe for an @mention.

_UNSAFE_HANDLE_CHARS = re.compile(r'[^A-Za-z0-9_]')


def sanitize_handle(raw_username):
    """Return a privacy-safe @mention handle for a given Django username.

    Rules:
      • If the username contains "@", strip everything from "@" onward
        (prevents email-domain leakage in public comment API responses).
      • Replace any non-word characters with an empty string so the handle
        matches ``@(\\w+)`` used in mention parsing.
      • Empty result falls back to ``"user{id}"`` is handled by the caller;
        this function just returns the sanitized string (possibly empty).
    """
    if not raw_username:
        return ''
    local = raw_username.split('@', 1)[0]
    return _UNSAFE_HANDLE_CHARS.sub('', local)


def user_handle(user):
    """Safe handle for a User object, with a stable fallback."""
    if not user:
        return ''
    h = sanitize_handle(getattr(user, 'username', ''))
    return h or f'user{user.pk}'


def resolve_mentioned_users(content, exclude_user=None):
    """Parse @mentions in ``content`` and return User objects whose sanitized
    handle exactly matches any mentioned handle (case-insensitive).

    This is the privacy-safe replacement for the old
    ``User.objects.filter(username__in=...)`` lookup which accidentally
    required users to type the user's email.
    """
    from django.contrib.auth.models import User  # local import to avoid cycles

    raw_handles = re.findall(r'@(\w+)', content or '')
    if not raw_handles:
        return []
    # Build a lowercase set for matching.
    wanted = {h.lower() for h in raw_handles}
    # Pull every candidate whose email local-part *could* contain one of the
    # handles. Using ``istartswith`` on username (email) is the cheapest query
    # that reliably includes every potential match.
    qs = User.objects.filter(is_active=True)
    if exclude_user is not None:
        qs = qs.exclude(pk=exclude_user.pk)
    candidates = []
    for handle in wanted:
        candidates.extend(qs.filter(username__istartswith=handle))
    # Deduplicate and verify the sanitized handle exactly matches.
    seen = set()
    matched = []
    for user in candidates:
        if user.pk in seen:
            continue
        seen.add(user.pk)
        if sanitize_handle(user.username).lower() in wanted:
            matched.append(user)
    return matched


# ── Admin Audit Trail ─────────────────────────────────────────

def log_admin_action(request, action_type, model_name, object_id=None,
                     object_repr='', changes=None):
    """
    Create an AdminActivityLog entry for an admin action.

    This is the primary entry point for recording admin audit trail events.
    Call this from any admin view after a successful create/update/delete/etc.

    Args:
        request: The Django HTTP request (provides user, IP, user-agent, path).
        action_type: One of AdminActivityLog.ACTION_TYPE_CHOICES keys
                     (e.g. 'create', 'update', 'delete', 'status_change', etc.).
        model_name: Human-readable model name (e.g. 'Article', 'Event', 'User').
        object_id: Primary key of the affected object (optional).
        object_repr: Short string representation of the object (e.g. article title).
        changes: Dict of field changes in the format
                 {field_name: {'old': old_value, 'new': new_value}} (optional).
    """
    try:
        from core.models import AdminActivityLog

        AdminActivityLog.objects.create(
            user=request.user if request.user.is_authenticated else None,
            action_type=action_type,
            model_name=model_name,
            object_id=object_id,
            object_repr=str(object_repr)[:255],
            changes=changes or {},
            ip_address=_get_client_ip(request),
            user_agent=(request.META.get('HTTP_USER_AGENT', '') or '')[:1000],
            path=(request.path or '')[:500],
        )
    except Exception:
        # Never let audit logging break the actual admin operation
        logger.exception('Failed to log admin action: %s %s', action_type, model_name)


def compute_model_diff(instance, new_values, fields=None):
    """
    Compute a diff between the current state of a model instance and new values.

    Args:
        instance: The Django model instance (before saving).
        new_values: Dict of {field_name: new_value} to compare against.
        fields: Optional list of field names to compare. If None, compares
                all keys present in new_values.

    Returns:
        Dict of {field_name: {'old': old_value, 'new': new_value}} for fields
        that actually changed. File/image fields are represented by their
        string names rather than the raw FieldFile objects.
    """
    diff = {}
    compare_fields = fields or list(new_values.keys())

    for field in compare_fields:
        if field not in new_values:
            continue
        old_val = getattr(instance, field, None)
        new_val = new_values[field]

        # Normalize file fields to string for comparison
        if hasattr(old_val, 'name'):
            old_val = old_val.name or ''
        if hasattr(new_val, 'name'):
            new_val = new_val.name or ''

        # Normalize None vs empty string
        old_str = str(old_val) if old_val is not None else ''
        new_str = str(new_val) if new_val is not None else ''

        if old_str != new_str:
            diff[field] = {
                'old': old_str[:500],
                'new': new_str[:500],
            }

    return diff


def _get_client_ip(request):
    """
    Extract the real client IP address from the request.
    Respects X-Forwarded-For (set by Cloudflare middleware) or REMOTE_ADDR.
    """
    forwarded_for = request.META.get('HTTP_X_FORWARDED_FOR', '')
    if forwarded_for:
        # Take the first IP in the chain (the real client)
        ip = forwarded_for.split(',')[0].strip()
    else:
        ip = request.META.get('REMOTE_ADDR', '127.0.0.1')
    return ip


def send_sms(phone_number, message):
    """
    Stub SMS sending function.

    Logs the message instead of actually sending it.
    To integrate with a real SMS provider, replace this stub with
    actual API calls and configure the provider's credentials in settings.

    Args:
        phone_number (str): The recipient's phone number (e.g., '+25779000000')
        message (str): The SMS message text (max ~160 chars for single SMS)

    Returns:
        bool: True if the SMS was "sent" (logged) successfully
    """
    if not phone_number or not message:
        logger.warning('SMS send failed: missing phone_number or message')
        return False

    # Validate phone number format (basic check)
    clean_number = phone_number.strip().replace(' ', '').replace('-', '')
    if not clean_number.startswith('+') or len(clean_number) < 8:
        logger.warning(f'SMS send failed: invalid phone number format: {phone_number}')
        return False

    # Log the SMS instead of actually sending
    logger.info(
        f'[SMS STUB] To: {phone_number} | Message: {message[:100]}'
        f'{"..." if len(message) > 100 else ""}'
    )

    # TODO: Replace with actual SMS provider integration

    return True


def send_sms_to_enabled_users(title, message):
    """
    Send SMS to all users with sms_enabled=True and a valid phone number.

    Args:
        title (str): The notification title (prepended to message)
        message (str): The notification message body

    Returns:
        tuple: (success_count, failure_count)
    """
    from core.models import UserProfile

    profiles = UserProfile.objects.filter(
        sms_enabled=True,
        user__is_active=True,
    ).exclude(
        phone_number=''
    ).exclude(
        phone_number__isnull=True
    )

    success_count = 0
    failure_count = 0

    sms_text = f"{title}: {message}"
    # Truncate to ~160 chars for a single SMS
    if len(sms_text) > 160:
        sms_text = sms_text[:157] + '...'

    for profile in profiles:
        if send_sms(profile.phone_number, sms_text):
            success_count += 1
        else:
            failure_count += 1

    logger.info(
        f'SMS batch send complete: {success_count} sent, {failure_count} failed '
        f'(out of {profiles.count()} eligible users)'
    )

    return success_count, failure_count
