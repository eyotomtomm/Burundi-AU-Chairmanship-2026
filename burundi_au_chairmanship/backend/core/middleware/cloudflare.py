"""
Cloudflare middleware — ensures the real client IP is used for rate limiting,
logging, and security even when requests arrive through Cloudflare's proxy.

Cloudflare sets the CF-Connecting-IP header to the visitor's original IP.
This middleware copies that value into REMOTE_ADDR *only* when the request
actually originates from a Cloudflare edge server (verified by source IP).

Without this check, an attacker who reaches the origin directly can set a
spoofed CF-Connecting-IP header to bypass IP-based throttling and django-axes
lockouts.

Cloudflare IP ranges: https://www.cloudflare.com/ips/
Last updated: 2026-07-02 — check the URL above periodically for changes.
"""

import ipaddress
import logging

from django.conf import settings

logger = logging.getLogger(__name__)

# Published Cloudflare edge IP ranges.
# Source: https://www.cloudflare.com/ips-v4  /  https://www.cloudflare.com/ips-v6
_CF_IPV4 = [
    '173.245.48.0/20',
    '103.21.244.0/22',
    '103.22.200.0/22',
    '103.31.4.0/22',
    '141.101.64.0/18',
    '108.162.192.0/18',
    '190.93.240.0/20',
    '188.114.96.0/20',
    '197.234.240.0/22',
    '198.41.128.0/17',
    '162.158.0.0/15',
    '104.16.0.0/13',
    '104.24.0.0/14',
    '172.64.0.0/13',
    '131.0.72.0/22',
]

_CF_IPV6 = [
    '2400:cb00::/32',
    '2606:4700::/32',
    '2803:f800::/32',
    '2405:b500::/32',
    '2405:8100::/32',
    '2a06:98c0::/29',
    '2c0f:f248::/32',
]

CLOUDFLARE_NETWORKS = [
    ipaddress.ip_network(cidr) for cidr in _CF_IPV4 + _CF_IPV6
]


def _is_cloudflare_ip(ip_str):
    """Return True if *ip_str* belongs to a known Cloudflare edge range."""
    try:
        addr = ipaddress.ip_address(ip_str)
    except (ValueError, TypeError):
        return False
    return any(addr in net for net in CLOUDFLARE_NETWORKS)


def get_client_ip(request):
    """The real client IP as resolved by CloudflareProxyMiddleware.

    Single source of truth — every IP-based feature (throttling, login
    history, geo lookups, QR scan logs) should call this rather than read
    REMOTE_ADDR / X-Forwarded-For itself.
    """
    return request.META.get('REMOTE_ADDR', '')


def _xff_hops(request):
    xff = request.META.get('HTTP_X_FORWARDED_FOR', '')
    return [h.strip() for h in xff.split(',') if h.strip()]


class CloudflareProxyMiddleware:
    """
    Sets REMOTE_ADDR to the real client IP.

    Two trusted topologies:
      1. Cloudflare -> origin: REMOTE_ADDR is a Cloudflare edge IP, so
         CF-Connecting-IP is trusted.
      2. Cloudflare -> platform router (DigitalOcean App Platform) -> app:
         REMOTE_ADDR is the router, and the router appends its peer (the
         Cloudflare edge) as the LAST X-Forwarded-For hop. When
         settings.TRUST_PLATFORM_PROXY is on and that last hop is a
         Cloudflare IP, CF-Connecting-IP is trusted. If the last hop is not
         Cloudflare, the request bypassed Cloudflare and that hop *is* the
         client (the router appended it, so the client cannot forge it).

    Anything else keeps the original REMOTE_ADDR, so an attacker hitting the
    origin directly cannot spoof CF-Connecting-IP or X-Forwarded-For to dodge
    throttling / django-axes lockouts.

    The resolved IP is also written back to X-Forwarded-For so libraries that
    read that header (DRF throttling with NUM_PROXIES, axes) agree with us.

    Must be placed BEFORE any middleware that reads REMOTE_ADDR.
    """

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        cf_ip = request.META.get('HTTP_CF_CONNECTING_IP')
        remote = request.META.get('REMOTE_ADDR', '')
        hops = _xff_hops(request) if getattr(settings, 'TRUST_PLATFORM_PROXY', False) else []
        resolved = None

        if cf_ip and _is_cloudflare_ip(remote):
            resolved = cf_ip
        elif hops:
            resolved = cf_ip if (cf_ip and _is_cloudflare_ip(hops[-1])) else hops[-1]
        elif cf_ip:
            # CF-Connecting-IP from a peer that is neither Cloudflare nor the
            # platform router: ignore it. Debug level — this is expected noise
            # from scanners hitting the origin directly.
            logger.debug('Ignoring CF-Connecting-IP=%s from non-Cloudflare source %s', cf_ip, remote)

        if resolved:
            request.META['REMOTE_ADDR'] = resolved
            if 'HTTP_X_FORWARDED_FOR' in request.META:
                request.META['HTTP_X_FORWARDED_FOR'] = resolved

        return self.get_response(request)
