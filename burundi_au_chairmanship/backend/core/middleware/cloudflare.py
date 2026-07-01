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


class CloudflareProxyMiddleware:
    """
    Sets REMOTE_ADDR to the real client IP provided by Cloudflare.

    The CF-Connecting-IP header is only trusted when the immediate upstream
    (REMOTE_ADDR set by the WSGI server / DO App Platform router) is a
    Cloudflare IP.  Requests that bypass Cloudflare and hit the origin
    directly will retain the original REMOTE_ADDR.

    Must be placed BEFORE any middleware that reads REMOTE_ADDR
    (SecurityMiddleware, throttling, etc.).
    """

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        cf_ip = request.META.get('HTTP_CF_CONNECTING_IP')
        if cf_ip:
            upstream_ip = request.META.get('REMOTE_ADDR', '')
            if _is_cloudflare_ip(upstream_ip):
                request.META['REMOTE_ADDR'] = cf_ip
            else:
                # Someone is sending CF-Connecting-IP without coming through
                # Cloudflare.  Log it and ignore the header.
                logger.warning(
                    'Ignoring CF-Connecting-IP=%s from non-Cloudflare source %s',
                    cf_ip, upstream_ip,
                )

        return self.get_response(request)
