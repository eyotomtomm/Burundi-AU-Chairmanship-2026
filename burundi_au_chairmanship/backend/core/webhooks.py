"""
Webhook dispatch logic for external integrations.

Usage:
    from core.webhooks import send_webhook
    send_webhook('user.registered', {'user_id': 123, 'username': 'john'})
"""

import json
import logging
import time

import requests
from django.utils import timezone

logger = logging.getLogger(__name__)


def _format_slack_payload(event_type, data):
    """Format payload for Slack incoming webhooks."""
    event_display = event_type.replace('.', ' ').replace('_', ' ').title()
    text = f"*{event_display}*"

    fields = []
    for key, value in data.items():
        fields.append({
            "type": "mrkdwn",
            "text": f"*{key}:* {value}"
        })

    blocks = [
        {
            "type": "header",
            "text": {
                "type": "plain_text",
                "text": f"Be 4 Africa: {event_display}",
            }
        },
        {
            "type": "section",
            "fields": fields[:10],  # Slack limits fields
        },
        {
            "type": "context",
            "elements": [
                {
                    "type": "mrkdwn",
                    "text": f"Event: `{event_type}` | Sent at {timezone.now().strftime('%Y-%m-%d %H:%M:%S UTC')}"
                }
            ]
        }
    ]

    return {"text": text, "blocks": blocks}


def _format_teams_payload(event_type, data):
    """Format payload for Microsoft Teams incoming webhooks."""
    event_display = event_type.replace('.', ' ').replace('_', ' ').title()

    facts = []
    for key, value in data.items():
        facts.append({"name": str(key), "value": str(value)})

    return {
        "@type": "MessageCard",
        "@context": "http://schema.org/extensions",
        "themeColor": "0076D7",
        "summary": f"Be 4 Africa: {event_display}",
        "sections": [
            {
                "activityTitle": f"Be 4 Africa: {event_display}",
                "activitySubtitle": f"Event: {event_type}",
                "facts": facts[:10],
                "markdown": True,
            }
        ],
    }


def _format_discord_payload(event_type, data):
    """Format payload for Discord webhooks."""
    event_display = event_type.replace('.', ' ').replace('_', ' ').title()

    fields = []
    for key, value in data.items():
        fields.append({
            "name": str(key),
            "value": str(value),
            "inline": True,
        })

    return {
        "content": f"**Be 4 Africa: {event_display}**",
        "embeds": [
            {
                "title": event_display,
                "color": 30191,  # Cyan-ish
                "fields": fields[:25],  # Discord limits
                "footer": {
                    "text": f"Event: {event_type}"
                },
                "timestamp": timezone.now().isoformat(),
            }
        ],
    }


def _format_custom_payload(event_type, data):
    """Format payload for custom webhook endpoints."""
    return {
        "event": event_type,
        "timestamp": timezone.now().isoformat(),
        "data": data,
    }


FORMATTERS = {
    'slack': _format_slack_payload,
    'teams': _format_teams_payload,
    'discord': _format_discord_payload,
    'custom': _format_custom_payload,
}


def send_webhook(event_type, data):
    """
    Dispatch webhook to all active endpoints subscribed to the given event_type.

    Args:
        event_type: str - e.g. 'user.registered', 'article.published'
        data: dict - payload data to send

    Returns:
        list of (webhook_id, success, status_code) tuples
    """
    from core.models import Webhook, WebhookLog

    results = []

    webhooks = Webhook.objects.filter(is_active=True)
    matching_webhooks = []
    for wh in webhooks:
        if isinstance(wh.events, list) and event_type in wh.events:
            matching_webhooks.append(wh)

    for webhook in matching_webhooks:
        formatter = FORMATTERS.get(webhook.service_type, _format_custom_payload)
        payload = formatter(event_type, data)

        headers = {
            'Content-Type': 'application/json',
            'User-Agent': 'AU-Chairmanship-Webhook/1.0',
        }

        # Add secret key header if configured
        if webhook.secret_key:
            headers['X-Webhook-Secret'] = webhook.secret_key

        # Add custom headers
        if isinstance(webhook.custom_headers, dict):
            headers.update(webhook.custom_headers)

        success = False
        status_code = None
        response_body = ''
        duration_ms = None

        try:
            start_time = time.time()
            response = requests.post(
                webhook.url,
                json=payload,
                headers=headers,
                timeout=5,
            )
            duration_ms = int((time.time() - start_time) * 1000)
            status_code = response.status_code
            response_body = response.text[:2000]  # Truncate long responses
            success = 200 <= response.status_code < 300

            if success:
                webhook.failure_count = 0
            else:
                webhook.failure_count += 1

        except requests.Timeout:
            duration_ms = 5000
            response_body = 'Request timed out after 5 seconds'
            webhook.failure_count += 1
            logger.warning(f"Webhook timeout: {webhook.name} ({webhook.url})")

        except requests.ConnectionError as e:
            response_body = f'Connection error: {str(e)[:500]}'
            webhook.failure_count += 1
            logger.warning(f"Webhook connection error: {webhook.name} ({webhook.url})")

        except Exception as e:
            response_body = f'Unexpected error: {str(e)[:500]}'
            webhook.failure_count += 1
            logger.error(f"Webhook error: {webhook.name} ({webhook.url}): {e}")

        # Update webhook metadata
        webhook.last_triggered_at = timezone.now()
        webhook.save(update_fields=['last_triggered_at', 'failure_count'])

        # Create log entry
        WebhookLog.objects.create(
            webhook=webhook,
            event=event_type,
            payload=payload,
            response_status=status_code,
            response_body=response_body,
            success=success,
            duration_ms=duration_ms,
        )

        results.append((webhook.id, success, status_code))

    return results


def send_test_webhook(webhook):
    """
    Send a test payload to a specific webhook.

    Args:
        webhook: Webhook model instance

    Returns:
        (success: bool, status_code: int|None, error: str|None)
    """
    from core.models import WebhookLog

    formatter = FORMATTERS.get(webhook.service_type, _format_custom_payload)
    test_data = {
        'test': True,
        'message': 'This is a test webhook from Be 4 Africa Admin Portal',
        'timestamp': timezone.now().isoformat(),
    }
    payload = formatter('test.ping', test_data)

    headers = {
        'Content-Type': 'application/json',
        'User-Agent': 'AU-Chairmanship-Webhook/1.0',
    }

    if webhook.secret_key:
        headers['X-Webhook-Secret'] = webhook.secret_key

    if isinstance(webhook.custom_headers, dict):
        headers.update(webhook.custom_headers)

    try:
        start_time = time.time()
        response = requests.post(
            webhook.url,
            json=payload,
            headers=headers,
            timeout=5,
        )
        duration_ms = int((time.time() - start_time) * 1000)

        success = 200 <= response.status_code < 300

        WebhookLog.objects.create(
            webhook=webhook,
            event='test.ping',
            payload=payload,
            response_status=response.status_code,
            response_body=response.text[:2000],
            success=success,
            duration_ms=duration_ms,
        )

        if success:
            return True, response.status_code, None
        else:
            return False, response.status_code, f'HTTP {response.status_code}: {response.text[:200]}'

    except requests.Timeout:
        WebhookLog.objects.create(
            webhook=webhook,
            event='test.ping',
            payload=payload,
            response_status=None,
            response_body='Request timed out',
            success=False,
            duration_ms=5000,
        )
        return False, None, 'Request timed out after 5 seconds'

    except requests.ConnectionError as e:
        WebhookLog.objects.create(
            webhook=webhook,
            event='test.ping',
            payload=payload,
            response_status=None,
            response_body=str(e)[:500],
            success=False,
        )
        return False, None, f'Connection error: {str(e)[:200]}'

    except Exception as e:
        return False, None, f'Error: {str(e)[:200]}'
