import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'deep_link_router.dart';

/// Listens for incoming deep links (cold-start and runtime) and routes them
/// through [DeepLinkRouter].
///
/// FIAM action buttons fire `b4africa://` URIs which the OS delivers here.
class AppLinkService {
  static final AppLinkService _instance = AppLinkService._internal();
  factory AppLinkService() => _instance;
  AppLinkService._internal();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;
  bool _initialized = false;

  /// The link the app was launched with, held until the app has finished
  /// starting up. Routing it immediately would race SplashScreen's
  /// `pushReplacementNamed('/home')` and the destination could be replaced
  /// out from under the user.
  Uri? _pendingInitialLink;

  /// Call once during app startup (fire-and-forget).
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // 1. Handle the link that launched the app (cold start)
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        if (kDebugMode) print('AppLinkService: cold-start link held: $initialUri');
        _pendingInitialLink = initialUri;
      }
    } catch (e) {
      if (kDebugMode) print('AppLinkService: failed to get initial link: $e');
    }

    // 2. Listen for links while the app is running
    _sub = _appLinks.uriLinkStream.listen(
      (uri) {
        if (kDebugMode) print('AppLinkService: runtime link: $uri');
        DeepLinkRouter().navigate(uri.toString());
      },
      onError: (e) {
        if (kDebugMode) print('AppLinkService: link stream error: $e');
      },
    );
  }

  /// Route the launch link, if any. Called once the app has reached its first
  /// real screen so the deep link lands on top of it instead of the splash.
  void flushPendingLink() {
    final uri = _pendingInitialLink;
    if (uri == null) return;
    _pendingInitialLink = null;
    if (kDebugMode) print('AppLinkService: routing held cold-start link: $uri');
    DeepLinkRouter().navigate(uri.toString());
  }

  /// Cancel the stream subscription (e.g. in tests).
  void dispose() {
    _sub?.cancel();
    _sub = null;
    _pendingInitialLink = null;
    _initialized = false;
  }
}
