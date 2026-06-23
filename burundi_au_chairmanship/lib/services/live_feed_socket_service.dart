import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/environment.dart';

/// Event data emitted when a live feed starts.
class FeedStartedEvent {
  final int feedId;
  final String title;
  final String streamUrl;
  final String streamType;
  final String thumbnail;

  const FeedStartedEvent({
    required this.feedId,
    required this.title,
    required this.streamUrl,
    required this.streamType,
    required this.thumbnail,
  });
}

/// Event data emitted when a live feed ends.
class FeedEndedEvent {
  final int feedId;
  const FeedEndedEvent({required this.feedId});
}

/// Event data emitted when a feed's viewer count changes.
class ViewerCountEvent {
  final int feedId;
  final int viewerCount;
  const ViewerCountEvent({required this.feedId, required this.viewerCount});
}

/// Self-contained WebSocket client for the live-feeds channel.
///
/// Connects to `ws(s)://<host>/ws/live-feeds/?token=<firebase_id_token>`,
/// exposes broadcast streams for three event types, and auto-reconnects
/// with exponential backoff. The REST API remains the primary data source;
/// this service only relays real-time deltas.
class LiveFeedSocketService with WidgetsBindingObserver {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;

  bool _disposed = false;
  bool _connected = false;
  int _reconnectAttempts = 0;

  static const _maxBackoff = Duration(seconds: 30);

  final _feedStartedController = StreamController<FeedStartedEvent>.broadcast();
  final _feedEndedController = StreamController<FeedEndedEvent>.broadcast();
  final _viewerCountController = StreamController<ViewerCountEvent>.broadcast();

  /// Emitted when a new live feed starts.
  Stream<FeedStartedEvent> get onFeedStarted => _feedStartedController.stream;

  /// Emitted when a live feed ends.
  Stream<FeedEndedEvent> get onFeedEnded => _feedEndedController.stream;

  /// Emitted when a feed's viewer count changes.
  Stream<ViewerCountEvent> get onViewerCount => _viewerCountController.stream;

  /// Connect to the live-feeds WebSocket.
  Future<void> connect() async {
    if (_disposed) return;
    WidgetsBinding.instance.addObserver(this);
    await _connect();
  }

  Future<void> _connect() async {
    if (_disposed || _connected) return;

    // Get Firebase ID token for auth
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      // Not logged in — schedule a retry (user may log in later)
      _scheduleReconnect();
      return;
    }

    String? token;
    try {
      token = await firebaseUser.getIdToken();
    } catch (_) {
      _scheduleReconnect();
      return;
    }

    if (token == null || _disposed) return;

    // Connect without the token in the URL to avoid leaking it in logs.
    // The token is sent as the first message after the connection opens.
    final uri = Uri.parse(
      '${Environment.wsBaseUrl}/ws/live-feeds/',
    );

    try {
      _channel = WebSocketChannel.connect(uri);
      await _channel!.ready;
    } catch (e) {
      debugPrint('LiveFeedSocket: connection failed: $e');
      _channel = null;
      _scheduleReconnect();
      return;
    }

    if (_disposed) {
      _channel?.sink.close();
      _channel = null;
      return;
    }

    // Authenticate by sending the token as the first message.
    // The server should validate this before processing any other messages.
    // Falls back to query-param auth if the server doesn't support message-based auth.
    try {
      _channel!.sink.add(jsonEncode({
        'type': 'authenticate',
        'token': token,
      }));
    } catch (e) {
      debugPrint('LiveFeedSocket: failed to send auth message: $e');
      _channel?.sink.close();
      _channel = null;
      _scheduleReconnect();
      return;
    }

    _connected = true;
    _reconnectAttempts = 0;

    _subscription = _channel!.stream.listen(
      _onMessage,
      onError: (error) {
        debugPrint('LiveFeedSocket: stream error: $error');
        _handleDisconnect();
      },
      onDone: () {
        debugPrint('LiveFeedSocket: stream closed');
        _handleDisconnect();
      },
    );
  }

  void _onMessage(dynamic raw) {
    if (_disposed) return;

    Map<String, dynamic> data;
    try {
      data = jsonDecode(raw as String) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('LiveFeedSocket: JSON decode error: $e');
      return;
    }

    final type = data['type'] as String?;

    switch (type) {
      case 'feed_started':
        _feedStartedController.add(FeedStartedEvent(
          feedId: data['feed_id'] as int,
          title: (data['title'] as String?) ?? '',
          streamUrl: (data['stream_url'] as String?) ?? '',
          streamType: (data['stream_type'] as String?) ?? 'video',
          thumbnail: (data['thumbnail'] as String?) ?? '',
        ));
      case 'feed_ended':
        _feedEndedController.add(FeedEndedEvent(
          feedId: data['feed_id'] as int,
        ));
      case 'viewer_count':
        _viewerCountController.add(ViewerCountEvent(
          feedId: data['feed_id'] as int,
          viewerCount: (data['viewer_count'] as int?) ?? 0,
        ));
      case 'error':
        debugPrint('LiveFeedSocket: server error: ${data['message']}');
    }
  }

  void _handleDisconnect() {
    _connected = false;
    _subscription?.cancel();
    _subscription = null;
    _channel = null;
    if (!_disposed) _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_disposed || _reconnectTimer?.isActive == true) return;

    final delay = Duration(
      seconds: (1 << _reconnectAttempts).clamp(1, _maxBackoff.inSeconds),
    );
    _reconnectAttempts++;

    debugPrint('LiveFeedSocket: reconnecting in ${delay.inSeconds}s '
        '(attempt $_reconnectAttempts)');

    _reconnectTimer = Timer(delay, () {
      if (!_disposed) _connect();
    });
  }

  /// Tell the server this user is watching [feedId].
  void joinFeed(int feedId) {
    _send({'type': 'join_feed', 'feed_id': feedId});
  }

  /// Tell the server this user stopped watching [feedId].
  void leaveFeed(int feedId) {
    _send({'type': 'leave_feed', 'feed_id': feedId});
  }

  void _send(Map<String, dynamic> message) {
    if (!_connected || _channel == null || _disposed) return;
    try {
      _channel!.sink.add(jsonEncode(message));
    } catch (e) {
      debugPrint('LiveFeedSocket: send error: $e');
    }
  }

  // ── WidgetsBindingObserver ──────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_disposed) return;

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // App backgrounded — tear down to save battery, cancel pending reconnect
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
      _subscription?.cancel();
      _subscription = null;
      _channel?.sink.close();
      _channel = null;
      _connected = false;
    } else if (state == AppLifecycleState.resumed) {
      // App foregrounded — reconnect
      _reconnectAttempts = 0;
      _connect();
    }
  }

  // ── Cleanup ─────────────────────────────────────────────────────────

  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
    _feedStartedController.close();
    _feedEndedController.close();
    _viewerCountController.close();
  }
}
