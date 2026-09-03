import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_ds.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

/// Flags a post or a person for moderator review.
class ReportSheet {
  static const _reasons = [
    {'value': 'spam', 'label': 'Spam or misleading'},
    {'value': 'harassment', 'label': 'Harassment or hate'},
    {'value': 'violence', 'label': 'Violence or threats'},
    {'value': 'sexual', 'label': 'Sexual content'},
    {'value': 'misinformation', 'label': 'False information'},
    {'value': 'other', 'label': 'Something else'},
  ];

  static Future<void> open(
    BuildContext context, {
    int? discussionId,
    int? userId,
    String targetName = '',
  }) async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      Navigator.pushNamed(context, '/auth');
      return;
    }

    final reason = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Ds.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Ds.rSheet)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
              child: Text(
                discussionId != null
                    ? 'Report this post'
                    : 'Report ${targetName.isEmpty ? 'this account' : targetName}',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700, color: Ds.ink(ctx)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Text('What is wrong with it?',
                  style: TextStyle(fontSize: 13, color: Ds.body(ctx))),
            ),
            for (final r in _reasons)
              ListTile(
                title: Text(r['label']!,
                    style: TextStyle(fontSize: 15, color: Ds.ink(ctx))),
                trailing: Icon(Icons.chevron_right_rounded, color: Ds.chevron),
                onTap: () => Navigator.pop(ctx, r['value']),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (reason == null || !context.mounted) return;

    try {
      final res = await ApiService()
          .reportContent(discussionId: discussionId, userId: userId, reason: reason);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(res['detail'] as String? ??
                'Thanks — our moderators will take a look.')));
      }
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }
}
