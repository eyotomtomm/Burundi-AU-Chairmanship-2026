"""
WebSocket URL routing for Django Channels.

These patterns are loaded by config/asgi.py and map WebSocket
paths to their corresponding consumers.
"""
from django.urls import re_path

from . import consumers

websocket_urlpatterns = [
    re_path(r'ws/live-feeds/$', consumers.LiveFeedConsumer.as_asgi()),
    re_path(r'ws/notifications/$', consumers.NotificationConsumer.as_asgi()),
]
