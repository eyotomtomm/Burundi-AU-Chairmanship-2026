import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';

/// Which articles the reader has already been through.
///
/// Kept locally so a list can mark items the moment they are opened, with no
/// round trip and no dependence on being signed in. For a signed-in reader the
/// set is seeded once from `reading-progress/read/`, so the marks follow them
/// to a new device.
class ReadService extends ChangeNotifier {
  ReadService._();
  static final ReadService instance = ReadService._();

  static const _key = 'read_article_ids';

  final Set<int> _read = <int>{};
  bool _loaded = false;

  Set<int> get readIds => Set.unmodifiable(_read);

  bool isRead(Object? articleId) {
    final id = _asInt(articleId);
    return id != null && _read.contains(id);
  }

  /// Load the local set, then merge anything the server knows about.
  Future<void> load({bool syncRemote = true}) async {
    if (!_loaded) {
      try {
        final prefs = await SharedPreferences.getInstance();
        _read.addAll((prefs.getStringList(_key) ?? [])
            .map(int.tryParse)
            .whereType<int>());
      } catch (_) {
        // A broken prefs store just means we start from nothing.
      }
      _loaded = true;
      notifyListeners();
    }
    if (syncRemote) await _mergeRemote();
  }

  Future<void> _mergeRemote() async {
    try {
      final ids = await ApiService().getReadArticleIds();
      if (ids.isEmpty) return;
      final before = _read.length;
      _read.addAll(ids);
      if (_read.length != before) {
        await _persist();
        notifyListeners();
      }
    } catch (_) {
      // Signed out, offline, or the endpoint is unavailable — the local set
      // still stands on its own.
    }
  }

  /// Mark one article read. Safe to call repeatedly.
  Future<void> markRead(Object? articleId) async {
    final id = _asInt(articleId);
    if (id == null || !_read.add(id)) return;
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, _read.map((e) => e.toString()).toList());
    } catch (_) {}
  }

  /// Signing out should not leave the next account looking at someone else's
  /// read marks.
  Future<void> clear() async {
    if (_read.isEmpty) return;
    _read.clear();
    notifyListeners();
    await _persist();
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }
}
