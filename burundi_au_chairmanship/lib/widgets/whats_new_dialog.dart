import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_ds.dart';
import 'ds/ds_widgets.dart';
import '../services/api_service.dart';
import '../l10n/app_localizations.dart';

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
      icon: Icons.palette_rounded,
      titleEn: 'A brand new look',
      titleFr: 'Un tout nouveau look',
      subtitleEn: 'Every screen has been redesigned around the 2026 chairmanship identity — new colours, cards and typography throughout.',
      subtitleFr: "Chaque ecran a ete redessine autour de l'identite de la presidence 2026 — nouvelles couleurs, cartes et typographie.",
    ),
    _ChangelogItem(
      icon: Icons.home_rounded,
      titleEn: 'A home screen that keeps up',
      titleFr: 'Un accueil toujours a jour',
      subtitleEn: 'New today brings live streams, the latest news and upcoming events together — every card opens the real thing.',
      subtitleFr: "Nouveautes reunit les directs, les dernieres actualites et les evenements a venir — chaque carte ouvre le contenu.",
    ),
    _ChangelogItem(
      icon: Icons.explore_rounded,
      titleEn: 'Discover Burundi & Africa',
      titleFr: "Decouvrir le Burundi et l'Afrique",
      subtitleEn: 'Both Discover sections now open rich photo pages with the story, key facts and initiatives behind them.',
      subtitleFr: "Les deux sections Decouvrir ouvrent des pages illustrees avec le recit, les faits cles et les initiatives.",
    ),
    _ChangelogItem(
      icon: Icons.translate_rounded,
      titleEn: 'A clearer phrasebook',
      titleFr: 'Un guide de conversation plus clair',
      subtitleEn: 'Each phrase now shows your language and the Kirundi to say out loud — tap any phrase to copy it.',
      subtitleFr: 'Chaque phrase affiche votre langue et le kirundi a prononcer — appuyez pour copier.',
    ),
    _ChangelogItem(
      icon: Icons.speed_rounded,
      titleEn: 'Faster and steadier',
      titleFr: 'Plus rapide et plus stable',
      subtitleEn: 'Lighter screens, fewer stalls, and fixes to sharing, deep links and image loading.',
      subtitleFr: "Ecrans plus legers, moins de blocages, et corrections du partage, des liens et du chargement d'images.",
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
    final bool isFr = langCode == 'fr';
    final screenHeight = MediaQuery.of(context).size.height;

    final String headerTitle;
    if (isFr && (remoteTitleFr?.isNotEmpty ?? false)) {
      headerTitle = remoteTitleFr!;
    } else if (remoteTitleEn?.isNotEmpty ?? false) {
      headerTitle = remoteTitleEn!;
    } else {
      headerTitle = AppLocalizations.of(context).translate('whats_new');
    }

    return Container(
      constraints: BoxConstraints(maxHeight: screenHeight * 0.86),
      decoration: BoxDecoration(
        color: Ds.bg(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Green header, same treatment as every screen in the app.
          Container(
            width: double.infinity,
            color: Ds.green,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: Ds.gold,
                    borderRadius: BorderRadius.circular(Ds.rPill),
                  ),
                  child: Text(
                    'VERSION $currentVersion',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      color: Ds.goldInkDeep,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  headerTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  AppLocalizations.of(context).translate('w_whats_new_sub'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),

          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) => _ChangelogTile(
                item: items[index],
                langCode: langCode,
                isDark: Theme.of(context).brightness == Brightness.dark,
                index: index,
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: DsPrimaryButton(
              AppLocalizations.of(context).translate('got_it'),
              radius: 14,
              onTap: onDismiss,
            ),
          ),
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

  @override
  Widget build(BuildContext context) {
    return DsCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DsIconSquare(item.icon,
              tint: Ds.tint(context), color: Ds.green, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title(langCode),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Ds.ink(context),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.subtitle(langCode),
                  style: TextStyle(
                      fontSize: 13, height: 1.45, color: Ds.body(context)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
