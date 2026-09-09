import 'package:flutter/material.dart';

import '../../config/app_ds.dart';
import '../../config/environment.dart';
import '../../services/api_service.dart';
import '../../widgets/verified_badge.dart';
import '../../widgets/app_network_image.dart';
import '../discussions/discussion_detail_screen.dart';
import 'user_profile_screen.dart';

/// Explore's own activity feed: follows, likes, replies and reposts.
///
/// Separate from the app's broadcast notification centre — this is only ever
/// about what other people did to your posts.
class ExploreNotificationsScreen extends StatefulWidget {
  const ExploreNotificationsScreen({super.key});

  @override
  State<ExploreNotificationsScreen> createState() =>
      _ExploreNotificationsScreenState();
}

class _ExploreNotificationsScreenState extends State<ExploreNotificationsScreen> {
  final _api = ApiService();
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _api.getExploreNotifications();
      _items = (data['results'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      // Opening the screen is the read receipt.
      await _api.markExploreNotificationsRead();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  static String _line(Map<String, dynamic> n) {
    final name = n['actor_name'] as String? ?? 'Someone';
    return switch (n['verb']) {
      'follow' => '$name started following you',
      'like' => '$name liked your post',
      'reply' => '$name replied to your post',
      'repost' => '$name reposted your post',
      _ => name,
    };
  }

  static IconData _icon(String? verb) => switch (verb) {
        'follow' => Icons.person_add_rounded,
        'like' => Icons.favorite_rounded,
        'reply' => Icons.mode_comment_rounded,
        'repost' => Icons.repeat_rounded,
        _ => Icons.notifications_rounded,
      };

  static Color _iconColour(String? verb) => switch (verb) {
        'like' => Ds.red,
        'repost' => Ds.green,
        _ => Ds.blue,
      };

  static String _age(String? iso) {
    final at = DateTime.tryParse(iso ?? '');
    if (at == null) return '';
    final d = DateTime.now().difference(at);
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    if (d.inDays < 7) return '${d.inDays}d';
    return '${(d.inDays / 7).floor()}w';
  }

  @override
  Widget build(BuildContext context) {
    final fr = Localizations.localeOf(context).languageCode == 'fr';

    return Scaffold(
      backgroundColor: Ds.bg(context),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(Ds.headerHPad,
                MediaQuery.viewPaddingOf(context).top + 12, Ds.headerHPad, 18),
            decoration: const BoxDecoration(
              color: Ds.green,
              borderRadius:
                  BorderRadius.vertical(bottom: Radius.circular(Ds.rHeader)),
            ),
            child: Row(
              children: [
                Semantics(
                  button: true,
                  label: MaterialLocalizations.of(context).backButtonTooltip,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const SizedBox(
                      width: 32,
                      height: 32,
                      child: Icon(Icons.arrow_back_rounded,
                          color: Colors.white, size: 22),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(fr ? 'Activité' : 'Activity',
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: Colors.white)),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              color: Ds.green,
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Ds.green))
                  : _items.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(32, 80, 32, 0),
                          children: [
                            Icon(Icons.notifications_none_rounded,
                                size: 56, color: Ds.muted(context)),
                            const SizedBox(height: 16),
                            Text(
                              fr ? 'Rien pour l\'instant' : 'Nothing yet',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Ds.ink(context)),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              fr
                                  ? 'Les mentions J\'aime, réponses et abonnements apparaîtront ici.'
                                  : 'Likes, replies and new followers will show up here.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 14, height: 1.5, color: Ds.body(context)),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: EdgeInsets.fromLTRB(
                              16, 14, 16, Ds.navSpace(context)),
                          itemCount: _items.length,
                          itemBuilder: (_, i) => _row(context, _items[i]),
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, Map<String, dynamic> n) {
    final avatarUrl = n['actor_avatar'] as String?;
    final name = n['actor_name'] as String? ?? '';
    final excerpt = n['excerpt'] as String? ?? '';
    final unread = n['is_read'] != true;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: unread ? Ds.tint(context) : Ds.surface(context),
        borderRadius: BorderRadius.circular(Ds.rCard),
        boxShadow: unread ? null : Ds.shadow(context),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(Ds.rCard),
        child: InkWell(
          borderRadius: BorderRadius.circular(Ds.rCard),
          onTap: () {
            final discussionId = n['discussion_id'] as int?;
            if (discussionId != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DiscussionDetailScreen(discussionId: discussionId),
                ),
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => UserProfileScreen(userId: n['actor_id'] as int),
                ),
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipOval(
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: (avatarUrl == null || avatarUrl.isEmpty)
                            ? Container(
                                color: Ds.greenTint,
                                alignment: Alignment.center,
                                child: Text(
                                  name.isEmpty ? '?' : name[0].toUpperCase(),
                                  style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: Ds.greenDeep),
                                ),
                              )
                            : AppNetworkImage(
                                imageUrl: Environment.fixMediaUrl(avatarUrl),
                                fit: BoxFit.cover,
                                placeholder: (_, _) =>
                                    Container(color: Ds.greenTint),
                                errorWidget: (_, _, _) =>
                                    Container(color: Ds.greenTint),
                              ),
                      ),
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Ds.surface(context),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(_icon(n['verb'] as String?),
                            size: 13, color: _iconColour(n['verb'] as String?)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _line(n),
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Ds.ink(context)),
                            ),
                          ),
                          if (n['actor_badge'] != null)
                            VerifiedBadge(
                                badgeType: n['actor_badge'] as String?, size: 14),
                          const SizedBox(width: 6),
                          Text(_age(n['created_at'] as String?),
                              style: TextStyle(
                                  fontSize: 12, color: Ds.muted(context))),
                        ],
                      ),
                      if (excerpt.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          excerpt,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, color: Ds.body(context)),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
