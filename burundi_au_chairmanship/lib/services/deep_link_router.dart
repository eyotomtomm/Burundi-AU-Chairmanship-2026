import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:url_launcher/url_launcher.dart';
import '../main.dart' show navigatorKey;
import 'api_service.dart';
import '../screens/news/article_detail_screen.dart';
import '../screens/events/event_detail_screen.dart';
import '../screens/magazine/magazine_detail_screen.dart';
import '../screens/facts/fact_detail_screen.dart';
import '../screens/videos/video_detail_screen.dart';
import '../screens/gallery/album_detail_screen.dart';
import '../screens/discussions/discussion_detail_screen.dart';
import '../screens/feature_card/feature_card_detail_screen.dart';

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
    'discussion': '/discussions',
  };

  /// Priority agendas ship as three fixed screens, keyed by their backend slug.
  static const Map<String, String> _agendaRoutes = {
    'water-sanitation': '/water-sanitation',
    'arise-initiative': '/arise-initiative',
    'peace-security': '/peace-security',
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
    '/priority-agenda',
    '/water-sanitation',
    '/arise-initiative',
    '/peace-security',
    '/gallery',
    '/discussions',
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
    // Share links look like /articles/12/share/ — drop the trailing marker.
    if (segments.length == 3 && segments.last == 'share') segments.removeLast();
    if (segments.length == 2) {
      final section = segments[0]; // e.g. "news"
      final id = segments[1]; // e.g. "123"

      // Validate ID: must be alphanumeric, max 64 chars, no path traversal
      final validId = RegExp(r'^[a-zA-Z0-9_-]{1,64}$').hasMatch(id);
      if (!validId) {
        if (kDebugMode) print('DeepLinkRouter: invalid id format: $id');
        return;
      }

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
            CupertinoPageRoute(builder: (_) => ArticleDetailScreen(article: article, scrollToComments: false)),
          );
          return true;

        case 'events':
        case 'event':
          final eventId = int.tryParse(id);
          if (eventId == null) return false;
          final event = await ApiService().getEventRegistration(eventId);
          navigator.push(
            CupertinoPageRoute(builder: (_) => EventDetailScreen(event: event, scrollToComments: false)),
          );
          return true;

        case 'magazines':
        case 'magazine':
          final magazines = await ApiService().getMagazines();
          final match = magazines.where((m) => m.id == id).toList();
          if (match.isEmpty) return false;
          navigator.push(
            CupertinoPageRoute(builder: (_) => MagazineDetailScreen(magazine: match.first)),
          );
          return true;

        case 'facts':
        case 'fact':
          final factId = int.tryParse(id);
          if (factId == null) return false;
          navigator.push(
            CupertinoPageRoute(builder: (_) => FactDetailScreen(factId: factId)),
          );
          return true;

        case 'gallery':
        case 'albums':
          final albums = await ApiService().getGalleryAlbums();
          final album = albums
              .where((a) => a['id']?.toString() == id)
              .toList();
          if (album.isEmpty) return false;
          navigator.push(
            CupertinoPageRoute(builder: (_) => AlbumDetailScreen(album: album.first)),
          );
          return true;

        case 'discussions':
        case 'discussion':
          final discussionId = int.tryParse(id);
          if (discussionId == null) return false;
          navigator.push(
            CupertinoPageRoute(
                builder: (_) => DiscussionDetailScreen(discussionId: discussionId)),
          );
          return true;

        case 'agendas':
        case 'agenda':
          final agendas = await ApiService().getPriorityAgendas();
          final match = agendas
              .where((a) => a['id']?.toString() == id)
              .toList();
          final route = match.isEmpty ? null : _agendaRoutes[match.first['slug']];
          if (route == null) return false;
          navigator.pushNamed(route);
          return true;

        case 'features':
        case 'feature':
          // Feature cards only ship inside the home feed payload.
          final feed = await ApiService().getHomeFeed();
          final cards = (feed['feature_cards'] as List<dynamic>? ?? [])
              .cast<Map<String, dynamic>>()
              .where((c) => c['id']?.toString() == id)
              .toList();
          if (cards.isEmpty) return false;
          navigator.push(
            CupertinoPageRoute(
                builder: (_) => FeatureCardDetailScreen(cardData: cards.first)),
          );
          return true;

        case 'videos':
        case 'video':
          final videos = await ApiService().getVideos();
          final match = videos.where((v) => v['id']?.toString() == id).toList();
          if (match.isEmpty) return false;
          navigator.push(
            CupertinoPageRoute(builder: (_) => VideoDetailScreen(video: match.first, scrollToComments: false)),
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
