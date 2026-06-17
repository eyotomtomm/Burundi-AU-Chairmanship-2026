import 'dart:async';
import 'api_service.dart';

/// Data class holding the four preloaded API results from the home feed.
class PreloadedHomeData {
  final Map<String, dynamic> homeFeed;
  final List<Map<String, dynamic>> priorityAgendas;
  final List<Map<String, dynamic>> heroTextContent;
  final List<Map<String, dynamic>> quickAccessMenu;

  const PreloadedHomeData({
    required this.homeFeed,
    required this.priorityAgendas,
    required this.heroTextContent,
    required this.quickAccessMenu,
  });
}

/// Singleton that fires home-feed API calls during the splash screen
/// so HomeTab can consume the results immediately without re-fetching.
class SplashPreloader {
  SplashPreloader._();
  static final SplashPreloader instance = SplashPreloader._();

  Completer<PreloadedHomeData?>? _completer;
  PreloadedHomeData? _data;

  /// Kick off all four home-feed requests in parallel.
  /// Safe to call multiple times — subsequent calls are no-ops while loading.
  void startPreload() {
    if (_completer != null) return; // already in-flight
    _completer = Completer<PreloadedHomeData?>();

    _doPreload().then((data) {
      _data = data;
      if (!_completer!.isCompleted) _completer!.complete(data);
    }).catchError((e) {
      if (!_completer!.isCompleted) _completer!.complete(null);
    });
  }

  Future<PreloadedHomeData?> _doPreload() async {
    final api = ApiService();
    final results = await Future.wait([
      api.getHomeFeed(),
      api.getPriorityAgendas().catchError((_) => <Map<String, dynamic>>[]),
      api.getHeroTextContent().catchError((_) => <Map<String, dynamic>>[]),
      api.getQuickAccessMenu().catchError((_) => <Map<String, dynamic>>[]),
    ]);

    return PreloadedHomeData(
      homeFeed: results[0] as Map<String, dynamic>,
      priorityAgendas: results[1] as List<Map<String, dynamic>>,
      heroTextContent: results[2] as List<Map<String, dynamic>>,
      quickAccessMenu: results[3] as List<Map<String, dynamic>>,
    );
  }

  /// Await the home-feed Completer with an optional timeout.
  /// Returns null if preload was never started, failed, or timed out.
  Future<PreloadedHomeData?> waitForCriticalData(Duration timeout) async {
    if (_completer == null) return null;
    try {
      return await _completer!.future.timeout(timeout);
    } catch (_) {
      return _data; // return whatever we have, even if partial
    }
  }

  /// Return preloaded data once, then reset so subsequent calls (e.g.
  /// pull-to-refresh, re-navigation) fall through to the normal network path.
  PreloadedHomeData? consume() {
    final data = _data;
    _data = null;
    _completer = null;
    return data;
  }
}
