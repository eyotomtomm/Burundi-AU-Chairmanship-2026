import 'package:shared_preferences/shared_preferences.dart';

/// Reduces bandwidth usage by shrinking decoded image sizes
/// and increasing polling intervals.
class DataSaverService {
  static final DataSaverService _instance = DataSaverService._();
  factory DataSaverService() => _instance;
  DataSaverService._();

  static const String _prefKey = 'data_saver_enabled';

  bool _enabled = false;
  bool get enabled => _enabled;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_prefKey) ?? false;
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, value);
  }

  /// Decode width for list thumbnails (cards, grid items).
  int get thumbnailCacheWidth => _enabled ? 300 : 600;

  /// Decode width for hero / carousel images.
  int get heroCacheWidth => _enabled ? 600 : 1200;

  /// Decode width for full-screen / detail images (null = native size).
  int? get fullImageCacheWidth => _enabled ? 800 : null;

  /// Multiplier for polling intervals. 1× normal, 3× in data-saver mode.
  int get pollingMultiplier => _enabled ? 3 : 1;
}
