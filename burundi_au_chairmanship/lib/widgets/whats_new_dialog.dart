import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_colors.dart';
import '../services/api_service.dart';

/// A bottom sheet that shows latest release notes ("What's New").
///
/// Fetches from `/api/whats-new/` and displays once per version update,
/// storing the last seen version in SharedPreferences.
class WhatsNewDialog {
  static const String _lastSeenVersionKey = 'whats_new_last_seen_version';

  /// Shows the What's New bottom sheet if the user hasn't seen the current version.
  ///
  /// [context] - the BuildContext.
  /// [currentVersion] - the current app version.
  /// [langCode] - "en" or "fr".
  static Future<void> showIfNeeded({
    required BuildContext context,
    required String currentVersion,
    String langCode = 'en',
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSeen = prefs.getString(_lastSeenVersionKey);

      // Already seen this version
      if (lastSeen == currentVersion) return;

      final api = ApiService();
      final items = await api.getWhatsNew();

      if (items.isEmpty) return;
      if (!context.mounted) return;

      // Mark as seen
      await prefs.setString(_lastSeenVersionKey, currentVersion);

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (sheetContext) => DraggableScrollableSheet(
          initialChildSize: 0.55,
          minChildSize: 0.3,
          maxChildSize: 0.85,
          expand: false,
          builder: (_, scrollController) => _WhatsNewContent(
            items: items,
            langCode: langCode,
            scrollController: scrollController,
          ),
        ),
      );
    } catch (_) {
      // Silently fail - what's new is non-critical
    }
  }
}

class _WhatsNewContent extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final String langCode;
  final ScrollController scrollController;

  const _WhatsNewContent({
    required this.items,
    required this.langCode,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                const Icon(Icons.new_releases, color: AppColors.burundiGreen),
                const SizedBox(width: 10),
                Text(
                  langCode == 'fr' ? 'Nouveautes' : "What's New",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          // Content
          Expanded(
            child: ListView.separated(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(height: 24),
              itemBuilder: (context, index) {
                final item = items[index];
                final version = item['version'] ?? '';
                final date = item['date'] ?? '';
                final title = langCode == 'fr'
                    ? (item['title_fr'] ?? item['title'] ?? '')
                    : (item['title'] ?? '');
                final changelog = langCode == 'fr'
                    ? (item['changelog_fr'] ?? item['changelog'] ?? '')
                    : (item['changelog'] ?? '');

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.burundiGreen.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'v$version',
                            style: const TextStyle(
                              color: AppColors.burundiGreen,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          date,
                          style: TextStyle(
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    if (title.toString().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        title.toString(),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (changelog.toString().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        changelog.toString(),
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
