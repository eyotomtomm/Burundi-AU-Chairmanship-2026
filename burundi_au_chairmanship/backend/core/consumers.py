"""
WebSocket consumers for real-time features.

LiveFeedConsumer  - ws/live-feeds/   Broadcasts live feed status changes and viewer counts.
NotificationConsumer - ws/notifications/  Delivers real-time notifications to authenticated users.
"""
import logging

from channels.generic.websocket import AsyncJsonWebsocketConsumer
from channels.db import database_sync_to_async

logger = logging.getLogger(__name__)


class LiveFeedConsumer(AsyncJsonWebsocketConsumer):
    """
    Real-time live feed updates.

    All connected clients join the 'live_feeds' group and receive:
    - feed_started: A new live feed has started streaming.
    - feed_ended: A live feed has ended.
    - viewer_count: Updated viewer count for a feed.

    Clients can send:
    - {"type": "join_feed", "feed_id": <int>}   — Start watching a specific feed.
    - {"type": "leave_feed", "feed_id": <int>}  — Stop watching a specific feed.
    """
    GROUP_NAME = 'live_feeds'

    async def connect(self):
        await self.channel_layer.group_add(self.GROUP_NAME, self.channel_name)
        await self.accept()
        logger.info("LiveFeed WebSocket connected: %s", self.channel_name)

    async def disconnect(self, close_code):
        await self.channel_layer.group_discard(self.GROUP_NAME, self.channel_name)
        logger.info("LiveFeed WebSocket disconnected: %s (code=%s)", self.channel_name, close_code)

    async def receive_json(self, content, **kwargs):
        """Handle incoming messages from the client."""
        msg_type = content.get('type')
        feed_id = content.get('feed_id')

        if msg_type == 'join_feed' and feed_id:
            # Add client to a feed-specific group for targeted updates
            feed_group = f'live_feed_{feed_id}'
            await self.channel_layer.group_add(feed_group, self.channel_name)
            # Increment viewer count
            new_count = await self._increment_viewer_count(feed_id)
            await self.channel_layer.group_send(feed_group, {
                'type': 'viewer_count_update',
                'feed_id': feed_id,
                'viewer_count': new_count,
            })

        elif msg_type == 'leave_feed' and feed_id:
            feed_group = f'live_feed_{feed_id}'
            await self.channel_layer.group_discard(feed_group, self.channel_name)
            # Decrement viewer count
            new_count = await self._decrement_viewer_count(feed_id)
            await self.channel_layer.group_send(feed_group, {
                'type': 'viewer_count_update',
                'feed_id': feed_id,
                'viewer_count': new_count,
            })

    # ─── Group message handlers (called via channel_layer.group_send) ──

    async def feed_started(self, event):
        """Broadcast when a live feed starts."""
        await self.send_json({
            'type': 'feed_started',
            'feed_id': event['feed_id'],
            'title': event.get('title', ''),
            'stream_url': event.get('stream_url', ''),
            'stream_type': event.get('stream_type', 'video'),
            'thumbnail': event.get('thumbnail', ''),
        })

    async def feed_ended(self, event):
        """Broadcast when a live feed ends."""
        await self.send_json({
            'type': 'feed_ended',
            'feed_id': event['feed_id'],
        })

    async def viewer_count_update(self, event):
        """Send updated viewer count to all watchers of a feed."""
        await self.send_json({
            'type': 'viewer_count',
            'feed_id': event['feed_id'],
            'viewer_count': event['viewer_count'],
        })

    # ─── Database helpers ─────────────────────────────────────

    @database_sync_to_async
    def _increment_viewer_count(self, feed_id):
        from .models import LiveFeed
        try:
            feed = LiveFeed.objects.get(pk=feed_id)
            feed.viewer_count = max(0, feed.viewer_count + 1)
            feed.save(update_fields=['viewer_count'])
            return feed.viewer_count
        except LiveFeed.DoesNotExist:
            return 0

    @database_sync_to_async
    def _decrement_viewer_count(self, feed_id):
        from .models import LiveFeed
        try:
            feed = LiveFeed.objects.get(pk=feed_id)
            feed.viewer_count = max(0, feed.viewer_count - 1)
            feed.save(update_fields=['viewer_count'])
            return feed.viewer_count
        except LiveFeed.DoesNotExist:
            return 0


class NotificationConsumer(AsyncJsonWebsocketConsumer):
    """
    Real-time notification delivery for authenticated users.

    Each authenticated user joins a personal group ('notifications_<user_id>')
    so the server can push notifications to specific users.
    Unauthenticated connections are closed immediately.

    Server pushes:
    - new_notification: A new notification was created for this user.
    - notification_count: Updated unread notification count.

    Clients can send:
    - {"type": "mark_read", "notification_id": <int>}  — Mark a notification as read.
    """

    async def connect(self):
        self.user = self.scope.get('user')
        if self.user is None or self.user.is_anonymous:
            await self.close(code=4001)
            return

        self.user_group = f'notifications_{self.user.id}'
        await self.channel_layer.group_add(self.user_group, self.channel_name)
        await self.accept()

        # Send current unread count on connect
        unread = await self._get_unread_count()
        await self.send_json({
            'type': 'notification_count',
            'unread_count': unread,
        })
        logger.info("Notification WebSocket connected for user %s", self.user.id)

    async def disconnect(self, close_code):
        if hasattr(self, 'user_group'):
            await self.channel_layer.group_discard(self.user_group, self.channel_name)
        logger.info("Notification WebSocket disconnected (code=%s)", close_code)

    async def receive_json(self, content, **kwargs):
        """Handle incoming messages from the client."""
        msg_type = content.get('type')

        if msg_type == 'mark_read':
            notification_id = content.get('notification_id')
            if notification_id:
                await self._mark_notification_read(notification_id)
                unread = await self._get_unread_count()
                await self.send_json({
                    'type': 'notification_count',
                    'unread_count': unread,
                })

    # ─── Group message handlers (called via channel_layer.group_send) ──

    async def new_notification(self, event):
        """Push a new notification to the connected user."""
        await self.send_json({
            'type': 'new_notification',
            'notification': {
                'id': event['notification_id'],
                'title': event.get('title', ''),
                'title_fr': event.get('title_fr', ''),
                'message': event.get('message', ''),
                'message_fr': event.get('message_fr', ''),
                'notification_type': event.get('notification_type', 'general'),
                'action_type': event.get('action_type', 'none'),
                'action_value': event.get('action_value', ''),
                'image': event.get('image', ''),
                'created_at': event.get('created_at', ''),
            },
        })

    async def notification_count(self, event):
        """Push updated unread count."""
        await self.send_json({
            'type': 'notification_count',
            'unread_count': event['unread_count'],
        })

    # ─── Database helpers ─────────────────────────────────────

    @database_sync_to_async
    def _get_unread_count(self):
        from .models import Notification
        from django.db.models import Q
        return Notification.objects.filter(
            is_active=True,
        ).filter(
            Q(is_global=True) | Q(target_users=self.user)
        ).exclude(
            read_by=self.user
        ).distinct().count()

    @database_sync_to_async
    def _mark_notification_read(self, notification_id):
        from .models import Notification
        try:
            notification = Notification.objects.get(pk=notification_id, is_active=True)
            notification.read_by.add(self.user)
        except Notification.DoesNotExist:
            pass
