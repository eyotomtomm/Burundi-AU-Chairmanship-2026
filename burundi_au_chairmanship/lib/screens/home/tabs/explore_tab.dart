import '../../../widgets/app_network_image.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../config/app_ds.dart';
import '../../../config/environment.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/api_service.dart';
import '../../../widgets/feed/post_card.dart';
import '../../../widgets/feed/post_composer.dart';
import '../../../widgets/feed/repost_sheet.dart';
import '../../../widgets/ds/ds_widgets.dart';
import '../../../widgets/shimmer_loading.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../discussions/discussion_detail_screen.dart';
import '../../feed/explore_notifications_screen.dart';
import '../../feed/explore_terms_screen.dart';
import '../../feed/tag_feed_screen.dart';
import '../../feed/user_profile_screen.dart';

/// The Explore tab: the social feed from `B4Africa Social Feed`.
///
/// Two feeds off one endpoint — Following narrows `discussions` to people the
/// viewer follows, For You is everything.
class ExploreTab extends StatefulWidget {
  /// Returns to the Home tab — Explore is a root tab, so its back arrow is a
  /// tab switch rather than a Navigator pop.
  final VoidCallback? onBackToHome;

  const ExploreTab({super.key, this.onBackToHome});

  @override
  State<ExploreTab> createState() => _ExploreTabState();
}

class _ExploreTabState extends State<ExploreTab> {
  final _api = ApiService();
  List<Map<String, dynamic>>? _posts;
  List<Map<String, dynamic>> _topics = [];
  List<Map<String, dynamic>> _tags = [];
  int _unread = 0;
  bool _loading = true;
  bool _following = false;

  // Topics advance on their own so more than the first one gets seen.
  final _topicsController = PageController(viewportFraction: 0.88);
  Timer? _topicsTimer;
  int _topicPage = 0;

  // The server pages at 20; without these the feed could never show a
  // twenty-first post.
  final _scroll = ScrollController();
  int _page = 1;
  bool _hasMore = true;
  bool _loadingMore = false;

  /// Set once, forever, the first time someone posts. Survives restarts.
  static const _thanksShownKey = 'explore_first_post_thanks_shown';

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load();
    _loadSideData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Explore lives in an IndexedStack, so it stays mounted while the user
    // reads another tab. TickerMode tells us whether we are the visible one;
    // without this the carousel animated on forever in the background.
    if (TickerMode.of(context)) {
      _startTopicsAutoSlide();
    } else {
      _topicsTimer?.cancel();
      _topicsTimer = null;
    }
  }

  @override
  void dispose() {
    _topicsTimer?.cancel();
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _topicsController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients || _loadingMore || !_hasMore || _loading) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 600) {
      _loadMore();
    }
  }

  void _startTopicsAutoSlide() {
    _topicsTimer?.cancel();
    if (_topics.length < 2 || !mounted || !TickerMode.of(context)) return;
    _topicsTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted || !_topicsController.hasClients || !TickerMode.of(context)) return;
      final next = (_topicPage + 1) % _topics.length;
      _topicsController.animateToPage(
        next,
        duration: const Duration(milliseconds: 550),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _loadSideData() async {
    try {
      _topics = await _api.getDiscussionTopics();
      _startTopicsAutoSlide();
    } catch (_) {}
    try {
      _tags = await _api.getTrendingTags();
    } catch (_) {}
    try {
      final notes = await _api.getExploreNotifications();
      _unread = notes['unread'] as int? ?? 0;
    } catch (_) {}
    if (mounted) setState(() {});
  }

  /// The Explore terms are a one-time gate, checked against the server rather
  /// than a local flag so a reinstall can't skip it.
  Future<bool> _ensureTermsAccepted() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      Navigator.pushNamed(context, '/auth');
      return false;
    }
    try {
      final state = await _api.getExploreTerms();
      if (state['accepted'] == true) return true;
      if (!mounted) return false;
      final accepted = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => ExploreTermsScreen(
            missingFields:
                (state['missing_fields'] as List?)?.cast<String>() ?? const [],
          ),
        ),
      );
      return accepted == true;
    } catch (_) {
      // Offline: let the server refuse the post itself rather than blocking.
      return true;
    }
  }

  /// Shown once in a user's lifetime, right after their first post.
  Future<void> _maybeThankThem() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_thanksShownKey) == true) return;
    await prefs.setBool(_thanksShownKey, true);
    if (!mounted) return;

    final fr = Localizations.localeOf(context).languageCode == 'fr';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Ds.greenDeep,
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(16, 0, 16, Ds.navSpace(context)),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Ds.rCard)),
        content: Row(
          children: [
            const Icon(Icons.celebration_rounded, color: Colors.white, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                fr
                    ? 'Merci — votre première publication est en ligne. Bienvenue dans le débat.'
                    : 'Thank you — your first post is live. Welcome to the debate.',
                style: const TextStyle(
                    fontSize: 14, height: 1.35, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _compose({
    String? pick,
    String? category,
    Map<String, dynamic>? topic,
  }) async {
    if (!await _ensureTermsAccepted()) return;
    if (!mounted) return;
    if (await PostComposer.open(context,
        pickOnOpen: pick, category: category, topic: topic)) {
      await _load();
      await _maybeThankThem();
    }
  }

  void _openTag(String tag) => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TagFeedScreen(tag: tag)),
      );

  void _openTopic(int topicId, String title) => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TagFeedScreen(topicId: topicId, topicTitle: title),
        ),
      ).then((_) => _loadSideData());

  /// Fetch the first page.
  ///
  /// [quiet] refreshes in place instead of replacing the list with a skeleton,
  /// which is what coming back from a post should do — the shimmer used to
  /// throw the reader back to the top of the feed every time.
  Future<void> _load({bool quiet = false}) async {
    if (!quiet) setState(() => _loading = true);
    try {
      final page = await _api.getFeedPage(following: _following);
      _posts = page.posts;
      _hasMore = page.hasMore;
      _page = 1;
    } catch (_) {
      if (!quiet) _posts = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final next = await _api.getFeedPage(following: _following, page: _page + 1);
      _page += 1;
      _posts = [...?_posts, ...next.posts];
      _hasMore = next.hasMore;
    } catch (_) {
      _hasMore = false;
    }
    if (mounted) setState(() => _loadingMore = false);
  }

  /// One post changed — swap it in place rather than refetching the feed.
  void _replacePost(Map<String, dynamic> updated) {
    final posts = _posts;
    if (posts == null) return;
    final i = posts.indexWhere((p) => p['id'] == updated['id']);
    if (i >= 0) setState(() => posts[i] = updated);
  }

  void _removePost(int id) {
    setState(() => _posts?.removeWhere((p) => p['id'] == id));
  }

  void _switchFeed(bool following) {
    if (_following == following) return;
    HapticFeedback.selectionClick();
    setState(() => _following = following);
    _load();
  }

  Future<void> _repost(Map<String, dynamic> post) async {
    if (await RepostSheet.open(context, post)) await _load(quiet: true);
  }

  void _openPost(Map<String, dynamic> post) => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DiscussionDetailScreen(discussionId: post['id'] as int),
        ),
      ).then((_) => _load(quiet: true));

  void _openAuthor(int userId) => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => UserProfileScreen(userId: userId)),
      ).then((_) => _load(quiet: true));

  @override
  Widget build(BuildContext context) {
    final langCode = Localizations.localeOf(context).languageCode;
    final fr = langCode == 'fr';

    return Scaffold(
      backgroundColor: Ds.bg(context),
      // This Scaffold is nested inside the one that owns the nav bar, so the
      // FAB has to be lifted past it by hand.
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: Ds.navSpace(context)),
        child: FloatingActionButton(
          onPressed: _compose,
          backgroundColor: Ds.green,
          child: const Icon(Icons.add_rounded, color: Colors.white),
        ),
      ),
      body: Column(
        children: [
          _header(context, fr),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                HapticFeedback.mediumImpact();
                await _load();
              },
              color: Ds.green,
              child: _loading
                  ? ListView(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                      children: const [ShimmerAgendaListSkeleton()],
                    )
                  : (_posts == null || _posts!.isEmpty)
                      ? _empty(context, fr)
                      : ListView.builder(
                          controller: _scroll,
                          padding: EdgeInsets.fromLTRB(
                              16, 14, 16, Ds.navSpace(context)),
                          physics: const AlwaysScrollableScrollPhysics(
                              parent: BouncingScrollPhysics()),
                          // Header row, the posts, then the load-more footer.
                          itemCount: _posts!.length + 2,
                          itemBuilder: (_, i) {
                            if (i == 0) {
                              return Column(
                                children: [
                                  _topicsStrip(context),
                                  _tagsStrip(context),
                                  _composerCard(context),
                                ],
                              );
                            }
                            if (i == _posts!.length + 1) {
                              return _feedFooter(context, fr);
                            }
                            final post = _posts![i - 1];
                            return PostCard(
                              post: post,
                              onTap: () => _openPost(post),
                              onAuthorTap: _openAuthor,
                              onRepost: () => _repost(post),
                              onTagTap: _openTag,
                              onTopicTap: _openTopic,
                              onChanged: _replacePost,
                              onDeleted: () => _removePost(post['id'] as int),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }

  /// Spinner while the next page loads, and a full stop when there is none.
  Widget _feedFooter(BuildContext context, bool fr) {
    if (_loadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 22),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: Ds.green),
          ),
        ),
      );
    }
    if (_hasMore || (_posts?.isEmpty ?? true)) return const SizedBox(height: 8);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 22),
      child: Center(
        child: Text(
          fr ? 'Vous êtes à jour' : "You're all caught up",
          style: Ds.meta(context),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, bool fr) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          Ds.headerHPad, MediaQuery.viewPaddingOf(context).top + 12, Ds.headerHPad, 16),
      decoration: const BoxDecoration(
        color: Ds.green,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(Ds.rHeader)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              if (widget.onBackToHome != null)
                Semantics(
                  button: true,
                  label: MaterialLocalizations.of(context).backButtonTooltip,
                  child: GestureDetector(
                    onTap: widget.onBackToHome,
                    child: const SizedBox(
                      width: 32,
                      height: 32,
                      child: Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
                    ),
                  ),
                ),
              if (widget.onBackToHome != null) const SizedBox(width: 8),
              Expanded(
                child: Text(fr ? 'Explorer' : 'Explore',
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: Colors.white)),
              ),
              _activityBell(context),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(Ds.rPill),
                  ),
                  child: Row(
                    children: [
                      _segment(fr ? 'Abonnements' : 'Following', _following,
                          () => _switchFeed(true)),
                      _segment(fr ? 'Pour vous' : 'For You', !_following,
                          () => _switchFeed(false)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _myAvatar(context),
            ],
          ),
        ],
      ),
    );
  }

  /// Inline create card under the topics: write, or jump straight to a photo,
  /// video or poll without going through the compose button.
  Widget _composerCard(BuildContext context) {
    final fr = Localizations.localeOf(context).languageCode == 'fr';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Ds.surface(context),
        borderRadius: BorderRadius.circular(Ds.rCard),
        boxShadow: Ds.shadow(context),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Row(
              children: [
                _myAvatar(context, size: 42, ring: false),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _compose(),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.centerLeft,
                      decoration: BoxDecoration(
                        color: Ds.subtle(context),
                        borderRadius: BorderRadius.circular(Ds.rPill),
                      ),
                      child: Text(
                        fr
                            ? 'Que doit entendre le sommet ?'
                            : 'What should the summit hear?',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 14, color: Ds.muted(context)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: Ds.hairline(context)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                _uploadButton(
                  context,
                  icon: Icons.photo_library_rounded,
                  label: fr ? 'Photo' : 'Photo',
                  onTap: () => _compose(pick: 'image'),
                ),
                _uploadButton(
                  context,
                  icon: Icons.videocam_rounded,
                  label: fr ? 'Vidéo' : 'Video',
                  onTap: () => _compose(pick: 'video'),
                ),
                _uploadButton(
                  context,
                  icon: Icons.bar_chart_rounded,
                  label: fr ? 'Sondage' : 'Poll',
                  onTap: () => _compose(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _uploadButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) =>
      Expanded(
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(Ds.rTile),
          child: InkWell(
            borderRadius: BorderRadius.circular(Ds.rTile),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  DsIconSquare(icon, size: 30, color: Ds.green),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Ds.ink(context)),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  /// The viewer's own social profile — the feed identity, which is a different
  /// thing from the settings profile under More.
  Widget _myAvatar(BuildContext context, {double size = 42, bool ring = true}) {
    final auth = context.watch<AuthProvider>();
    final id = auth.userId;
    final name = auth.userName ?? '';
    final pic = auth.profilePictureUrl;
    final url = (pic == null || pic.isEmpty) ? '' : Environment.fixMediaUrl(pic);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        if (id == null) {
          Navigator.pushNamed(context, '/auth');
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => UserProfileScreen(userId: id)),
        ).then((_) => _load(quiet: true));
      },
      child: Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(ring ? 2 : 0),
        decoration: BoxDecoration(
            color: ring ? Colors.white : Colors.transparent, shape: BoxShape.circle),
        child: ClipOval(
          child: url.isEmpty
              ? Container(
                  color: Ds.greenTint,
                  alignment: Alignment.center,
                  child: Text(
                    name.isEmpty ? '?' : name[0].toUpperCase(),
                    style: TextStyle(
                        fontSize: size * 0.38,
                        fontWeight: FontWeight.w800,
                        color: Ds.greenDeep),
                  ),
                )
              : AppNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => Container(color: Ds.greenTint),
                  errorWidget: (_, _, _) => Container(
                    color: Ds.greenTint,
                    alignment: Alignment.center,
                    child: Text(
                      name.isEmpty ? '?' : name[0].toUpperCase(),
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w800, color: Ds.greenDeep),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  /// Hashtags in use, so they are findable rather than only reachable by
  /// already knowing one exists.
  Widget _tagsStrip(BuildContext context) {
    if (_tags.isEmpty) return const SizedBox.shrink();
    final fr = Localizations.localeOf(context).languageCode == 'fr';

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              fr ? 'Tendances' : 'Trending tags',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                  color: Ds.muted(context)),
            ),
          ),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _tags.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final tag = _tags[i]['tag'] as String? ?? '';
                final count = _tags[i]['count'] as int? ?? 0;
                return GestureDetector(
                  onTap: () => _openTag(tag),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Ds.surface(context),
                      borderRadius: BorderRadius.circular(Ds.rPill),
                      border: Border.all(color: Ds.outline(context)),
                    ),
                    child: Row(
                      children: [
                        Text('#$tag',
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Ds.greenDeep)),
                        const SizedBox(width: 6),
                        Text('$count',
                            style: TextStyle(
                                fontSize: 12, color: Ds.muted(context))),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _activityBell(BuildContext context) => GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ExploreNotificationsScreen()),
          ).then((_) {
            setState(() => _unread = 0);
            _loadSideData();
          });
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.notifications_none_rounded,
                  size: 20, color: Colors.white),
            ),
            if (_unread > 0)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  constraints: const BoxConstraints(minWidth: 18),
                  decoration: BoxDecoration(
                    color: Ds.red,
                    borderRadius: BorderRadius.circular(Ds.rPill),
                    border: const Border.fromBorderSide(
                        BorderSide(color: Ds.green, width: 1.5)),
                  ),
                  child: Text(
                    _unread > 99 ? '99+' : '$_unread',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      );

  /// Admin-authored prompts, sliding on their own so more than the first gets
  /// seen. Tapping one opens the composer already answering it; the answer
  /// count opens everything posted under it.
  Widget _topicsStrip(BuildContext context) {
    if (_topics.isEmpty) return const SizedBox.shrink();
    final fr = Localizations.localeOf(context).languageCode == 'fr';

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              fr ? 'Sujets du moment' : 'Topics to weigh in on',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                  color: Ds.muted(context)),
            ),
          ),
          SizedBox(
            height: 176,
            child: PageView.builder(
              controller: _topicsController,
              itemCount: _topics.length,
              padEnds: false,
              onPageChanged: (i) => setState(() => _topicPage = i),
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.only(right: 10),
                child: _topicCard(context, _topics[i], fr),
              ),
            ),
          ),
          if (_topics.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _topics.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _topicPage ? 18 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i == _topicPage ? Ds.gold : Ds.outline(context),
                        borderRadius: BorderRadius.circular(Ds.rPill),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _topicCard(BuildContext context, Map<String, dynamic> t, bool fr) {
    final title = (fr && (t['title_fr'] as String? ?? '').isNotEmpty)
        ? t['title_fr'] as String
        : t['title'] as String? ?? '';
    final desc = (fr && (t['description_fr'] as String? ?? '').isNotEmpty)
        ? t['description_fr'] as String
        : t['description'] as String? ?? '';
    final count = t['post_count'] as int? ?? 0;

    return GestureDetector(
      onTap: () => _compose(category: t['category'] as String?, topic: t),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Ds.greenDeep, Ds.green],
          ),
          borderRadius: BorderRadius.circular(Ds.rCard),
          boxShadow: Ds.shadow(context),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Ds.gold,
                    borderRadius: BorderRadius.circular(Ds.rPill),
                  ),
                  child: Text(
                    fr ? 'SUJET' : 'TOPIC',
                    style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7,
                        color: Ds.goldInkDeep),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => _openTopic(t['id'] as int, title),
                  child: Text(
                    count == 0
                        ? (fr ? 'Aucune réponse' : 'No answers yet')
                        : count == 1
                            ? (fr ? '1 réponse' : '1 answer')
                            : '$count ${fr ? 'réponses' : 'answers'}',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.85)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  height: 1.3,
                  letterSpacing: -0.2,
                  color: Colors.white),
            ),
            if (desc.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                desc,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: Colors.white.withValues(alpha: 0.88)),
              ),
            ],
            const Spacer(),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(Ds.rPill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.edit_rounded, size: 13, color: Ds.greenDeep),
                      const SizedBox(width: 5),
                      Text(
                        fr ? 'Répondre' : 'Add yours',
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Ds.greenDeep),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _segment(String label, bool active, VoidCallback onTap) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(Ds.rPill),
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: active ? Ds.greenDeep : Colors.white.withValues(alpha: 0.88),
              ),
            ),
          ),
        ),
      );

  Widget _empty(BuildContext context, bool fr) {
    final followingEmpty = _following;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: EdgeInsets.fromLTRB(16, 14, 16, Ds.navSpace(context)),
      children: [
        // An empty feed is exactly when someone needs these most.
        _topicsStrip(context),
        _tagsStrip(context),
        _composerCard(context),
        const SizedBox(height: 40),
        Icon(followingEmpty ? Icons.group_add_rounded : Icons.forum_rounded,
            size: 56, color: Ds.muted(context)),
        const SizedBox(height: 16),
        Text(
          followingEmpty
              ? (fr ? 'Suivez des voix' : 'Follow some voices')
              : (fr ? 'Rien encore' : 'Nothing here yet'),
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w700, color: Ds.ink(context)),
        ),
        const SizedBox(height: 8),
        Text(
          followingEmpty
              ? (fr
                  ? 'Les publications des personnes que vous suivez apparaîtront ici.'
                  : 'Posts from people you follow will show up here.')
              : (fr
                  ? 'Soyez le premier à lancer le débat.'
                  : 'Be the first to start the debate.'),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, height: 1.5, color: Ds.body(context)),
        ),
      ],
    );
  }
}
