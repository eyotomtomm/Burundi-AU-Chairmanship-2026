"""
ASGI config for the Be 4 Africa project.

Supports both HTTP and WebSocket connections via Django Channels.
WebSocket routes are defined in core.routing.
"""
import os
from channels.routing import ProtocolTypeRouter, URLRouter
from channels.auth import AuthMiddlewareStack
from channels.security.websocket import AllowedHostsOriginValidator
from django.core.asgi import get_asgi_application

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')

# Initialize Django ASGI application early to ensure apps are loaded
# before importing routing (which references models).
django_asgi_app = get_asgi_application()

from core import routing  # noqa: E402 — must be imported after Django setup


async def lifespan(scope, receive, send):
    """Handle ASGI lifespan protocol so uvicorn doesn't log warnings."""
    while True:
        message = await receive()
        if message["type"] == "lifespan.startup":
            await send({"type": "lifespan.startup.complete"})
        elif message["type"] == "lifespan.shutdown":
            await send({"type": "lifespan.shutdown.complete"})
            return


application = ProtocolTypeRouter({
    'http': django_asgi_app,
    'websocket': AllowedHostsOriginValidator(
        AuthMiddlewareStack(
            URLRouter(routing.websocket_urlpatterns)
        ),
    ),
    'lifespan': lifespan,
})
