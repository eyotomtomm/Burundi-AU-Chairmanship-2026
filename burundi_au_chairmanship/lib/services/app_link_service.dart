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

  /// Call once during app startup (fire-and-forget).
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // 1. Handle the link that launched the app (cold start)
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        if (kDebugMode) print('AppLinkService: cold-start link: $initialUri');
        DeepLinkRouter().navigate(initialUri.toString());
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

  /// Cancel the stream subscription (e.g. in tests).
  void dispose() {
    _sub?.cancel();
    _sub = null;
    _initialized = false;
  }
}
