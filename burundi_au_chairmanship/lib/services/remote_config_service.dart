import 'package:flutter/foundation.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';

/// Firebase Remote Config — only the app-version keys the app actually reads.
class RemoteConfigService {
  final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;

  /// The first fetchAndActivate, shared so callers (e.g. the force-update
  /// check) can await it instead of reading defaults before it lands.
  static Future<void>? _fetch;

  /// Initialize Remote Config with default values and fetch settings.
  /// Should be called during app startup.
  Future<void> initialize() async {
    try {
      await _remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(hours: 1),
      ));
      await _remoteConfig.setDefaults({
        'min_app_version': '1.0.0',
        'latest_app_version': '1.0.0',
      });
      await ensureFetched();
      if (kDebugMode) print('Remote Config initialized successfully');
    } catch (e) {
      if (kDebugMode) print('Failed to initialize Remote Config: $e');
      // Continue with default values if fetch fails
    }
  }

  /// Completes once the first fetchAndActivate has finished (or failed).
  Future<void> ensureFetched() {
    return _fetch ??= _remoteConfig.fetchAndActivate().then((_) {}).catchError((e) {
      if (kDebugMode) print('Remote Config fetch failed: $e');
    });
  }

  /// Minimum required app version (force update threshold)
  String get minAppVersion => getString('min_app_version');

  /// Latest available app version (optional update threshold)
  String get latestAppVersion => getString('latest_app_version');

  bool getBool(String key) {
    try {
      return _remoteConfig.getBool(key);
    } catch (e) {
      if (kDebugMode) print('Error getting bool for key $key: $e');
      return false;
    }
  }

  String getString(String key) {
    try {
      return _remoteConfig.getString(key);
    } catch (e) {
      if (kDebugMode) print('Error getting string for key $key: $e');
      return '';
    }
  }
}
