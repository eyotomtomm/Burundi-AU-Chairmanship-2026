"""
ASGI config for the Be 4 Africa project.

Supports both HTTP and WebSocket connections via Django Channels.
WebSocket routes are defined in core.routing.
"""
import os
from channels.routing import ProtocolTypeRouter, URLRouter
from channels.auth import AuthMiddlewareStack
from django.core.asgi import get_asgi_application

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')

# Initialize Django ASGI application early to ensure apps are loaded
# before importing routing (which references models).
django_asgi_app = get_asgi_application()

from core import routing  # noqa: E402 — must be imported after Django setup

application = ProtocolTypeRouter({
    'http': django_asgi_app,
    'websocket': AuthMiddlewareStack(
        URLRouter(routing.websocket_urlpatterns)
    ),
})
