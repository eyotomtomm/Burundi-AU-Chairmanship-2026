import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_colors.dart';
import '../services/api_service.dart';

/// Shows an app update dialog on startup.
///
/// Calls `/api/app-update/?current_version=X` and shows either:
/// - A dismissable optional update dialog, or
/// - A non-dismissable force update dialog.
class AppUpdateDialog {
  /// Check for updates and show the appropriate dialog.
  ///
  /// [context] - the BuildContext to show the dialog in.
  /// [currentVersion] - the current app version string (e.g. "1.2.3").
  /// [langCode] - "en" or "fr" for bilingual support.
  static Future<void> check({
    required BuildContext context,
    required String currentVersion,
    String langCode = 'en',
  }) async {
    try {
      final api = ApiService();
      final data = await api.checkAppUpdate(currentVersion);

      final bool updateAvailable = data['update_available'] ?? false;
      if (!updateAvailable) return;

      final bool forceUpdate = data['force_update'] ?? false;
      final String storeUrl = data['store_url'] ?? '';
      final String latestVersion = data['latest_version'] ?? '';
      final String releaseNotes = data['release_notes'] ?? '';

      if (!context.mounted) return;

      showDialog(
        context: context,
        barrierDismissible: !forceUpdate,
        builder: (dialogContext) => PopScope(
          canPop: !forceUpdate,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.system_update, color: AppColors.burundiGreen),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    langCode == 'fr' ? 'Mise a jour disponible' : 'Update Available',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  langCode == 'fr'
                      ? 'Version $latestVersion est disponible.'
                      : 'Version $latestVersion is available.',
                  style: const TextStyle(fontSize: 14),
                ),
                if (releaseNotes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    releaseNotes,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
                if (forceUpdate) ...[
                  const SizedBox(height: 12),
                  Text(
                    langCode == 'fr'
                        ? 'Cette mise a jour est obligatoire.'
                        : 'This update is required to continue.',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.burundiRed,
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              if (!forceUpdate)
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(
                    langCode == 'fr' ? 'Plus tard' : 'Later',
                  ),
                ),
              FilledButton.icon(
                onPressed: () {
                  if (storeUrl.isNotEmpty) {
                    final uri = Uri.tryParse(storeUrl);
                    if (uri != null) {
                      launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  }
                },
                icon: const Icon(Icons.download, size: 18),
                label: Text(
                  langCode == 'fr' ? 'Mettre a jour' : 'Update Now',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.burundiGreen,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (_) {
      // Silently fail - update check is non-critical
    }
  }
}
