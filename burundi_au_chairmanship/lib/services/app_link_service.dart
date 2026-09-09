import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'deep_link_router.dart';

/// Listens for incoming deep links (cold-start and runtime) and routes them
/// through [DeepLinkRouter].
///
/// FIAM action buttons fire `b4africa://` URIs which the OS delivers here.
///
/// This is the *only* deep-link handler. Flutter's built-in handling is turned
/// off — `FlutterDeepLinkingEnabled=false` in ios/Runner/Info.plist and
/// `flutter_deeplinking_enabled=false` in the Android manifest — because it
/// also receives every incoming URL and pushes the URI's path as a named
/// route. For `b4africa://magazine` that path is empty, so it pushed `/`, ran
/// SplashScreen a second time, and its `pushReplacementNamed('/home')` wiped
/// out the screen this router had just opened.
class AppLinkService {
  static final AppLinkService _instance = AppLinkService._internal();
  factory AppLinkService() => _instance;
  AppLinkService._internal();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;
  bool _initialized = false;

  /// Links held until the app has finished starting up. Routing one early
  /// races SplashScreen's `pushReplacementNamed('/home')`, which replaces the
  /// top route — so the destination is pushed and then silently swallowed.
  ///
  /// This applies to runtime links too, not just the cold-start one: the
  /// splash's bootstrap waits on a maintenance check that can take twenty
  /// seconds, and any link arriving inside that window was lost the same way.
  final List<Uri> _pending = [];

  /// Set once the app has reached its first real screen.
  bool _startupComplete = false;

  /// Call once during app startup (fire-and-forget).
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // 1. Handle the link that launched the app (cold start)
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        if (kDebugMode) print('AppLinkService: cold-start link held: $initialUri');
        _pending.add(initialUri);
      }
    } catch (e) {
      if (kDebugMode) print('AppLinkService: failed to get initial link: $e');
    }

    // 2. Listen for links while the app is running
    _sub = _appLinks.uriLinkStream.listen(
      (uri) {
        if (!_startupComplete) {
          if (kDebugMode) print('AppLinkService: runtime link held: $uri');
          _pending.add(uri);
          return;
        }
        if (kDebugMode) print('AppLinkService: runtime link: $uri');
        DeepLinkRouter().navigate(uri.toString());
      },
      onError: (e) {
        if (kDebugMode) print('AppLinkService: link stream error: $e');
      },
    );
  }

  /// Route any held links. Called once the app has reached its first real
  /// screen, so a deep link lands on top of it instead of being replaced by
  /// the startup navigation. Marks startup complete, after which runtime links
  /// route straight through.
  void flushPendingLink() {
    _startupComplete = true;
    if (_pending.isEmpty) return;
    final held = List<Uri>.from(_pending);
    _pending.clear();
    // Only the last one is worth honouring — earlier links in the same window
    // would each be replaced by the next anyway.
    final uri = held.last;
    if (kDebugMode) print('AppLinkService: routing held link: $uri');
    DeepLinkRouter().navigate(uri.toString());
  }

  /// Cancel the stream subscription (e.g. in tests).
  void dispose() {
    _sub?.cancel();
    _sub = null;
    _pending.clear();
    _startupComplete = false;
    _initialized = false;
  }
}
