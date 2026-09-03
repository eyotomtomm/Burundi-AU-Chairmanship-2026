import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../config/app_ds.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import 'post_body_text.dart';
import 'verified_badge_row.dart';

/// Sharing a post: straight repost, or quote it with your own line.
class RepostSheet {
  /// Returns true when the feed should reload.
  static Future<bool> open(BuildContext context, Map<String, dynamic> post) async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      Navigator.pushNamed(context, '/auth');
      return false;
    }

    // Sharing a share credits the original, matching what the server does.
    final target = (post['reposted_post'] as Map<String, dynamic>?) ?? post;
    final fr = Localizations.localeOf(context).languageCode == 'fr';

    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Ds.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Ds.rSheet)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Ds.outline(ctx),
                borderRadius: BorderRadius.circular(Ds.rPill),
              ),
            ),
            const SizedBox(height: 14),
            ListTile(
              leading: Icon(Icons.repeat_rounded, color: Ds.ink(ctx)),
              title: Text(fr ? 'Republier' : 'Repost',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Ds.ink(ctx))),
              subtitle: Text(
                  fr
                      ? 'Partager tel quel avec vos abonnés'
                      : 'Share it as is with your followers',
                  style: TextStyle(fontSize: 12, color: Ds.body(ctx))),
              onTap: () => Navigator.pop(ctx, 'repost'),
            ),
            ListTile(
              leading: Icon(Icons.format_quote_rounded, color: Ds.ink(ctx)),
              title: Text(fr ? 'Citer' : 'Quote',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Ds.ink(ctx))),
              subtitle: Text(
                  fr ? 'Ajouter votre propre commentaire' : 'Add your own take',
                  style: TextStyle(fontSize: 12, color: Ds.body(ctx))),
              onTap: () => Navigator.pop(ctx, 'quote'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (choice == null || !context.mounted) return false;

    if (choice == 'repost') {
      return _send(context, target['id'] as int, '');
    }
    return _quote(context, target, fr);
  }

  static Future<bool> _quote(
      BuildContext context, Map<String, dynamic> target, bool fr) async {
    final ctrl = TextEditingController();
    var sent = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Ds.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Ds.rSheet)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 26),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: Ds.outline(ctx),
                      borderRadius: BorderRadius.circular(Ds.rPill),
                    ),
                  ),
                ),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Text(fr ? 'Annuler' : 'Cancel',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Ds.body(ctx))),
                    ),
                    Expanded(
                      child: Text(fr ? 'Citer' : 'Quote',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Ds.ink(ctx))),
                    ),
                    GestureDetector(
                      onTap: () async {
                        final text = ctrl.text.trim();
                        if (text.isEmpty) return;
                        Navigator.pop(ctx);
                        sent = await _send(context, target['id'] as int, text);
                      },
                      child: Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Ds.green,
                          borderRadius: BorderRadius.circular(Ds.rPill),
                        ),
                        child: Text(fr ? 'Publier' : 'Post',
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  minLines: 2,
                  maxLines: 6,
                  style: TextStyle(fontSize: 16, height: 1.5, color: Ds.ink(ctx)),
                  decoration: InputDecoration(
                    hintText: fr ? 'Ajouter votre commentaire…' : 'Add your take…',
                    hintStyle: TextStyle(fontSize: 16, color: Ds.muted(ctx)),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(height: 12),
                // The post being quoted, shown the way it will appear.
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    border: Border.all(color: Ds.outline(ctx)),
                    borderRadius: BorderRadius.circular(Ds.rTile),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      VerifiedBadgeRow(
                        name: target['author_name'] as String? ?? '',
                        badge: target['author_badge'] as String?,
                      ),
                      const SizedBox(height: 7),
                      PostBodyText(
                        target['content'] as String? ?? '',
                        fontSize: 13,
                        maxLines: 4,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return sent;
  }

  static Future<bool> _send(
      BuildContext context, int discussionId, String content) async {
    try {
      final res = await ApiService().toggleRepost(discussionId, content: content);
      HapticFeedback.lightImpact();
      if (context.mounted && res['reposted'] == false) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Repost removed')));
      }
      return true;
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
      return false;
    }
  }
}
