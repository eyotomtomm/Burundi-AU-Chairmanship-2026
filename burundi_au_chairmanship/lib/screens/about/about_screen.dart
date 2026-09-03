import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_constants.dart';
import '../../config/app_ds.dart';
import '../../l10n/app_localizations.dart';
import '../../services/api_service.dart';
import '../../widgets/ds/ds_widgets.dart';

/// About page: CMS-driven identity, mission, features, credits and contact.
///
/// Every string field below (`_description`, `_summitTheme`, developer
/// details, feature list, contact links) is loaded from `/settings/` and
/// `/about-features/` via [ApiService]; the literals are only the fallback
/// values shown until — or if — that request completes.
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _description = 'Official application for the Be 4 Africa 2026.';
  String _summitTheme = AppConstants.summitTheme;
  String _developerName = 'Eyosias Tamene';
  String _developerUrl = 'https://eyosias.dev';
  String _developerRole = 'Lead Developer';
  String _ownershipText = 'Property of Burundi Embassy in Addis Ababa';
  String _missionTitle = 'Our Mission';
  String _featuresTitle = 'Key Features';
  String _contactWebsite = 'burundi4africa.com';
  String _contactWebsiteUrl = 'https://burundi4africa.com';
  String _contactEmail = 'info@burundi4africa.com';
  List<Map<String, dynamic>>? _aboutFeatures;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadAboutFeatures();
  }

  Future<void> _loadSettings() async {
    // Read the locale before the await so we never touch BuildContext across
    // an async gap.
    final langCode = AppLocalizations.of(context).locale.languageCode;
    try {
      final settings = await ApiService().getSettings();
      if (settings != null && mounted) {
        setState(() {
          if (settings.getDescription(langCode).isNotEmpty) {
            _description = settings.getDescription(langCode);
          }
          if (settings.getTheme(langCode).isNotEmpty) {
            _summitTheme = settings.getTheme(langCode);
          }
          if (settings.developerName.isNotEmpty) {
            _developerName = settings.developerName;
          }
          if (settings.developerUrl.isNotEmpty) {
            _developerUrl = settings.developerUrl;
          }
          if (settings.developerRole.isNotEmpty) {
            _developerRole = settings.developerRole;
          }
          if (settings.appOwnershipText.isNotEmpty) {
            _ownershipText = settings.appOwnershipText;
          }
          _missionTitle = settings.getMissionTitle(langCode);
          _featuresTitle = settings.getFeaturesTitle(langCode);
          if (settings.contactWebsite.isNotEmpty) {
            _contactWebsite = settings.contactWebsite;
          }
          if (settings.contactWebsiteUrl.isNotEmpty) {
            _contactWebsiteUrl = settings.contactWebsiteUrl;
          }
          if (settings.contactEmail.isNotEmpty) {
            _contactEmail = settings.contactEmail;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _loadAboutFeatures() async {
    try {
      final features = await ApiService().getAboutFeatures();
      if (mounted && features.isNotEmpty) {
        setState(() {
          _aboutFeatures = features;
        });
      }
    } catch (_) {}
  }

  static IconData _mapIconName(String iconName) {
    const iconMap = <String, IconData>{
      'article': Icons.article_rounded,
      'event': Icons.event_rounded,
      'auto_stories': Icons.auto_stories_rounded,
      'translate': Icons.translate_rounded,
      'wb_sunny': Icons.wb_sunny_rounded,
      'account_balance': Icons.account_balance_rounded,
      'public': Icons.public_rounded,
      'group': Icons.group_rounded,
      'school': Icons.school_rounded,
      'gavel': Icons.gavel_rounded,
    };
    return iconMap[iconName] ?? Icons.star_rounded;
  }

  static Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return const Color(0xFF1EB53A);
    }
  }

  Future<void> _launch(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Ds.bg(context),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: DsHeader(
              title: l10n.translate('about'),
              large: true,
              bottom: Center(child: _crestLockup(context, l10n)),
            ),
          ),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _summitThemeBanner(context),
                ),
                DsCard(
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  padding: const EdgeInsets.all(20),
                  child: _missionCard(context),
                ),
                DsSectionTitle(_featuresTitle),
                DsTileGroup(children: _featureTiles(context)),
                DsGroupLabel(l10n.translate('about_credits')),
                DsCard(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  padding: const EdgeInsets.all(16),
                  child: _creditsCard(context, l10n),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: _ownershipBanner(context),
                ),
                DsSectionTitle(l10n.translate('contact_us')),
                DsTileGroup(
                  children: [
                    DsTile(
                      icon: Icons.language_rounded,
                      iconTint: Ds.tint(context),
                      iconColor: Ds.green,
                      title: _contactWebsite,
                      chevron: false,
                      trailing: Icon(
                        Icons.open_in_new_rounded,
                        size: 16,
                        color: Ds.muted(context),
                      ),
                      onTap: () => _launch(_contactWebsiteUrl),
                    ),
                    DsTile(
                      icon: Icons.mail_outline_rounded,
                      iconTint: Ds.goldTintOf(context),
                      iconColor: Ds.goldInk,
                      title: _contactEmail,
                      chevron: false,
                      trailing: Icon(
                        Icons.open_in_new_rounded,
                        size: 16,
                        color: Ds.muted(context),
                      ),
                      onTap: () => _launch('mailto:$_contactEmail'),
                    ),
                  ],
                ),
                _footer(context, l10n),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// App icon in a gold ring, the app name, the chairmanship year line and
  /// the build version — the compact, institution-specific replacement for
  /// the old generic star hero.
  Widget _crestLockup(BuildContext context, AppLocalizations l10n) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: Container(
            width: 76,
            height: 76,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Ds.gold, width: 2.5),
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/icons/icon-180.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => Container(
                  color: Colors.white,
                  child: const Icon(
                    Icons.account_balance_rounded,
                    color: Ds.green,
                    size: 32,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          AppConstants.appName,
          style: const TextStyle(
            fontFamily: 'HeatherGreen',
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          l10n.translate('about_chairmanship_year_line'),
          style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.85)),
        ),
        const SizedBox(height: 8),
        Container(
          height: 3,
          width: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Ds.gold, Ds.red]),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'v${AppConstants.appVersion}',
          style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.65)),
        ),
      ],
    );
  }

  Widget _summitThemeBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Ds.goldTintOf(context),
        borderRadius: BorderRadius.circular(Ds.rTile),
      ),
      child: Text(
        _summitTheme,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontStyle: FontStyle.italic,
          fontSize: 13,
          height: 1.4,
          color: Ds.goldInk,
        ),
      ),
    );
  }

  Widget _missionCard(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.flag_rounded, size: 20, color: Ds.green),
            const SizedBox(width: 8),
            Expanded(child: Text(_missionTitle, style: Ds.sectionTitle(context))),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          _description,
          style: Ds.cardBody(context).copyWith(fontSize: 14, height: 1.6),
        ),
      ],
    );
  }

  List<Widget> _featureTiles(BuildContext context) {
    final langCode = AppLocalizations.of(context).locale.languageCode;

    // Use API features if available, otherwise fall back to defaults.
    final List<Map<String, dynamic>> features;
    if (_aboutFeatures != null && _aboutFeatures!.isNotEmpty) {
      features = _aboutFeatures!.map((f) {
        final title = (langCode == 'fr' && (f['title_fr'] as String? ?? '').isNotEmpty)
            ? f['title_fr'] as String
            : f['title'] as String? ?? '';
        return {
          'icon': _mapIconName(f['icon_name'] as String? ?? 'star'),
          'title': title,
          'color': _parseColor(f['color'] as String? ?? '#1EB53A'),
        };
      }).toList();
    } else {
      features = [
        {'icon': Icons.article_rounded, 'title': 'News', 'color': Ds.green},
        {'icon': Icons.event_rounded, 'title': 'Events Calendar', 'color': Ds.red},
        {'icon': Icons.auto_stories_rounded, 'title': 'Magazine', 'color': Ds.gold},
        {'icon': Icons.translate_rounded, 'title': 'Translation', 'color': Ds.green},
        {'icon': Icons.wb_sunny_rounded, 'title': 'Weather', 'color': Ds.gold},
        {'icon': Icons.account_balance_rounded, 'title': 'Diplomacy', 'color': Ds.red},
      ];
    }

    return [
      for (final f in features)
        DsTile(
          icon: f['icon'] as IconData,
          iconTint: (f['color'] as Color).withValues(alpha: 0.12),
          iconColor: f['color'] as Color,
          title: f['title'] as String,
          chevron: false,
        ),
    ];
  }

  Widget _creditsCard(BuildContext context, AppLocalizations l10n) {
    return Column(
      children: [
        Text(l10n.translate('designed_by'), style: Ds.meta(context)),
        const SizedBox(height: 6),
        Semantics(
          button: true,
          link: true,
          label: _developerName,
          child: GestureDetector(
            onTap: () => _launch(_developerUrl),
            child: Text(
              _developerName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Ds.green,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          _developerRole,
          style: Ds.cardBody(context).copyWith(fontStyle: FontStyle.italic),
        ),
      ],
    );
  }

  Widget _ownershipBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Ds.subtle(context),
        borderRadius: BorderRadius.circular(Ds.rTile),
      ),
      child: Text(
        _ownershipText,
        textAlign: TextAlign.center,
        style: Ds.meta(context).copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _footer(BuildContext context, AppLocalizations l10n) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 32 + MediaQuery.paddingOf(context).bottom),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.public_rounded, size: 22, color: Ds.gold),
            const SizedBox(height: 6),
            Text(
              'B4Africa',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Ds.muted(context)),
            ),
            const SizedBox(height: 2),
            Text('v${AppConstants.appVersion}', style: Ds.meta(context)),
          ],
        ),
      ),
    );
  }
}
