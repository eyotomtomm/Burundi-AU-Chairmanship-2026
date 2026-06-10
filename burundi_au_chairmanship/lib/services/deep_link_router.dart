import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:url_launcher/url_launcher.dart';
import '../main.dart' show navigatorKey;
import 'api_service.dart';
import '../screens/news/article_detail_screen.dart';
import '../screens/events/event_detail_screen.dart';

/// Central deep link router — all navigation-from-message-sources funnel
/// through [navigate] so that push notifications, in-app messages, popups,
/// and OS deep links share identical routing logic.
class DeepLinkRouter {
  static final DeepLinkRouter _instance = DeepLinkRouter._internal();
  factory DeepLinkRouter() => _instance;
  DeepLinkRouter._internal();

  /// Custom URL scheme used by FIAM action buttons and OS deep links.
  static const String scheme = 'b4africa';

  /// Fallback map: notification `type` → named route.
  /// Shared by push notification handlers so the mapping lives in one place.
  static const Map<String, String> notificationTypeRoutes = {
    'article': '/news',
    'magazine': '/magazine',
    'event': '/events',
    'gallery': '/gallery',
    'video': '/videos',
  };

  /// All named routes registered in [MaterialApp.onGenerateRoute].
  static const Set<String> _knownRoutes = {
    '/',
    '/auth',
    '/home',
    '/live-feeds',
    '/resources',
    '/calendar',
    '/news',
    '/magazine',
    '/translate',
    '/weather',
    '/profile',
    '/profile-completion',
    '/email-verification',
    '/water-sanitation',
    '/arise-initiative',
    '/peace-security',
    '/gallery',
    '/videos',
    '/social-media',
    '/notifications',
    '/support-tickets',
    '/ticket-conversation',
    '/contact-support',
    '/verification-request',
    '/trending',
    '/events',
    '/youth-dialogue',
    '/youth-dialogue-apply',
    '/youth-dialogue-documents',
    '/youth-dialogue-credential',
  };

  /// Navigate to the destination described by [url].
  ///
  /// Supported formats:
  /// - Internal path: `/news`, `/events`, `/profile-completion`
  /// - Parameterised path: `/news/123`, `/events/42`
  /// - Custom scheme: `b4africa://events`, `b4africa://news/123`
  /// - HTTPS to our domain: `https://burundi4africa.com/news`
  /// - External URL: opens in browser via url_launcher
  Future<void> navigate(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;

    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      if (kDebugMode) print('DeepLinkRouter: navigator not available');
      return;
    }

    // Parse the URI
    final uri = Uri.tryParse(trimmed);
    if (uri == null) {
      if (kDebugMode) print('DeepLinkRouter: invalid URI: $trimmed');
      return;
    }

    String path;

    if (trimmed.startsWith('/')) {
      // Plain internal path: /news, /news/123
      path = trimmed;
    } else if (uri.scheme == scheme) {
      // Custom scheme: b4africa://events or b4africa://news/123
      // host + path gives us the full route
      path = '/${uri.host}${uri.path}';
      // Normalise double slashes from b4africa:///events
      path = path.replaceAll('//', '/');
    } else if ((uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.contains('burundi4africa.com')) {
      // Our domain — treat the path as an internal route
      path = uri.path.isEmpty ? '/home' : uri.path;
    } else if (uri.scheme == 'http' || uri.scheme == 'https') {
      // External URL — open in browser
      await _openExternal(uri);
      return;
    } else {
      if (kDebugMode) print('DeepLinkRouter: unsupported scheme: ${uri.scheme}');
      return;
    }

    // Ensure leading slash
    if (!path.startsWith('/')) path = '/$path';

    // Try parameterised routes first: /news/123, /events/42
    final segments = path.split('/').where((s) => s.isNotEmpty).toList();
    if (segments.length == 2) {
      final section = segments[0]; // e.g. "news"
      final id = segments[1]; // e.g. "123"

      final handled = await _navigateToDetail(navigator, section, id);
      if (handled) return;
    }

    // Simple named route
    final basePath = '/${segments.isNotEmpty ? segments[0] : 'home'}';
    if (_knownRoutes.contains(path)) {
      navigator.pushNamed(path);
    } else if (_knownRoutes.contains(basePath)) {
      navigator.pushNamed(basePath);
    } else {
      if (kDebugMode) print('DeepLinkRouter: unknown route $path, going home');
      navigator.pushNamed('/home');
    }
  }

  /// Navigate from a push notification type + optional ID.
  /// Falls back to the list screen if the type is known, or /notifications.
  void navigateForNotificationType(String? type, {String? id}) {
    if (type != null && id != null && id.isNotEmpty) {
      navigate('/$type/$id');
      return;
    }
    final route = notificationTypeRoutes[type] ?? '/notifications';
    navigate(route);
  }

  /// Attempt to push a detail screen for [section]/[id].
  /// Returns `true` if handled, `false` otherwise.
  Future<bool> _navigateToDetail(
    NavigatorState navigator,
    String section,
    String id,
  ) async {
    try {
      switch (section) {
        case 'news':
        case 'article':
        case 'articles':
          final article = await ApiService().getArticle(id);
          navigator.push(
            CupertinoPageRoute(builder: (_) => ArticleDetailScreen(article: article)),
          );
          return true;

        case 'events':
        case 'event':
          final eventId = int.tryParse(id);
          if (eventId == null) return false;
          final event = await ApiService().getEventRegistration(eventId);
          navigator.push(
            CupertinoPageRoute(builder: (_) => EventDetailScreen(event: event)),
          );
          return true;

        default:
          return false;
      }
    } catch (e) {
      if (kDebugMode) print('DeepLinkRouter: failed to load detail for $section/$id: $e');
      // Fall through to list screen
      return false;
    }
  }

  Future<void> _openExternal(Uri uri) async {
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (kDebugMode) print('DeepLinkRouter: failed to open external URL: $e');
    }
  }
}
