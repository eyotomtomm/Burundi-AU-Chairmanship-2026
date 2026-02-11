import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Privacy-friendly analytics service
///
/// This service tracks basic app usage WITHOUT:
/// - Collecting personally identifiable information
/// - Sending data to third parties
/// - Tracking users across apps
/// - Requiring additional permissions
///
/// All data is stored locally and anonymously.
/// Users can clear analytics data anytime.
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  static const String _analyticsKey = 'app_analytics';
  static const String _sessionKey = 'analytics_session';

  bool _initialized = false;
  Map<String, dynamic> _analytics = {};
  int _sessionCount = 0;

  /// Initialize analytics service
  Future<void> init() async {
    if (_initialized) return;

    final prefs = await SharedPreferences.getInstance();

    // Load existing analytics
    final analyticsJson = prefs.getString(_analyticsKey);
    if (analyticsJson != null) {
      try {
        _analytics = json.decode(analyticsJson) as Map<String, dynamic>;
      } catch (_) {
        _analytics = _createEmptyAnalytics();
      }
    } else {
      _analytics = _createEmptyAnalytics();
    }

    // Increment session count
    _sessionCount = prefs.getInt(_sessionKey) ?? 0;
    _sessionCount++;
    await prefs.setInt(_sessionKey, _sessionCount);

    _initialized = true;
  }

  /// Create empty analytics structure
  Map<String, dynamic> _createEmptyAnalytics() {
    return {
      'app_launches': 0,
      'screens_visited': <String, int>{},
      'features_used': <String, int>{},
      'last_session': DateTime.now().toIso8601String(),
      'version': '1.0.0',
    };
  }

  /// Save analytics to local storage
  Future<void> _save() async {
    if (!_initialized) return;

    final prefs = await SharedPreferences.getInstance();
    final analyticsJson = json.encode(_analytics);
    await prefs.setString(_analyticsKey, analyticsJson);
  }

  /// Log app launch
  Future<void> logAppLaunch() async {
    if (!_initialized) await init();

    _analytics['app_launches'] = (_analytics['app_launches'] as int? ?? 0) + 1;
    _analytics['last_session'] = DateTime.now().toIso8601String();

    await _save();
  }

  /// Log screen view
  ///
  /// Example: logScreen('Home')
  Future<void> logScreen(String screenName) async {
    if (!_initialized) await init();

    final screens = _analytics['screens_visited'] as Map<String, dynamic>? ?? {};
    screens[screenName] = (screens[screenName] as int? ?? 0) + 1;
    _analytics['screens_visited'] = screens;

    await _save();
  }

  /// Log feature usage
  ///
  /// Example: logFeature('live_feeds_watched')
  Future<void> logFeature(String featureName) async {
    if (!_initialized) await init();

    final features = _analytics['features_used'] as Map<String, dynamic>? ?? {};
    features[featureName] = (features[featureName] as int? ?? 0) + 1;
    _analytics['features_used'] = features;

    await _save();
  }

  /// Get analytics summary
  Future<Map<String, dynamic>> getAnalyticsSummary() async {
    if (!_initialized) await init();

    return {
      'total_app_launches': _analytics['app_launches'] ?? 0,
      'current_session': _sessionCount,
      'last_session': _analytics['last_session'] ?? 'Never',
      'screens_visited': _analytics['screens_visited'] ?? {},
      'features_used': _analytics['features_used'] ?? {},
      'version': _analytics['version'] ?? '1.0.0',
    };
  }

  /// Get most visited screen
  String getMostVisitedScreen() {
    final screens = _analytics['screens_visited'] as Map<String, dynamic>? ?? {};
    if (screens.isEmpty) return 'None';

    String mostVisited = '';
    int maxVisits = 0;

    screens.forEach((screen, count) {
      if (count is int && count > maxVisits) {
        maxVisits = count;
        mostVisited = screen;
      }
    });

    return mostVisited.isEmpty ? 'None' : mostVisited;
  }

  /// Get most used feature
  String getMostUsedFeature() {
    final features = _analytics['features_used'] as Map<String, dynamic>? ?? {};
    if (features.isEmpty) return 'None';

    String mostUsed = '';
    int maxUses = 0;

    features.forEach((feature, count) {
      if (count is int && count > maxUses) {
        maxUses = count;
        mostUsed = feature;
      }
    });

    return mostUsed.isEmpty ? 'None' : mostUsed;
  }

  /// Clear all analytics data
  /// Allows users to delete their usage data
  Future<void> clearAnalytics() async {
    _analytics = _createEmptyAnalytics();
    _sessionCount = 0;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_analyticsKey);
    await prefs.remove(_sessionKey);
  }

  /// Check if analytics is enabled
  /// In this privacy-friendly version, analytics is always local and enabled
  /// No third-party services are used
  bool get isEnabled => true;

  /// Get total sessions
  int get totalSessions => _sessionCount;
}

/// Common screen names for consistency
class AnalyticsScreens {
  static const String home = 'Home';
  static const String magazine = 'Magazine';
  static const String consular = 'Consular';
  static const String locations = 'Locations';
  static const String more = 'More';
  static const String auth = 'Authentication';
  static const String emergency = 'Emergency';
  static const String liveFeeds = 'Live Feeds';
  static const String resources = 'Resources';
  static const String calendar = 'Calendar';
  static const String news = 'News';
  static const String translate = 'Translate';
  static const String weather = 'Weather';
}

/// Common feature names for consistency
class AnalyticsFeatures {
  static const String signIn = 'sign_in';
  static const String signUp = 'sign_up';
  static const String signOut = 'sign_out';
  static const String skipAuth = 'skip_auth';
  static const String deleteAccount = 'delete_account';
  static const String exportData = 'export_data';
  static const String watchLiveFeed = 'watch_live_feed';
  static const String viewMagazine = 'view_magazine';
  static const String readArticle = 'read_article';
  static const String viewEmbassy = 'view_embassy';
  static const String getDirections = 'get_directions';
  static const String callEmergency = 'call_emergency';
  static const String downloadResource = 'download_resource';
  static const String shareApp = 'share_app';
  static const String rateApp = 'rate_app';
  static const String contactSupport = 'contact_support';
  static const String switchLanguage = 'switch_language';
  static const String switchTheme = 'switch_theme';
}
