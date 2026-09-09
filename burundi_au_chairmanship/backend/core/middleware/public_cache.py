"""Let a response that says it is public actually be cached by a shared cache."""


class PublicCacheVaryMiddleware:
    """Trim `Vary` on responses that asked to be publicly cacheable.

    Session, CORS and CSRF middleware each append to `Vary` on the way out, so
    a view cannot set the header and expect it to survive: by the time the
    response leaves Django it reads `Vary: Accept-Encoding, origin, Cookie`,
    and a shared cache treats `Cookie` as one stored object per visitor. The
    effect is that nothing is ever served from the edge — measured on
    burundi4africa.com, every response came back DYNAMIC or BYPASS.

    Only responses that explicitly set `Cache-Control: public` are touched, so
    a view opts in by saying so; everything else keeps whatever Vary the
    middleware stack built. This must sit first in MIDDLEWARE — the response
    phase runs in reverse, so first in the list is last to see the response.
    """

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        response = self.get_response(request)
        if 'public' in response.get('Cache-Control', ''):
            response['Vary'] = 'Accept-Encoding'
        return response
