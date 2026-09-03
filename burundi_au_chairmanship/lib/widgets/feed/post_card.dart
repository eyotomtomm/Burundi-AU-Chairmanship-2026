import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../config/app_ds.dart';
import '../../config/environment.dart';
import '../../screens/feature_card/media_video_player_screen.dart';
import '../../services/like_service.dart';
import '../image_gallery_viewer.dart';
import '../verified_badge.dart';
import 'post_body_text.dart';
import 'post_poll.dart';
import 'report_sheet.dart';
import '../../services/share_service.dart';

/// One post in the Explore feed — the card drawn in `B4Africa Social Feed`.
///
/// Renders a plain post, a repost (with the shared post quoted inside) and a
/// media post from the same `discussions` payload, so the feed and a profile
/// page can share it.
class PostCard extends StatefulWidget {
  final Map<String, dynamic> post;
  final VoidCallback? onTap;
  final void Function(int userId)? onAuthorTap;
  final Future<void> Function()? onRepost;
  final void Function(String tag)? onTagTap;
  final void Function(int topicId, String title)? onTopicTap;

  const PostCard({
    super.key,
    required this.post,
    this.onTap,
    this.onAuthorTap,
    this.onRepost,
    this.onTagTap,
    this.onTopicTap,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  final _likes = LikeService();
  VoidCallback? _removeLikeListener;

  int get _id => widget.post['id'] as int;

  @override
  void initState() {
    super.initState();
    _likes.seed(
      EntityType.discussion,
      _id,
      isLiked: widget.post['is_liked'] == true,
      likeCount: widget.post['like_count'] as int? ?? 0,
    );
    _removeLikeListener = _likes.addListener((key, _) {
      if (key == 'discussion:$_id' && mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _removeLikeListener?.call();
    super.dispose();
  }

  /// "2h", "5d" — the feed never needs more precision than this.
  static String _age(String? iso) {
    final at = DateTime.tryParse(iso ?? '');
    if (at == null) return '';
    final d = DateTime.now().difference(at);
    if (d.inMinutes < 1) return 'now';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    if (d.inDays < 7) return '${d.inDays}d';
    return '${(d.inDays / 7).floor()}w';
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final quoted = post['reposted_post'] as Map<String, dynamic>?;
    final like = _likes.getState(EntityType.discussion, _id);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Ds.surface(context),
        borderRadius: BorderRadius.circular(Ds.rCard),
        boxShadow: Ds.shadow(context),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(Ds.rCard),
        child: InkWell(
          borderRadius: BorderRadius.circular(Ds.rCard),
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (quoted != null) _repostedLine(context),
                _authorRow(context, post),
                if ((post['title'] as String? ?? '').isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    post['title'] as String,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                      color: Ds.ink(context),
                    ),
                  ),
                ],
                _topicBanner(context, post),
                if ((post['content'] as String? ?? '').isNotEmpty) ...[
                  const SizedBox(height: 10),
                  PostBodyText(
                    post['content'] as String,
                    onTagTap: widget.onTagTap,
                  ),
                ],
                if (post['poll'] != null)
                  PostPoll(poll: post['poll'] as Map<String, dynamic>),
                _mediaStrip(context, post),
                if (quoted != null) _quotedPost(context, quoted),
                _actionRow(context, like),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _repostedLine(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        Icon(Icons.repeat_rounded, size: 14, color: Ds.muted(context)),
        const SizedBox(width: 6),
        Text(
          '${widget.post['author_name'] ?? ''} reposted',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Ds.muted(context),
          ),
        ),
      ],
    ),
  );

  Widget _authorRow(BuildContext context, Map<String, dynamic> post) {
    final name = post['author_name'] as String? ?? 'Anonymous';
    final handle = post['author_handle'] as String? ?? '';
    final age = _age(post['created_at'] as String?);
    final category = post['category'] as String? ?? '';

    return Row(
      children: [
        GestureDetector(
          onTap: () => widget.onAuthorTap?.call(post['author'] as int),
          child: _avatar(context, post['author_avatar'] as String?, name, 40),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: () => widget.onAuthorTap?.call(post['author'] as int),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Ds.ink(context),
                        ),
                      ),
                    ),
                    if (post['author_badge'] != null) ...[
                      const SizedBox(width: 4),
                      VerifiedBadge(
                        badgeType: post['author_badge'] as String?,
                        size: 14,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  [
                    if (handle.isNotEmpty) '@$handle',
                    if (age.isNotEmpty) age,
                  ].join(' · '),
                  style: TextStyle(fontSize: 12, color: Ds.muted(context)),
                ),
              ],
            ),
          ),
        ),
        if (category.isNotEmpty && category != 'general')
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Ds.tint(context),
              borderRadius: BorderRadius.circular(Ds.rPill),
            ),
            child: Text(
              _categoryLabel(category),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Ds.greenDeep,
              ),
            ),
          ),
        _overflowMenu(context, post),
      ],
    );
  }

  /// The question this post answers. Without it an answer reads as a stray
  /// remark, so it travels with the post rather than living only on the card
  /// that started it.
  Widget _topicBanner(BuildContext context, Map<String, dynamic> post) {
    final topicId = post['topic'] as int?;
    final title = post['topic_title'] as String? ?? '';
    if (topicId == null || title.isEmpty) return const SizedBox.shrink();

    final fr = Localizations.localeOf(context).languageCode == 'fr';
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: GestureDetector(
        onTap: () => widget.onTopicTap?.call(topicId, title),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Ds.tint(context),
            borderRadius: BorderRadius.circular(Ds.rTile),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.forum_rounded, size: 16, color: Ds.greenDeep),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fr ? 'EN RÉPONSE À' : 'ANSWERING',
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: Ds.greenDeep),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      style: TextStyle(
                          fontSize: 12.5,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                          color: Ds.ink(context)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _overflowMenu(BuildContext context, Map<String, dynamic> post) {
    return SizedBox(
      width: 32,
      child: PopupMenuButton<String>(
        padding: EdgeInsets.zero,
        icon: Icon(Icons.more_vert_rounded, size: 18, color: Ds.chevron),
        onSelected: (value) {
          if (value == 'report_post') {
            ReportSheet.open(context, discussionId: post['id'] as int);
          } else if (value == 'report_user') {
            ReportSheet.open(
              context,
              userId: post['author'] as int,
              targetName: post['author_name'] as String? ?? '',
            );
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'report_post', child: Text('Report post')),
          PopupMenuItem(value: 'report_user', child: Text('Report account')),
        ],
      ),
    );
  }

  static String _categoryLabel(String value) => switch (value) {
    'arise' => 'A-RISE',
    'politics' => 'Politics',
    'business' => 'Business',
    'announcements' => 'News',
    _ => value[0].toUpperCase() + value.substring(1),
  };

  Widget _avatar(BuildContext context, String? url, String name, double size) {
    final fixed = (url == null || url.isEmpty)
        ? ''
        : Environment.fixMediaUrl(url);
    if (fixed.isEmpty) {
      return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Ds.tint(context),
          shape: BoxShape.circle,
        ),
        child: Text(
          name.isEmpty ? '?' : name[0].toUpperCase(),
          style: TextStyle(
            fontSize: size * 0.38,
            fontWeight: FontWeight.w800,
            color: Ds.greenDeep,
          ),
        ),
      );
    }
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: fixed,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, _) =>
            Container(width: size, height: size, color: Ds.subtle(context)),
        errorWidget: (_, _, _) => Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          color: Ds.tint(context),
          child: Text(
            name.isEmpty ? '?' : name[0].toUpperCase(),
            style: TextStyle(
              fontSize: size * 0.38,
              fontWeight: FontWeight.w800,
              color: Ds.greenDeep,
            ),
          ),
        ),
      ),
    );
  }

  Widget _mediaStrip(BuildContext context, Map<String, dynamic> post) {
    final media =
        (post['media'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    if (media.isEmpty) return const SizedBox.shrink();

    final photos = media
        .where((m) => m['media_type'] != 'video' && m['url'] != null)
        .map((m) => Environment.fixMediaUrl(m['url'] as String))
        .toList();

    // One item fills the card; several scroll sideways.
    final single = media.length == 1;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SizedBox(
        height: single ? 168 : 150,
        child: LayoutBuilder(
          builder: (context, constraints) => ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: single
                ? const NeverScrollableScrollPhysics()
                : const BouncingScrollPhysics(),
            itemCount: media.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final m = media[i];
              final raw = m['url'] as String?;
              if (raw == null) return const SizedBox.shrink();
              final url = Environment.fixMediaUrl(raw);
              // A horizontal ListView hands children unbounded width, so a lone
              // item has to take the card's measured width, not double.infinity.
              final width = single ? constraints.maxWidth : 220.0;

              if (m['media_type'] == 'video') {
                return _tile(
                  context,
                  width: width,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MediaVideoPlayerScreen(
                        videoUrl: url,
                        caption: m['caption'] as String? ?? '',
                      ),
                    ),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(color: Ds.greenDarker),
                      const Center(
                        child: Icon(
                          Icons.play_circle_fill_rounded,
                          size: 48,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                );
              }

              final index = photos.indexOf(url);
              return _tile(
                context,
                width: width,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ImageGalleryViewer(
                      images: photos,
                      initialIndex: index < 0 ? 0 : index,
                      shareKind: 'discussions',
                      shareId: _id,
                      shareTitle: widget.post['title'] as String?,
                    ),
                  ),
                ),
                child: CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => Container(color: Ds.subtle(context)),
                  errorWidget: (_, _, _) => Container(
                    color: Ds.subtle(context),
                    child: Icon(
                      Icons.broken_image_rounded,
                      color: Ds.muted(context),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _tile(
    BuildContext context, {
    required double width,
    required Widget child,
    VoidCallback? onTap,
  }) {
    final clipped = ClipRRect(
      borderRadius: BorderRadius.circular(Ds.rTile),
      child: SizedBox(
        width: width == double.infinity ? null : width,
        child: child,
      ),
    );
    return GestureDetector(
      onTap: onTap,
      child: width == double.infinity
          ? SizedBox(width: double.infinity, child: clipped)
          : clipped,
    );
  }

  Widget _quotedPost(BuildContext context, Map<String, dynamic> quoted) {
    final name = quoted['author_name'] as String? ?? '';
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        border: Border.all(color: Ds.outline(context)),
        borderRadius: BorderRadius.circular(Ds.rTile),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _avatar(context, quoted['author_avatar'] as String?, name, 24),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Ds.ink(context),
                  ),
                ),
              ),
              if (quoted['author_badge'] != null) ...[
                const SizedBox(width: 4),
                VerifiedBadge(
                  badgeType: quoted['author_badge'] as String?,
                  size: 12,
                ),
              ],
              const SizedBox(width: 6),
              Text(
                '· ${_age(quoted['created_at'] as String?)}',
                style: TextStyle(fontSize: 12, color: Ds.muted(context)),
              ),
            ],
          ),
          const SizedBox(height: 7),
          PostBodyText(
            quoted['content'] as String? ?? '',
            fontSize: 13,
            maxLines: 4,
            onTagTap: widget.onTagTap,
          ),
        ],
      ),
    );
  }

  Widget _actionRow(BuildContext context, LikeState like) {
    final post = widget.post;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          _action(
            context,
            icon: like.isLiked
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            color: like.isLiked ? Ds.red : Ds.body(context),
            count: like.likeCount,
            onTap: () => _likes.toggle(EntityType.discussion, _id),
          ),
          _action(
            context,
            icon: Icons.mode_comment_outlined,
            color: Ds.body(context),
            count: post['reply_count'] as int? ?? 0,
            onTap: widget.onTap,
          ),
          _action(
            context,
            icon: Icons.repeat_rounded,
            color: Ds.body(context),
            count: post['repost_count'] as int? ?? 0,
            onTap: widget.onRepost == null ? null : () => widget.onRepost!(),
          ),
          Builder(
            builder: (btnContext) => _action(
              btnContext,
              icon: Icons.share_rounded,
              color: Ds.body(context),
              count: 0,
              onTap: () => ShareService.item(
                btnContext,
                kind: 'discussions',
                id: _id,
                title: (post['title'] as String?)?.trim().isNotEmpty == true
                    ? post['title'] as String
                    : (post['content'] as String? ?? ''),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _action(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required int count,
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(Ds.rTile),
        onTap: onTap,
        child: SizedBox(
          height: 44,
          child: Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 7),
              Text(
                count == 0 ? '' : '$count',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Ds.body(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
