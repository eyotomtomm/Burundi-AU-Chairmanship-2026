"""
Firebase Cloud Messaging push notification service.

Handles collecting target tokens based on notification targeting rules
and dispatching FCM messages to devices.

Supports:
- Language-specific push notifications (EN/FR)
- Multi-account device handling via DeviceToken model
- Deduplication of tokens to prevent duplicate sends
- Open tracking via opened_count field
"""

import logging
from datetime import date

from django.conf import settings
from django.utils import timezone

from core.models import UserProfile, DeviceToken, Notification

logger = logging.getLogger(__name__)


def get_target_profiles(notification):
    """
    Collect target UserProfile queryset based on notification targeting fields.

    Returns a filtered queryset of UserProfile objects (not just tokens).
    This allows language-specific message dispatch.

    Includes profiles that have EITHER a legacy fcm_token OR active entries
    in the DeviceToken model, so users who registered tokens via the
    ``register_fcm_token`` endpoint (which only creates DeviceToken rows)
    are not silently excluded.
    """
    from django.db.models import Q

    profiles = UserProfile.objects.filter(
        Q(fcm_token__isnull=False) & ~Q(fcm_token='')
        | Q(user__device_tokens__is_active=True)
    ).select_related('user').distinct()

    if notification.is_global:
        # Apply language filter even for global notifications
        if notification.target_language:
            profiles = profiles.filter(preferred_language=notification.target_language)
        return profiles

    # Specific users take priority over filter-based targeting
    if notification.target_users.exists():
        profiles = profiles.filter(user__in=notification.target_users.all())
        if notification.target_language:
            profiles = profiles.filter(preferred_language=notification.target_language)
        return profiles

    # Filter-based targeting
    if notification.target_gender:
        profiles = profiles.filter(gender=notification.target_gender)

    if notification.target_nationalities:
        profiles = profiles.filter(nationality__in=notification.target_nationalities)

    if notification.target_language:
        profiles = profiles.filter(preferred_language=notification.target_language)

    today = date.today()
    if notification.target_age_min is not None:
        max_dob = today.replace(year=today.year - notification.target_age_min)
        profiles = profiles.filter(date_of_birth__lte=max_dob)

    if notification.target_age_max is not None:
        min_dob = today.replace(year=today.year - notification.target_age_max - 1)
        profiles = profiles.filter(date_of_birth__gte=min_dob)

    # Verification-based targeting
    if notification.target_verified_only:
        profiles = profiles.filter(is_verified=True)
        if notification.target_badge_type:
            profiles = profiles.filter(badge_type=notification.target_badge_type)

    return profiles


def get_target_tokens(notification):
    """
    Collect FCM tokens based on notification targeting fields.
    Uses both DeviceToken model (preferred) and legacy UserProfile.fcm_token.
    For global notifications, also includes anonymous device tokens (user=None).

    Returns a list of non-empty, deduplicated FCM token strings.
    """
    profiles = get_target_profiles(notification)
    user_ids = list(profiles.values_list('user_id', flat=True))

    # Collect tokens from DeviceToken model (active tokens only, deduplicated)
    device_tokens = list(
        DeviceToken.objects.filter(
            user_id__in=user_ids,
            is_active=True,
        ).values_list('token', flat=True).distinct()
    )

    # Include anonymous device tokens for global notifications
    if notification.is_global:
        anonymous_tokens = list(
            DeviceToken.objects.filter(
                user__isnull=True,
                is_active=True,
            ).values_list('token', flat=True).distinct()
        )
        device_tokens = list(set(device_tokens + anonymous_tokens))

    # Also collect legacy tokens from UserProfile for backward compatibility
    legacy_tokens = list(profiles.values_list('fcm_token', flat=True))

    # Merge and deduplicate
    all_tokens = list(set(device_tokens + [t for t in legacy_tokens if t]))
    return all_tokens


def get_target_tokens_by_language(notification):
    """
    Collect FCM tokens grouped by language preference.

    Returns dict: {'en': [tokens...], 'fr': [tokens...]}

    Language is resolved in this priority order:
      1. Authenticated user: ``UserProfile.preferred_language``
      2. Anonymous device: ``DeviceToken.preferred_language`` (set from the
         client's current in-app language at token registration time)
      3. Default: ``'en'``

    This ensures anonymous users browsing in French receive the French
    push variant instead of being silently bucketed into English.
    When the admin set a ``target_language`` filter, only tokens matching
    that language are returned.
    """
    profiles = get_target_profiles(notification)
    tokens_by_lang = {'en': [], 'fr': []}

    for lang_code in ('en', 'fr'):
        # Skip the bucket entirely if the admin explicitly targeted the other language.
        if notification.target_language and notification.target_language != lang_code:
            continue

        lang_profiles = profiles.filter(preferred_language=lang_code)
        lang_user_ids = list(lang_profiles.values_list('user_id', flat=True))

        # Collect from DeviceToken model (active only, deduplicated)
        device_tokens = list(
            DeviceToken.objects.filter(
                user_id__in=lang_user_ids,
                is_active=True,
            ).values_list('token', flat=True).distinct()
        )

        # Also collect legacy tokens
        legacy_tokens = list(lang_profiles.values_list('fcm_token', flat=True))

        tokens_by_lang[lang_code] = list(set(
            device_tokens + [t for t in legacy_tokens if t]
        ))

    # Include anonymous device tokens for global notifications, bucketed by
    # their own ``preferred_language`` so anonymous FR users get FR content.
    if notification.is_global:
        all_assigned = set(tokens_by_lang['en'] + tokens_by_lang['fr'])
        anon_qs = DeviceToken.objects.filter(
            user__isnull=True,
            is_active=True,
        )
        if notification.target_language:
            anon_qs = anon_qs.filter(preferred_language=notification.target_language)

        anon_rows = list(anon_qs.values_list('token', 'preferred_language').distinct())
        for token, anon_lang in anon_rows:
            if not token or token in all_assigned:
                continue
            bucket = 'fr' if anon_lang == 'fr' else 'en'
            if notification.target_language and bucket != notification.target_language:
                continue
            tokens_by_lang[bucket].append(token)
            all_assigned.add(token)

        # Deduplicate final buckets
        tokens_by_lang['en'] = list(set(tokens_by_lang['en']))
        tokens_by_lang['fr'] = list(set(tokens_by_lang['fr']))

    return tokens_by_lang


def get_target_audience_count(notification):
    """
    Return the number of unique devices that would receive this notification.
    Used for audience preview in admin before sending.
    Includes anonymous device tokens for global notifications.
    """
    profiles = get_target_profiles(notification)
    count = profiles.count()

    # Add anonymous device tokens for global notifications
    if notification.is_global:
        anonymous_count = DeviceToken.objects.filter(
            user__isnull=True,
            is_active=True,
        ).count()
        count += anonymous_count

    return count


def send_push_to_users(user_ids, title, body, data=None):
    """
    Synchronous push to specific users — used as fallback when Celery/Redis
    is unavailable.  Collects tokens from both DeviceToken and legacy
    UserProfile, sends via FCM, and cleans stale tokens.
    """
    try:
        from config.firebase import initialize_firebase
        initialize_firebase()
        from firebase_admin import messaging
    except ImportError:
        logger.error("firebase_admin not available for synchronous push fallback")
        return

    device_tokens = list(
        DeviceToken.objects.filter(
            user_id__in=user_ids, is_active=True,
        ).values_list('token', flat=True).distinct()
    )
    legacy_tokens = list(
        UserProfile.objects.filter(
            user_id__in=user_ids, fcm_token__isnull=False,
        ).exclude(fcm_token='').values_list('fcm_token', flat=True)
    )
    tokens = list(set(device_tokens + [t for t in legacy_tokens if t]))
    if not tokens:
        return

    fcm_messages = [
        messaging.Message(
            notification=messaging.Notification(title=title, body=body),
            data={k: str(v) for k, v in (data or {}).items()},
            token=token,
            android=messaging.AndroidConfig(
                priority='high',
                notification=messaging.AndroidNotification(
                    channel_id='default_channel',
                    priority='max',
                    default_sound=True,
                    default_vibrate_timings=True,
                ),
            ),
            apns=messaging.APNSConfig(
                headers={'apns-priority': '10'},
                payload=messaging.APNSPayload(
                    aps=messaging.Aps(sound='default', badge=1),
                ),
            ),
        )
        for token in tokens
    ]

    try:
        response = messaging.send_each(fcm_messages)
        # Clean stale tokens
        stale = [
            tokens[i] for i, r in enumerate(response.responses)
            if r.exception and isinstance(
                r.exception,
                (messaging.UnregisteredError, messaging.SenderIdMismatchError),
            )
        ]
        if stale:
            UserProfile.objects.filter(fcm_token__in=stale).update(fcm_token='')
            DeviceToken.objects.filter(token__in=stale).update(is_active=False)
        logger.info(
            f"Sync push: {response.success_count} sent, "
            f"{response.failure_count} failed, {len(stale)} stale cleaned"
        )
    except Exception as exc:
        logger.error(f"Sync push failed: {exc}")


def send_push_notification(notification):
    """
    Build and send FCM messages for a Notification instance.

    Sends language-specific content:
    - French users receive title_fr/message_fr (falls back to EN if empty)
    - English users receive title/message

    Uses firebase_admin.messaging.send_each() in batches of 500.
    Clears stale tokens on UnregisteredError.
    Updates notification push tracking fields.

    Returns (success_count, failure_count) tuple.
    """
    try:
        from config.firebase import initialize_firebase
        initialize_firebase()
        from firebase_admin import messaging
    except ImportError:
        logger.error("firebase_admin.messaging not available")
        raise RuntimeError("Firebase Admin SDK messaging module is not installed.")

    # Get tokens grouped by language
    tokens_by_lang = get_target_tokens_by_language(notification)

    all_token_count = sum(len(t) for t in tokens_by_lang.values())
    if all_token_count == 0:
        logger.info(f"No FCM tokens found for notification #{notification.pk}")
        notification.push_sent = True
        notification.push_sent_at = timezone.now()
        notification.push_recipient_count = 0
        notification.push_recipient_en = 0
        notification.push_recipient_fr = 0
        notification.save(update_fields=[
            'push_sent', 'push_sent_at', 'push_recipient_count',
            'push_recipient_en', 'push_recipient_fr',
        ])
        return 0, 0

    # Build the data payload the Flutter app expects
    data_payload = {
        'type': notification.notification_type or 'general',
        'action_type': notification.action_type or 'none',
        'action_value': notification.action_value or '',
        'notification_id': str(notification.pk),
    }

    # Build absolute image URL for rich push notifications
    image_url = None
    if notification.image:
        url = notification.image.url
        if url.startswith('http'):
            # Already absolute (e.g. DigitalOcean Spaces / CDN)
            image_url = url
        else:
            # Relative path — prepend SITE_URL
            site_url = getattr(settings, 'SITE_URL', '').rstrip('/')
            if site_url:
                image_url = f"{site_url}{url}"

    # Android config: explicit channel + high priority so background
    # notifications are displayed immediately on Android 8+ (API 26+).
    android_config = messaging.AndroidConfig(
        priority='high',
        notification=messaging.AndroidNotification(
            channel_id='default_channel',
            priority='max',
            default_sound=True,
            default_vibrate_timings=True,
            notification_count=1,
            icon='@mipmap/ic_launcher',
            image=image_url,
        ),
    )

    # APNS config for iOS: always set so banners, badges, and sounds
    # are displayed reliably. Add mutable-content when an image is
    # present so the notification service extension can download it.
    # NOTE: Do NOT set content_available=True for visible notifications.
    # On iOS, content_available marks the push as a silent background
    # update. When combined with an alert payload iOS *usually* shows
    # it, but if the user has force-quit the app, iOS may suppress the
    # display entirely. Only use content_available for data-only pushes.
    apns_config = messaging.APNSConfig(
        headers={
            'apns-priority': '10',  # immediate delivery
        },
        payload=messaging.APNSPayload(
            aps=messaging.Aps(
                sound='default',
                badge=1,
                mutable_content=bool(image_url),
            ),
        ),
        fcm_options=messaging.APNSFCMOptions(image=image_url) if image_url else None,
    )

    total_success = 0
    total_failure = 0
    stale_tokens = []
    success_by_lang = {'en': 0, 'fr': 0}

    # Send per-language batches
    for lang_code, tokens in tokens_by_lang.items():
        if not tokens:
            continue

        # Select correct language content
        if lang_code == 'fr':
            title = notification.title_fr or notification.title
            body = notification.message_fr or notification.message
        else:
            title = notification.title
            body = notification.message

        fcm_notification = messaging.Notification(
            title=title,
            body=body,
            image=image_url,
        )

        # Send in batches of 500 (FCM limit for send_each)
        batch_size = 500
        for i in range(0, len(tokens), batch_size):
            batch_tokens = tokens[i:i + batch_size]
            fcm_messages = [
                messaging.Message(
                    notification=fcm_notification,
                    data=data_payload,
                    token=token,
                    android=android_config,
                    apns=apns_config,
                )
                for token in batch_tokens
            ]

            response = messaging.send_each(fcm_messages)
            total_success += response.success_count
            total_failure += response.failure_count
            success_by_lang[lang_code] += response.success_count

            # Collect stale tokens for cleanup and log all errors
            for j, send_response in enumerate(response.responses):
                if send_response.exception:
                    if isinstance(
                        send_response.exception,
                        (messaging.UnregisteredError, messaging.SenderIdMismatchError),
                    ):
                        stale_tokens.append(batch_tokens[j])
                    else:
                        logger.warning(
                            'FCM send error for notification #%s token=%s…: %s: %s',
                            notification.pk,
                            batch_tokens[j][:12],
                            type(send_response.exception).__name__,
                            send_response.exception,
                        )

    # Clean up stale tokens from both DeviceToken and legacy UserProfile
    if stale_tokens:
        cleaned_legacy = UserProfile.objects.filter(
            fcm_token__in=stale_tokens
        ).update(fcm_token='')
        cleaned_device = DeviceToken.objects.filter(
            token__in=stale_tokens
        ).update(is_active=False)
        logger.info(
            f"Cleared {cleaned_legacy} stale legacy tokens, "
            f"deactivated {cleaned_device} device tokens"
        )

    # Update notification tracking (including per-language split)
    notification.push_sent = True
    notification.push_sent_at = timezone.now()
    notification.push_recipient_count = total_success
    notification.push_recipient_en = success_by_lang['en']
    notification.push_recipient_fr = success_by_lang['fr']
    notification.save(update_fields=[
        'push_sent', 'push_sent_at', 'push_recipient_count',
        'push_recipient_en', 'push_recipient_fr',
    ])

    logger.info(
        f"Push notification #{notification.pk}: "
        f"{total_success} sent ({success_by_lang['en']} EN, {success_by_lang['fr']} FR), "
        f"{total_failure} failed, {len(stale_tokens)} stale tokens cleared"
    )

    return total_success, total_failure
