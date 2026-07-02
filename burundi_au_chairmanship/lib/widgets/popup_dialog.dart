import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/popup_model.dart';
import '../config/app_colors.dart';
import '../services/deep_link_router.dart';

class PopupDialog extends StatelessWidget {
  final PopupModel popup;
  final String languageCode;
  final VoidCallback onClose;

  const PopupDialog({
    super.key,
    required this.popup,
    required this.languageCode,
    required this.onClose,
  });

  void _handleAction(BuildContext context) {
    onClose();
    final url = popup.actionUrl.trim();
    if (url.isEmpty) return;
    DeepLinkRouter().navigate(url);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Image (if provided)
            if (popup.image != null && popup.image!.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: CachedNetworkImage(
                  imageUrl: popup.image!,
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    height: 200,
                    color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
                    child: const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.burundiGreen),
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => const SizedBox.shrink(),
                ),
              ),

            // Content
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title
                  Text(
                    popup.getTitle(languageCode),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),

                  // Message
                  Text(
                    popup.getMessage(languageCode),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // Action button (if provided)
                  if (popup.actionText.isNotEmpty || popup.actionTextFr.isNotEmpty)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => _handleAction(context),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.burundiGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          popup.getActionText(languageCode),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                  // Close button
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: onClose,
                    child: Text(
                      languageCode == 'fr' ? 'Fermer' : 'Close',
                      style: TextStyle(
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Static method to show popup dialog
  static Future<void> show({
    required BuildContext context,
    required PopupModel popup,
    required String languageCode,
  }) async {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => PopupDialog(
        popup: popup,
        languageCode: languageCode,
        onClose: () => Navigator.of(context).pop(),
      ),
    );
  }
}
