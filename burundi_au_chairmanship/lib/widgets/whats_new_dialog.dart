import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_colors.dart';

/// A modal bottom sheet that shows release highlights ("What's New").
///
/// On each app launch the current version is compared to the last version the
/// user has acknowledged (persisted via SharedPreferences).  If different, a
/// beautiful bottom sheet displays hardcoded changelog items with icons.
///
/// Bilingual support: each item has both an English and French title/subtitle.
class WhatsNewDialog {
  static const String _lastSeenVersionKey = 'last_seen_version';

  // ── Changelog Items (hardcoded) ────────────────────────────
  // Add new items at the TOP of this list for each release.

  static const List<_ChangelogItem> _changelog = [
    _ChangelogItem(
      icon: Icons.speed_rounded,
      titleEn: 'Improved Performance',
      titleFr: 'Performance amelioree',
      subtitleEn: 'Faster load times and smoother animations across the app.',
      subtitleFr: 'Temps de chargement plus rapides et animations plus fluides.',
    ),
    _ChangelogItem(
      icon: Icons.event_available_rounded,
      titleEn: 'New Event Registration',
      titleFr: 'Nouvelle inscription aux evenements',
      subtitleEn: 'Register for upcoming AU events directly from the app.',
      subtitleFr: 'Inscrivez-vous aux evenements de l\'UA directement depuis l\'application.',
    ),
    _ChangelogItem(
      icon: Icons.verified_rounded,
      titleEn: 'Badge Verification System',
      titleFr: 'Systeme de verification de badge',
      subtitleEn: 'Request a Gold or Blue verified badge for your profile.',
      subtitleFr: 'Demandez un badge verifie Or ou Bleu pour votre profil.',
    ),
    _ChangelogItem(
      icon: Icons.support_agent_rounded,
      titleEn: 'In-App Support',
      titleFr: 'Support integre',
      subtitleEn: 'Create support tickets and chat with our team.',
      subtitleFr: 'Creez des tickets d\'assistance et discutez avec notre equipe.',
    ),
    _ChangelogItem(
      icon: Icons.bug_report_rounded,
      titleEn: 'Bug Fixes & Stability',
      titleFr: 'Corrections de bugs et stabilite',
      subtitleEn: 'Resolved issues with notifications, login, and content loading.',
      subtitleFr: 'Problemes resolus avec les notifications, la connexion et le chargement du contenu.',
    ),
  ];

  /// Shows the What's New bottom sheet if the user hasn't seen the current version.
  ///
  /// [context] - the BuildContext.
  /// [currentVersion] - the current app version (e.g. "1.0.0").
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

      if (!context.mounted) return;

      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (sheetContext) => _WhatsNewSheet(
          currentVersion: currentVersion,
          langCode: langCode,
          onDismiss: () async {
            // Save current version as seen
            await prefs.setString(_lastSeenVersionKey, currentVersion);
            if (sheetContext.mounted) {
              Navigator.of(sheetContext).pop();
            }
          },
        ),
      );
    } catch (_) {
      // Silently fail - what's new is non-critical
    }
  }
}

// ── Data class for changelog items ───────────────────────────

class _ChangelogItem {
  final IconData icon;
  final String titleEn;
  final String titleFr;
  final String subtitleEn;
  final String subtitleFr;

  const _ChangelogItem({
    required this.icon,
    required this.titleEn,
    required this.titleFr,
    required this.subtitleEn,
    required this.subtitleFr,
  });

  String title(String langCode) => langCode == 'fr' ? titleFr : titleEn;
  String subtitle(String langCode) => langCode == 'fr' ? subtitleFr : subtitleEn;
}

// ── Bottom Sheet Widget ──────────────────────────────────────

class _WhatsNewSheet extends StatelessWidget {
  final String currentVersion;
  final String langCode;
  final VoidCallback onDismiss;

  const _WhatsNewSheet({
    required this.currentVersion,
    required this.langCode,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isFr = langCode == 'fr';
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      constraints: BoxConstraints(maxHeight: screenHeight * 0.82),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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

          const SizedBox(height: 20),

          // App icon
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.burundiGreen, AppColors.auGreen],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.burundiGreen.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.flag_rounded,
              color: Colors.white,
              size: 36,
            ),
          ),

          const SizedBox(height: 16),

          // Title
          Text(
            isFr
                ? 'Nouveautes dans v$currentVersion'
                : "What's New in v$currentVersion",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            isFr
                ? 'Decouvrez les dernieres ameliorations'
                : 'Discover the latest improvements',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),

          const SizedBox(height: 20),

          const Divider(height: 1),

          // Changelog items
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              itemCount: WhatsNewDialog._changelog.length,
              separatorBuilder: (_, _) => const SizedBox(height: 4),
              itemBuilder: (context, index) {
                final item = WhatsNewDialog._changelog[index];
                return _ChangelogTile(
                  item: item,
                  langCode: langCode,
                  isDark: isDark,
                  index: index,
                );
              },
            ),
          ),

          // "Got it" button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: onDismiss,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.burundiGreen,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  isFr ? 'Compris!' : 'Got it!',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),

          // Bottom safe area
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}

// ── Individual changelog tile ────────────────────────────────

class _ChangelogTile extends StatelessWidget {
  final _ChangelogItem item;
  final String langCode;
  final bool isDark;
  final int index;

  const _ChangelogTile({
    required this.item,
    required this.langCode,
    required this.isDark,
    required this.index,
  });

  /// Rotate through a set of accent colors for visual variety.
  static const List<Color> _accentColors = [
    AppColors.burundiGreen,
    AppColors.auGold,
    AppColors.burundiRed,
    AppColors.patternOrange,
    AppColors.info,
  ];

  @override
  Widget build(BuildContext context) {
    final color = _accentColors[index % _accentColors.length];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon circle
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              item.icon,
              color: color,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title(langCode),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.subtitle(langCode),
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
