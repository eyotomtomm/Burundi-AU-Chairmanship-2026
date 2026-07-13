import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_colors.dart';
import '../services/api_service.dart';

/// A modal bottom sheet that shows release highlights ("What's New").
///
/// On each app launch the current version is compared to the last version the
/// user has acknowledged (persisted via SharedPreferences). If different, a
/// beautiful bottom sheet displays changelog items with icons.
///
/// Content is loaded in a two-step strategy:
///   1. First, try fetching `/whats-new/?version=<currentVersion>` from the
///      backend. If it returns a published AppRelease with highlights, those
///      are shown (admins can edit them live from the dashboard).
///   2. If the network call fails, returns nothing, or has no highlights, the
///      hardcoded fallback [_changelog] is used instead.
///
/// Bilingual support: each item has both an English and French title/subtitle.
class WhatsNewDialog {
  static const String _lastSeenVersionKey = 'last_seen_version';

  // ── Changelog Items (hardcoded fallback) ──────────────────────
  // Add new items at the TOP of this list for each release.
  // These are only used if the backend is unreachable or hasn't
  // published a release matching the current app version.

  static const List<_ChangelogItem> _changelog = [
    _ChangelogItem(
      icon: Icons.auto_awesome_rounded,
      titleEn: 'Discover Africa Redesigned',
      titleFr: 'Decouvrir l\'Afrique redesigne',
      subtitleEn: 'Facts and quotes now feature rich African-inspired patterns and vibrant new card designs.',
      subtitleFr: 'Les faits et citations presentent desormais des motifs inspires de l\'Afrique et un design vibrant.',
    ),
    _ChangelogItem(
      icon: Icons.groups_rounded,
      titleEn: 'Continental Dialogue Enhancements',
      titleFr: 'Ameliorations du Dialogue Continental',
      subtitleEn: 'Smoother registration experience with improved scheduling and document handling.',
      subtitleFr: 'Inscription plus fluide avec une meilleure gestion des horaires et des documents.',
    ),
    _ChangelogItem(
      icon: Icons.notifications_off_rounded,
      titleEn: 'Smarter Notifications',
      titleFr: 'Notifications plus intelligentes',
      subtitleEn: 'Dismissed banners stay dismissed. No more repeated announcements cluttering your feed.',
      subtitleFr: 'Les bannieres fermees restent fermees. Fini les annonces repetees qui encombrent votre fil.',
    ),
    _ChangelogItem(
      icon: Icons.speed_rounded,
      titleEn: 'Performance & Stability',
      titleFr: 'Performance et stabilite',
      subtitleEn: 'Faster app launch, improved splash screen timing, and overall smoother experience.',
      subtitleFr: 'Lancement plus rapide, meilleur timing de l\'ecran de demarrage et experience plus fluide.',
    ),
    _ChangelogItem(
      icon: Icons.bug_report_rounded,
      titleEn: 'Bug Fixes',
      titleFr: 'Corrections de bugs',
      subtitleEn: 'Fixed scheduling issues, image loading, and various stability improvements.',
      subtitleFr: 'Correction des problemes de planification, chargement d\'images et ameliorations de stabilite.',
    ),
  ];

  // ── Backend icon name → IconData mapping ─────────────────────
  // Keep in sync with APP_RELEASE_ICON_CHOICES in custom_admin/views.py.
  // Unknown names fall back to Icons.star_rounded so broken rows never crash.
  static const Map<String, IconData> _backendIconMap = {
    'forum_rounded': Icons.forum_rounded,
    'notifications_active_rounded': Icons.notifications_active_rounded,
    'translate_rounded': Icons.translate_rounded,
    'people_alt_rounded': Icons.people_alt_rounded,
    'shield_rounded': Icons.shield_rounded,
    'speed_rounded': Icons.speed_rounded,
    'bug_report_rounded': Icons.bug_report_rounded,
    'event_available_rounded': Icons.event_available_rounded,
    'verified_rounded': Icons.verified_rounded,
    'auto_awesome_rounded': Icons.auto_awesome_rounded,
    'palette_rounded': Icons.palette_rounded,
    'article_rounded': Icons.article_rounded,
    'menu_book_rounded': Icons.menu_book_rounded,
    'play_circle_rounded': Icons.play_circle_rounded,
    'live_tv_rounded': Icons.live_tv_rounded,
    'map_rounded': Icons.map_rounded,
    'support_agent_rounded': Icons.support_agent_rounded,
    'search_rounded': Icons.search_rounded,
    'download_rounded': Icons.download_rounded,
    'dark_mode_rounded': Icons.dark_mode_rounded,
    'accessibility_rounded': Icons.accessibility_rounded,
    'rocket_launch_rounded': Icons.rocket_launch_rounded,
    'star_rounded': Icons.star_rounded,
  };

  /// Shows the What's New bottom sheet if the user hasn't seen the current version.
  ///
  /// [context] - the BuildContext.
  /// [currentVersion] - the current app version (e.g. "1.1.0").
  /// [langCode] - "en" or "fr".
  static Future<void> showIfNeeded({
    required BuildContext context,
    required String currentVersion,
    String langCode = 'en',
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSeen = prefs.getString(_lastSeenVersionKey);

      // Already seen this version → nothing to do
      if (lastSeen == currentVersion) return;

      // Try backend first. On any failure / empty response fall back to
      // the hardcoded list so users always see something after an update.
      List<_ChangelogItem> items = _changelog;
      String? remoteTitleEn;
      String? remoteTitleFr;
      try {
        final remote = await ApiService().get(
          'whats-new/?version=$currentVersion',
        );
        if (remote is Map && remote['release'] is Map) {
          final release = remote['release'] as Map;
          final highlights = (release['highlights'] as List?) ?? const [];
          if (highlights.isNotEmpty) {
            items = highlights.map<_ChangelogItem>((h) {
              final map = h as Map;
              final iconName = (map['icon_name'] as String?) ?? 'star_rounded';
              return _ChangelogItem(
                icon: _backendIconMap[iconName] ?? Icons.star_rounded,
                titleEn: (map['title_en'] as String?) ?? '',
                titleFr: (map['title_fr'] as String?) ?? '',
                subtitleEn: (map['subtitle_en'] as String?) ?? '',
                subtitleFr: (map['subtitle_fr'] as String?) ?? '',
              );
            }).toList();
            remoteTitleEn = release['title'] as String?;
            remoteTitleFr = release['title_fr'] as String?;
          }
        }
      } catch (_) {
        // Network / parse failure → keep the hardcoded fallback list.
      }

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
          items: items,
          remoteTitleEn: remoteTitleEn,
          remoteTitleFr: remoteTitleFr,
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

  String title(String langCode) => langCode == 'fr' && titleFr.isNotEmpty ? titleFr : titleEn;
  String subtitle(String langCode) => langCode == 'fr' && subtitleFr.isNotEmpty ? subtitleFr : subtitleEn;
}

// ── Bottom Sheet Widget ──────────────────────────────────────

class _WhatsNewSheet extends StatelessWidget {
  final String currentVersion;
  final String langCode;
  final List<_ChangelogItem> items;
  final String? remoteTitleEn;
  final String? remoteTitleFr;
  final VoidCallback onDismiss;

  const _WhatsNewSheet({
    required this.currentVersion,
    required this.langCode,
    required this.items,
    required this.remoteTitleEn,
    required this.remoteTitleFr,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isFr = langCode == 'fr';
    final screenHeight = MediaQuery.of(context).size.height;

    // Use backend-provided titles when available, otherwise the built-in
    // bilingual default.
    final String headerTitle;
    if (isFr && (remoteTitleFr?.isNotEmpty ?? false)) {
      headerTitle = remoteTitleFr!;
    } else if (remoteTitleEn?.isNotEmpty ?? false) {
      headerTitle = remoteTitleEn!;
    } else {
      headerTitle = isFr
          ? 'Nouveautes dans v$currentVersion'
          : "What's New in v$currentVersion";
    }

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
            headerTitle,
            textAlign: TextAlign.center,
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
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 4),
              itemBuilder: (context, index) {
                final item = items[index];
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
