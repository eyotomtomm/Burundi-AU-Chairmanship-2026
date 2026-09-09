import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_ds.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../l10n/app_localizations.dart';

/// Flags a post or a person for moderator review.
class ReportSheet {
  static const _reasons = [
    {'value': 'spam', 'label': 'w_reason_spam'},
    {'value': 'harassment', 'label': 'w_reason_harassment'},
    {'value': 'violence', 'label': 'w_reason_violence'},
    {'value': 'sexual', 'label': 'w_reason_sexual'},
    {'value': 'misinformation', 'label': 'w_reason_misinformation'},
    {'value': 'other', 'label': 'w_reason_other'},
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
                    ? AppLocalizations.of(ctx).translate('w_report_this_post')
                    : '${AppLocalizations.of(ctx).translate('w_report')} ${targetName.isEmpty ? AppLocalizations.of(ctx).translate('w_this_account') : targetName}',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700, color: Ds.ink(ctx)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Text(AppLocalizations.of(ctx).translate('w_what_is_wrong'),
                  style: TextStyle(fontSize: 13, color: Ds.body(ctx))),
            ),
            for (final r in _reasons)
              ListTile(
                title: Text(AppLocalizations.of(ctx).translate(r['label']!),
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
