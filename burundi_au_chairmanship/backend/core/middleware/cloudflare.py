"""
Cloudflare middleware — ensures the real client IP is used for rate limiting,
logging, and security even when requests arrive through Cloudflare's proxy.

Cloudflare sets the CF-Connecting-IP header to the visitor's original IP.
This middleware copies that value into REMOTE_ADDR so Django's built-in
throttling, authentication, and admin tools see the correct address.
"""


class CloudflareProxyMiddleware:
    """
    Sets REMOTE_ADDR to the real client IP provided by Cloudflare.

    Must be placed BEFORE any middleware that reads REMOTE_ADDR
    (SecurityMiddleware, throttling, etc.).
    """

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        # CF-Connecting-IP is the definitive client IP from Cloudflare
        cf_ip = request.META.get('HTTP_CF_CONNECTING_IP')
        if cf_ip:
            request.META['REMOTE_ADDR'] = cf_ip

        return self.get_response(request)
