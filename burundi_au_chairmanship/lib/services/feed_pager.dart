import 'package:flutter/material.dart';

import 'api_service.dart';

/// Paging for any screen that lists the `discussions` feed.
///
/// The server pages at 20 and every one of these screens used to request page
/// one and stop, so the twenty-first post was unreachable. The page counter,
/// the "am I near the bottom" trigger and the guard flags are the same
/// everywhere, so they live here rather than in four copies.
class FeedPager extends ChangeNotifier {
  FeedPager(this.fetch);

  /// Fetches one page, 1-based.
  final Future<FeedPage> Function(int page) fetch;

  final ScrollController scroll = ScrollController();

  List<Map<String, dynamic>> posts = [];
  bool loading = true;
  bool loadingMore = false;
  bool hasMore = true;
  bool failed = false;
  int _page = 1;

  /// Pixels from the bottom at which the next page starts loading — about a
  /// card and a half, so the spinner rarely gets seen.
  static const double _triggerDistance = 600;

  bool _attached = false;

  void _ensureAttached() {
    if (_attached) return;
    _attached = true;
    scroll.addListener(_onScroll);
  }

  void _onScroll() {
    if (!scroll.hasClients || loadingMore || !hasMore || loading) return;
    if (scroll.position.pixels >= scroll.position.maxScrollExtent - _triggerDistance) {
      loadMore();
    }
  }

  /// Load (or reload) the first page.
  ///
  /// [quiet] refreshes in place instead of clearing to a loading state, which
  /// is what returning from a post should do — otherwise the list rebuilds and
  /// throws the reader back to the top.
  Future<void> load({bool quiet = false}) async {
    _ensureAttached();
    if (!quiet) {
      loading = true;
      notifyListeners();
    }
    try {
      final page = await fetch(1);
      posts = page.posts;
      hasMore = page.hasMore;
      failed = false;
      _page = 1;
    } catch (_) {
      if (!quiet) {
        posts = [];
        hasMore = false;
      }
      failed = true;
    }
    loading = false;
    notifyListeners();
  }

  Future<void> loadMore() async {
    if (loadingMore || !hasMore) return;
    loadingMore = true;
    notifyListeners();
    try {
      final next = await fetch(_page + 1);
      _page += 1;
      posts = [...posts, ...next.posts];
      hasMore = next.hasMore;
    } catch (_) {
      // Stop asking rather than retrying on every scroll frame; pull to
      // refresh starts over.
      hasMore = false;
    }
    loadingMore = false;
    notifyListeners();
  }

  /// Swap one post in place — a like or a repost does not need a refetch.
  void replace(Map<String, dynamic> updated) {
    final i = posts.indexWhere((p) => p['id'] == updated['id']);
    if (i < 0) return;
    posts[i] = updated;
    notifyListeners();
  }

  void remove(int id) {
    posts.removeWhere((p) => p['id'] == id);
    notifyListeners();
  }

  @override
  void dispose() {
    scroll.removeListener(_onScroll);
    scroll.dispose();
    super.dispose();
  }
}

/// The footer every paged feed shows: a spinner while more loads, and a full
/// stop once there is nothing left.
class FeedPagerFooter extends StatelessWidget {
  final FeedPager pager;
  final Color accent;
  final TextStyle? endStyle;

  const FeedPagerFooter(this.pager,
      {super.key, required this.accent, this.endStyle});

  @override
  Widget build(BuildContext context) {
    if (pager.loadingMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 22),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: accent),
          ),
        ),
      );
    }
    if (pager.hasMore || pager.posts.isEmpty) return const SizedBox(height: 8);
    final fr = Localizations.localeOf(context).languageCode == 'fr';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 22),
      child: Center(
        child: Text(
          fr ? 'Vous êtes à jour' : "You're all caught up",
          style: endStyle,
        ),
      ),
    );
  }
}
