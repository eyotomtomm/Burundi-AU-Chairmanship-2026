import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../config/app_ds.dart';
import '../../config/environment.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/async_content_view.dart';
import '../../widgets/feed/post_card.dart';
import '../../widgets/feed/repost_sheet.dart';
import 'tag_feed_screen.dart';
import '../../widgets/feed/report_sheet.dart';
import '../../widgets/verified_badge.dart';
import '../../widgets/app_network_image.dart';
import '../discussions/discussion_detail_screen.dart';
import 'edit_profile_screen.dart';
import '../../l10n/app_localizations.dart';
import '../../services/feed_pager.dart';

/// A person's public page: who they are, their counts, and their posts.
class UserProfileScreen extends StatefulWidget {
  final int userId;

  const UserProfileScreen({super.key, required this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _api = ApiService();
  Map<String, dynamic>? _profile;
  bool _loading = true;
  bool _loadFailed = false;
  bool _followBusy = false;
  bool _blockBusy = false;
  late final FeedPager _pager =
      FeedPager((page) => _api.getFeedPage(authorId: widget.userId, page: page));

  List<Map<String, dynamic>> get _posts => _pager.posts;

  @override
  void initState() {
    super.initState();
    _pager.addListener(_onPager);
    _load();
  }

  @override
  void dispose() {
    _pager.removeListener(_onPager);
    _pager.dispose();
    super.dispose();
  }

  void _onPager() {
    if (mounted) setState(() {});
  }

  Future<void> _load({bool quiet = false}) async {
    if (!quiet) setState(() => _loading = true);
    try {
      _profile = await _api.getUserProfile(widget.userId);
      await _pager.load(quiet: quiet);
      _loadFailed = false;
    } catch (e) {
      _loadFailed = e is! ApiException || e.statusCode != 404;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _toggleFollow() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      Navigator.pushNamed(context, '/auth');
      return;
    }
    if (_followBusy) return;
    setState(() => _followBusy = true);

    // Optimistic: the button flips now, the count reconciles from the response.
    final wasFollowing = _profile?['is_following'] == true;
    setState(() {
      _profile?['is_following'] = !wasFollowing;
      _profile?['follower_count'] =
          (_profile?['follower_count'] as int? ?? 0) + (wasFollowing ? -1 : 1);
    });
    HapticFeedback.lightImpact();

    try {
      final res = await _api.toggleFollow(widget.userId);
      if (mounted) {
        setState(() {
          _profile?['is_following'] = res['is_following'] == true;
          _profile?['follower_count'] = res['follower_count'] as int? ?? 0;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _profile?['is_following'] = wasFollowing;
          _profile?['follower_count'] =
              (_profile?['follower_count'] as int? ?? 0) + (wasFollowing ? 1 : -1);
        });
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _followBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fr = Localizations.localeOf(context).languageCode == 'fr';

    if (_loading && _profile == null) {
      return Scaffold(
        backgroundColor: Ds.bg(context),
        body: const Center(
            child: CircularProgressIndicator(strokeWidth: 2, color: Ds.green)),
      );
    }
    if (_profile == null) {
      return Scaffold(
        backgroundColor: Ds.bg(context),
        appBar: AppBar(),
        body: _loadFailed
            ? AsyncContentView(
                state: AsyncContentState.error,
                onRetry: _load,
                child: const SizedBox.shrink(),
              )
            : Center(child: Text(fr ? 'Profil introuvable' : 'Profile not found')),
      );
    }

    return Scaffold(
      backgroundColor: Ds.bg(context),
      body: RefreshIndicator(
        onRefresh: _load,
        color: Ds.green,
        child: ListView(
          controller: _pager.scroll,
          padding: EdgeInsets.only(bottom: Ds.navSpace(context)),
          physics:
              const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          children: [
            _header(context),
            Transform.translate(
              offset: const Offset(0, -30),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _statsCard(context, fr),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Text(fr ? 'Publications' : 'Posts',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: Ds.ink(context))),
            ),
            if (_posts.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 20, 32, 0),
                child: Text(
                  fr ? 'Aucune publication pour le moment.' : 'No posts yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Ds.body(context)),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: _posts
                      .map((p) => PostCard(
                            post: p,
                            onRepost: () async {
                              if (await RepostSheet.open(context, p)) _load(quiet: true);
                            },
                            onTopicTap: (id, title) => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    TagFeedScreen(topicId: id, topicTitle: title),
                              ),
                            ),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => DiscussionDetailScreen(
                                    discussionId: p['id'] as int),
                              ),
                            ).then((_) => _load(quiet: true)),
                          ))
                      .toList(),
                ),
              ),
            FeedPagerFooter(_pager, accent: Ds.green, endStyle: Ds.meta(context)),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final p = _profile!;
    final honorific = p['honorific'] as String? ?? '';
    final baseName = p['name'] as String? ?? '';
    // A verified user's honorific comes from their approved request, so it is
    // shown automatically rather than typed into their name.
    final name = honorific.isEmpty ? baseName : '$honorific $baseName';
    final handle = p['handle'] as String? ?? '';
    final bio = p['bio'] as String? ?? '';
    final role = [p['role'], p['organization']]
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .join(' · ');

    return Container(
      padding: EdgeInsets.fromLTRB(Ds.headerHPad,
          MediaQuery.viewPaddingOf(context).top + 12, Ds.headerHPad, 46),
      decoration: const BoxDecoration(
        color: Ds.green,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(Ds.rHeader)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Semantics(
                button: true,
                label: MaterialLocalizations.of(context).backButtonTooltip,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const SizedBox(
                    width: 32,
                    height: 32,
                    child: Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
                  ),
                ),
              ),
              const Spacer(),
              if (p['is_self'] != true)
                GestureDetector(
                  onTap: () => ReportSheet.open(context,
                      userId: widget.userId,
                      targetName: p['name'] as String? ?? ''),
                  child: const SizedBox(
                    width: 32,
                    height: 32,
                    child: Icon(Icons.more_vert_rounded, color: Colors.white, size: 20),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _avatar(context, p['avatar'] as String?, name),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                                color: Colors.white),
                          ),
                        ),
                        if (p['badge'] != null) ...[
                          const SizedBox(width: 5),
                          VerifiedBadge(badgeType: p['badge'] as String?, size: 18),
                        ],
                      ],
                    ),
                    if (handle.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text('@$handle',
                            style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withValues(alpha: 0.85))),
                      ),
                    if (role.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(role,
                            style: TextStyle(
                                fontSize: 12,
                                height: 1.35,
                                color: Colors.white.withValues(alpha: 0.85))),
                      ),
                    if (bio.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(bio,
                            style: TextStyle(
                                fontSize: 13,
                                height: 1.4,
                                color: Colors.white.withValues(alpha: 0.95))),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _avatar(BuildContext context, String? url, String name) {
    final fixed = (url == null || url.isEmpty) ? '' : Environment.fixMediaUrl(url);
    Widget inner;
    if (fixed.isEmpty) {
      inner = Container(
        alignment: Alignment.center,
        decoration: const BoxDecoration(color: Ds.greenTint, shape: BoxShape.circle),
        child: Text(
          name.isEmpty ? '?' : name[0].toUpperCase(),
          style: const TextStyle(
              fontSize: 30, fontWeight: FontWeight.w800, color: Ds.greenDeep),
        ),
      );
    } else {
      inner = ClipOval(
        child: AppNetworkImage(
          imageUrl: fixed,
          width: 78,
          height: 78,
          fit: BoxFit.cover,
          placeholder: (_, _) => Container(color: Ds.greenTint),
          errorWidget: (_, _, _) => Container(color: Ds.greenTint),
        ),
      );
    }
    return Container(
      width: 84,
      height: 84,
      padding: const EdgeInsets.all(3),
      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      child: SizedBox(width: 78, height: 78, child: inner),
    );
  }

  Widget _statsCard(BuildContext context, bool fr) {
    final p = _profile!;
    final isSelf = p['is_self'] == true;
    final isFollowing = p['is_following'] == true;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Ds.surface(context),
        borderRadius: BorderRadius.circular(Ds.rCard),
        boxShadow: Ds.shadowLg(context),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _stat(context, '${p['post_count'] ?? 0}', fr ? 'Publications' : 'Posts'),
              _divider(context),
              _stat(context, '${p['follower_count'] ?? 0}',
                  fr ? 'Abonnés' : 'Followers'),
              _divider(context),
              _stat(context, '${p['following_count'] ?? 0}',
                  fr ? 'Abonnements' : 'Following'),
            ],
          ),
          const SizedBox(height: 14),
          if (isSelf)
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EditProfileScreen()),
              ).then((changed) {
                if (changed == true) _load();
              }),
              child: Container(
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(color: Ds.outline(context)),
                  borderRadius: BorderRadius.circular(Ds.rPill),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.edit_rounded, size: 18, color: Ds.body(context)),
                    const SizedBox(width: 7),
                    Text(fr ? 'Modifier le profil' : 'Edit profile',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Ds.body(context))),
                  ],
                ),
              ),
            ),
          if (!isSelf) ...[
            GestureDetector(
              onTap: _toggleFollow,
              child: Container(
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isFollowing ? Colors.transparent : Ds.green,
                  border: isFollowing ? Border.all(color: Ds.outline(context)) : null,
                  borderRadius: BorderRadius.circular(Ds.rPill),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(isFollowing ? Icons.check_rounded : Icons.add_rounded,
                        size: 18,
                        color: isFollowing ? Ds.body(context) : Colors.white),
                    const SizedBox(width: 7),
                    Text(
                      isFollowing
                          ? (fr ? 'Abonné' : 'Following')
                          : (fr ? 'Suivre' : 'Follow'),
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isFollowing ? Ds.body(context) : Colors.white),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            _blockButton(context),
          ],
        ],
      ),
    );
  }

  /// Block / unblock. Reporting alone is not enough for a public feed — and
  /// Apple's guideline 1.2 asks for this specifically.
  Widget _blockButton(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final blocked = _profile?['is_blocked'] == true;
    return GestureDetector(
      onTap: _blockBusy ? null : _toggleBlock,
      child: Container(
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: Ds.outline(context)),
          borderRadius: BorderRadius.circular(Ds.rPill),
        ),
        child: Text(
          blocked ? l10n.translate('w_unblock') : l10n.translate('w_block'),
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: blocked ? Ds.body(context) : Ds.red),
        ),
      ),
    );
  }

  Future<void> _toggleBlock() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      Navigator.pushNamed(context, '/auth');
      return;
    }
    final l10n = AppLocalizations.of(context);
    final blocked = _profile?['is_blocked'] == true;
    if (!blocked) {
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.translate('w_block_account')),
          content: Text(l10n.translate('w_block_body')),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l10n.translate('cancel'))),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l10n.translate('w_block'),
                    style: const TextStyle(color: Ds.red))),
          ],
        ),
      );
      if (go != true) return;
    }
    setState(() => _blockBusy = true);
    try {
      final res = await _api.toggleBlock(widget.userId);
      _profile?['is_blocked'] = res['is_blocked'] == true;
      // Blocking drops the follow on both sides, so the header is stale.
      await _load(quiet: true);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
    if (mounted) setState(() => _blockBusy = false);
  }

  Widget _divider(BuildContext context) =>
      Container(width: 1, height: 32, color: Ds.hairline(context));

  Widget _stat(BuildContext context, String value, String label) => Expanded(
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800, color: Ds.ink(context))),
            const SizedBox(height: 2),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: Ds.muted(context))),
          ],
        ),
      );
}
