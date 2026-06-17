import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_colors.dart';
import '../providers/language_provider.dart';
import '../screens/home/widgets/support_options_modal.dart';

/// Shared dialog for profanity ban (403) and language warning (400) responses.
///
/// Replaces the duplicated `_showCommentErrorDialog` found across 9 files.
void showCommentErrorDialog(BuildContext context, String message, int statusCode, {String? referenceId}) {
  final isBan = statusCode == 403 || message.contains('banned');
  final langCode = context.read<LanguageProvider>().languageCode;

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: Icon(
        isBan ? Icons.block : Icons.warning_amber_rounded,
        color: isBan ? Colors.red : Colors.orange,
        size: 48,
      ),
      title: Text(
        isBan
            ? (langCode == 'fr' ? 'Commentaire Banni' : 'Comment Banned')
            : (langCode == 'fr' ? 'Avertissement de Langage' : 'Language Warning'),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          if (isBan && referenceId != null) ...[
            const SizedBox(height: 12),
            Text(
              langCode == 'fr'
                  ? 'Votre numéro de référence : $referenceId'
                  : 'Your reference number: $referenceId',
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
            label: Text(langCode == 'fr' ? 'Nous Contacter' : 'Contact Us'),
            style: TextButton.styleFrom(foregroundColor: AppColors.burundiGreen),
          ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(langCode == 'fr' ? 'Fermer' : 'OK'),
        ),
      ],
    ),
  );
}
