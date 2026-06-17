import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/magazine_model.dart';
import '../models/api_models.dart';
import '../models/event_registration_model.dart';

/// Hive-backed offline cache for API content.
///
/// Two boxes:
/// - `content_cache`   — JSON strings keyed by content type
/// - `cache_timestamps` — epoch-ms per key for staleness checks
///
/// Stale (15 min): show cached, trigger background refresh.
/// Expired (24 h): don't show; force fresh fetch.
class ContentCacheService {
  static final ContentCacheService _instance = ContentCacheService._();
  factory ContentCacheService() => _instance;
  ContentCacheService._();

  static const String _cacheBoxName = 'content_cache';
  static const String _timestampBoxName = 'cache_timestamps';

  static const Duration staleDuration = Duration(minutes: 15);
  static const Duration expireDuration = Duration(hours: 24);

  // Cache keys
  static const String keyHomeFeed = 'home_feed';
  static const String keyArticles = 'articles';
  static const String keyNews = 'news';
  static const String keyMagazines = 'magazines';
  static const String keyEvents = 'events';
  static const String keyGallery = 'gallery';
  static const String keyHeroSlides = 'hero_slides';

  late Box<String> _cacheBox;
  late Box<int> _timestampBox;

  Future<void> init() async {
    _cacheBox = await Hive.openBox<String>(_cacheBoxName);
    _timestampBox = await Hive.openBox<int>(_timestampBoxName);
  }

  // ─── Staleness helpers ───────────────────────────────────────

  bool _hasKey(String key) => _cacheBox.containsKey(key);

  DateTime? _timestampFor(String key) {
    final ms = _timestampBox.get(key);
    return ms != null ? DateTime.fromMillisecondsSinceEpoch(ms) : null;
  }

  bool isStale(String key) {
    final ts = _timestampFor(key);
    if (ts == null) return true;
    return DateTime.now().difference(ts) > staleDuration;
  }

  bool isExpired(String key) {
    final ts = _timestampFor(key);
    if (ts == null) return true;
    return DateTime.now().difference(ts) > expireDuration;
  }

  // ─── Raw read / write ────────────────────────────────────────

  void _put(String key, String jsonString) {
    _cacheBox.put(key, jsonString);
    _timestampBox.put(key, DateTime.now().millisecondsSinceEpoch);
  }

  String? _get(String key) {
    if (!_hasKey(key)) return null;
    if (isExpired(key)) {
      _cacheBox.delete(key);
      _timestampBox.delete(key);
      return null;
    }
    return _cacheBox.get(key);
  }

  // ─── Articles (shared for articles & news) ───────────────────

  void cacheArticles(String key, List<Article> articles) {
    final json = jsonEncode(articles.map((a) => a.toJson()).toList());
    _put(key, json);
  }

  List<Article>? getArticles(String key) {
    final raw = _get(key);
    if (raw == null) return null;
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((j) => Article.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  // ─── Magazines ───────────────────────────────────────────────

  void cacheMagazines(List<MagazineEdition> magazines) {
    final json = jsonEncode(magazines.map((m) => m.toJson()).toList());
    _put(keyMagazines, json);
  }

  List<MagazineEdition>? getMagazines() {
    final raw = _get(keyMagazines);
    if (raw == null) return null;
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((j) => MagazineEdition.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  // ─── Events ──────────────────────────────────────────────────

  void cacheEvents(List<EventRegistrationModel> events) {
    final json = jsonEncode(events.map((e) => e.toJson()).toList());
    _put(keyEvents, json);
  }

  List<EventRegistrationModel>? getEvents() {
    final raw = _get(keyEvents);
    if (raw == null) return null;
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((j) => EventRegistrationModel.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  // ─── Hero Slides ─────────────────────────────────────────────

  void cacheHeroSlides(List<HeroSlide> slides) {
    final json = jsonEncode(slides.map((s) => s.toJson()).toList());
    _put(keyHeroSlides, json);
  }

  List<HeroSlide>? getHeroSlides() {
    final raw = _get(keyHeroSlides);
    if (raw == null) return null;
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((j) => HeroSlide.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  // ─── Home Feed (raw JSON map) ────────────────────────────────

  void cacheHomeFeed(Map<String, dynamic> feed) {
    _put(keyHomeFeed, jsonEncode(feed));
  }

  Map<String, dynamic>? getHomeFeed() {
    final raw = _get(keyHomeFeed);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  // ─── Generic map list (gallery, etc.) ────────────────────────

  void cacheMapList(String key, List<Map<String, dynamic>> data) {
    _put(key, jsonEncode(data));
  }

  List<Map<String, dynamic>>? getMapList(String key) {
    final raw = _get(key);
    if (raw == null) return null;
    try {
      final list = jsonDecode(raw) as List;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return null;
    }
  }

  // ─── Cleanup ─────────────────────────────────────────────────

  Future<void> clearAll() async {
    await _cacheBox.clear();
    await _timestampBox.clear();
  }

  // ─── Migration from SharedPreferences ────────────────────────

  Future<void> migrateFromSharedPreferences() async {
    // Only migrate once — skip if we already have a home feed in Hive
    if (_hasKey(keyHomeFeed)) return;

    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('cached_home_feed');
    if (cached != null && cached.isNotEmpty) {
      _put(keyHomeFeed, cached);
      await prefs.remove('cached_home_feed');
    }
  }
}
