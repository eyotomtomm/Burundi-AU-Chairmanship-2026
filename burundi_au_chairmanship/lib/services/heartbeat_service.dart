import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'api_service.dart';
import 'firebase_messaging_service.dart';

/// Periodically pings the backend so the admin dashboard's "users online now"
/// counter reflects the real active audience.
///
/// Lifecycle behaviour:
///  - Starts a 60s timer as soon as [start] is called.
///  - Stops the timer when the app is backgrounded.
///  - Resumes the timer (and sends an immediate ping) when foregrounded.
///  - Fully idempotent — repeated [start]/[stop] calls are safe.
///
/// Presence pings are fire-and-forget. Network or auth failures never surface
/// to the user and never break the app.
class HeartbeatService with WidgetsBindingObserver {
  HeartbeatService._();
  static final HeartbeatService instance = HeartbeatService._();

  static const Duration _interval = Duration(seconds: 60);

  Timer? _timer;
  bool _started = false;

  /// Attach the lifecycle observer and begin heartbeating.
  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _beginTimer();
    // Fire an immediate ping so the user appears online as soon as the app
    // is ready, rather than waiting a full interval.
    _ping();
  }

  /// Stop heartbeating and detach the lifecycle observer.
  void stop() {
    if (!_started) return;
    _timer?.cancel();
    _timer = null;
    WidgetsBinding.instance.removeObserver(this);
    _started = false;
  }

  void _beginTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(_interval, (_) => _ping());
  }

  Future<void> _ping() async {
    try {
      final fcmToken = FirebaseMessagingService().currentToken;
      await ApiService().heartbeat(fcmToken: fcmToken);
    } catch (e) {
      if (kDebugMode) print('Heartbeat failed: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _beginTimer();
        _ping();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _timer?.cancel();
        _timer = null;
        break;
      case AppLifecycleState.inactive:
        // Transient state during transitions — ignore.
        break;
    }
  }
}
