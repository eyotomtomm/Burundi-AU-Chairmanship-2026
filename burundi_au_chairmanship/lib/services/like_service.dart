import 'dart:async';
import 'package:flutter/foundation.dart';
import '../widgets/liked_by_avatars.dart';
import 'api_service.dart';
import 'haptic_service.dart';

enum EntityType { article, magazine, gallery, video, livefeed, discussion, event }

class LikeState {
  final bool isLiked;
  final int likeCount;
  final List<Liker> recentLikers;

  const LikeState({
    this.isLiked = false,
    this.likeCount = 0,
    this.recentLikers = const [],
  });

  LikeState copyWith({bool? isLiked, int? likeCount, List<Liker>? recentLikers}) {
    return LikeState(
      isLiked: isLiked ?? this.isLiked,
      likeCount: likeCount ?? this.likeCount,
      recentLikers: recentLikers ?? this.recentLikers,
    );
  }
}

typedef LikeListener = void Function(String key, LikeState state);

class LikeService {
  LikeService._();
  static final LikeService _instance = LikeService._();
  factory LikeService() => _instance;

  final Map<String, LikeState> _cache = {};
  final Map<String, Timer> _debounceTimers = {};
  final Map<String, bool> _pendingApiState = {}; // target isLiked to send
  final List<LikeListener> _listeners = [];

  String _key(EntityType type, dynamic id) => '${type.name}:$id';

  /// Seed the cache from widget data. Won't overwrite if already cached.
  void seed(EntityType type, dynamic id, {
    required bool isLiked,
    required int likeCount,
    List<Liker> recentLikers = const [],
  }) {
    final key = _key(type, id);
    if (_cache.containsKey(key)) return;
    _cache[key] = LikeState(
      isLiked: isLiked,
      likeCount: likeCount,
      recentLikers: recentLikers,
    );
  }

  /// Read current cached state. Returns default if not seeded.
  LikeState getState(EntityType type, dynamic id) {
    return _cache[_key(type, id)] ?? const LikeState();
  }

  /// Toggle like: instant optimistic update + debounced API call.
  void toggle(EntityType type, dynamic id) {
    final key = _key(type, id);
    final current = _cache[key] ?? const LikeState();
    final newLiked = !current.isLiked;
    final newCount = current.likeCount + (newLiked ? 1 : -1);

    HapticService.light();

    _cache[key] = current.copyWith(isLiked: newLiked, likeCount: newCount < 0 ? 0 : newCount);
    _notify(key);

    // Debounce the API call
    _debounceTimers[key]?.cancel();
    _pendingApiState[key] = newLiked;

    _debounceTimers[key] = Timer(const Duration(milliseconds: 300), () {
      _sendApiCall(type, id, key);
    });
  }

  Future<void> _sendApiCall(EntityType type, dynamic id, String key) async {
    final targetLiked = _pendingApiState.remove(key);
    if (targetLiked == null) return;

    // If current cache state already differs from what we want to send,
    // that means user toggled again — the next timer will handle it.
    final current = _cache[key];
    if (current != null && current.isLiked != targetLiked) return;

    try {
      final result = await _callApi(type, id);
      if (result == null) return;

      List<Liker> likers = [];
      if (result['recent_likers'] is List) {
        likers = (result['recent_likers'] as List)
            .map((l) => Liker.fromJson(l as Map<String, dynamic>))
            .toList();
      }

      _cache[key] = LikeState(
        isLiked: result['is_liked'] == true,
        likeCount: result['like_count'] ?? _cache[key]?.likeCount ?? 0,
        recentLikers: likers.isNotEmpty ? likers : (_cache[key]?.recentLikers ?? []),
      );
      _notify(key);
    } catch (e) {
      if (kDebugMode) debugPrint('LikeService API error: $e');
      // Don't revert — the optimistic state is fine for UX.
      // Next time the screen opens, seed() will get fresh data from the server.
    }
  }

  Future<Map<String, dynamic>?> _callApi(EntityType type, dynamic id) async {
    final api = ApiService();
    switch (type) {
      case EntityType.article:
        return api.toggleArticleLike(id.toString());
      case EntityType.magazine:
        return api.toggleMagazineLike(id.toString());
      case EntityType.gallery:
        return api.toggleGalleryAlbumLike(id.toString());
      case EntityType.video:
        return api.toggleVideoLike(id.toString());
      case EntityType.livefeed:
        return api.toggleLiveFeedLike(id is int ? id : int.parse(id.toString()));
      case EntityType.discussion:
        return api.toggleDiscussionLike(id is int ? id : int.parse(id.toString()));
      case EntityType.event:
        return api.toggleEventLike(id is int ? id : int.parse(id.toString()));
    }
  }

  /// Register a listener. Returns a removal function.
  VoidCallback addListener(LikeListener listener) {
    _listeners.add(listener);
    return () => _listeners.remove(listener);
  }

  void _notify(String key) {
    final state = _cache[key];
    if (state == null) return;
    for (final listener in List.of(_listeners)) {
      listener(key, state);
    }
  }

  /// Clear all cached state (call on logout).
  void clearAll() {
    for (final timer in _debounceTimers.values) {
      timer.cancel();
    }
    _debounceTimers.clear();
    _pendingApiState.clear();
    _cache.clear();
  }
}
