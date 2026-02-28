import 'package:firebase_remote_config/firebase_remote_config.dart';

/// Service for Firebase Remote Config
///
/// Allows dynamic configuration and feature flags without app updates.
/// Use cases:
/// - Feature flags (enable/disable features)
/// - Maintenance mode banners
/// - API endpoint configuration
/// - App version requirements
class RemoteConfigService {
  final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;

  /// Initialize Remote Config with default values and fetch settings
  ///
  /// Should be called during app startup
  Future<void> initialize() async {
    try {
      // Configure settings
      await _remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(hours: 1),
      ));

      // Set default values (used when fetch fails or values not set in console)
      await _remoteConfig.setDefaults({
        'enable_live_feeds': true,
        'enable_magazines': true,
        'enable_events': true,
        'enable_embassies': true,
        'show_maintenance_banner': false,
        'maintenance_message': '',
        'min_app_version': '1.0.0',
        'force_update': false,
        // API URL defaults to production HTTPS
        'api_base_url': 'https://api.burundi4africa.com/api',
        'enable_analytics': true,
        'enable_crashlytics': true,
        'cache_duration_hours': 24,
      });

      // Fetch and activate remote config
      await _remoteConfig.fetchAndActivate();
      print('Remote Config initialized successfully');
    } catch (e) {
      print('Failed to initialize Remote Config: $e');
      // Continue with default values if fetch fails
    }
  }

  /// Force fetch new values from Remote Config
  ///
  /// Useful for debugging or when you need fresh values immediately
  Future<void> forceFetch() async {
    try {
      await _remoteConfig.fetchAndActivate();
      print('Remote Config force fetched');
    } catch (e) {
      print('Failed to force fetch Remote Config: $e');
    }
  }

  // ─── Feature Flags ────────────────────────────────────────────

  /// Check if live feeds feature is enabled
  bool get isLiveFeedsEnabled => getBool('enable_live_feeds');

  /// Check if magazines feature is enabled
  bool get isMagazinesEnabled => getBool('enable_magazines');

  /// Check if events feature is enabled
  bool get isEventsEnabled => getBool('enable_events');

  /// Check if embassies feature is enabled
  bool get isEmbassiesEnabled => getBool('enable_embassies');

  /// Check if analytics tracking is enabled
  bool get isAnalyticsEnabled => getBool('enable_analytics');

  /// Check if Crashlytics reporting is enabled
  bool get isCrashlyticsEnabled => getBool('enable_crashlytics');

  // ─── Maintenance Mode ─────────────────────────────────────────

  /// Check if maintenance banner should be shown
  bool get showMaintenanceBanner => getBool('show_maintenance_banner');

  /// Get maintenance message to display
  String get maintenanceMessage => getString('maintenance_message');

  // ─── App Version Control ──────────────────────────────────────

  /// Get minimum required app version
  String get minAppVersion => getString('min_app_version');

  /// Check if force update is required
  bool get forceUpdate => getBool('force_update');

  // ─── Configuration ────────────────────────────────────────────

  /// Get API base URL (for switching between dev/staging/prod)
  String get apiBaseUrl => getString('api_base_url');

  /// Get cache duration in hours
  int get cacheDurationHours => getInt('cache_duration_hours');

  // ─── Generic Getters ──────────────────────────────────────────

  /// Get a boolean value from Remote Config
  bool getBool(String key) {
    try {
      return _remoteConfig.getBool(key);
    } catch (e) {
      print('Error getting bool for key $key: $e');
      return false;
    }
  }

  /// Get a string value from Remote Config
  String getString(String key) {
    try {
      return _remoteConfig.getString(key);
    } catch (e) {
      print('Error getting string for key $key: $e');
      return '';
    }
  }

  /// Get an integer value from Remote Config
  int getInt(String key) {
    try {
      return _remoteConfig.getInt(key);
    } catch (e) {
      print('Error getting int for key $key: $e');
      return 0;
    }
  }

  /// Get a double value from Remote Config
  double getDouble(String key) {
    try {
      return _remoteConfig.getDouble(key);
    } catch (e) {
      print('Error getting double for key $key: $e');
      return 0.0;
    }
  }

  /// Get all Remote Config values as a map
  Map<String, dynamic> getAllValues() {
    final keys = _remoteConfig.getAll().keys;
    return {
      for (var key in keys)
        key: _remoteConfig.getValue(key).asString(),
    };
  }
}
