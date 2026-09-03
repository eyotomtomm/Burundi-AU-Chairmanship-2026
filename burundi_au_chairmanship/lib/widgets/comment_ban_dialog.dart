import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../screens/home/widgets/support_options_modal.dart';
import '../l10n/app_localizations.dart';

/// Shared dialog for profanity ban (403) and language warning (400) responses.
///
/// Replaces the duplicated `_showCommentErrorDialog` found across 9 files.
void showCommentErrorDialog(BuildContext context, String message, int statusCode, {String? referenceId}) {
  final isBan = statusCode == 403 || message.contains('banned');
  final l10n = AppLocalizations.of(context);

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: Icon(
        isBan ? Icons.block : Icons.warning_amber_rounded,
        color: isBan ? Colors.red : Colors.orange,
        size: 48,
      ),
      title: Text(
        l10n.translate(isBan ? 'w_comment_banned' : 'w_language_warning'),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          if (isBan && referenceId != null) ...[
            const SizedBox(height: 12),
            Text(
              '${l10n.translate('w_reference_number')} $referenceId',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
      actions: [
        if (isBan)
          TextButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              final subject = 'Comment Ban Appeal - $referenceId';
              showSupportOptionsModal(context, prefilledSubject: subject);
            },
            icon: const Icon(Icons.support_agent_rounded, size: 18),
            label: Text(l10n.translate('contact_us')),
            style: TextButton.styleFrom(foregroundColor: AppColors.burundiGreen),
          ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(l10n.translate('close')),
        ),
      ],
    ),
  );
}
