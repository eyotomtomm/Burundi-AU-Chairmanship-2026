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
///
/// The page holds to one accent. Green carries every interactive and iconic
/// element; gold appears exactly once, as the rule under the wordmark. The
/// feature list used to give each row its own colour, which turned the page
/// into a swatch board and left nothing for the eye to rank.
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _description =
      'The official application of the Republic of Burundi\u2019s African Union '
      'Chairmanship — carrying the summit\u2019s news, events, publications and '
      'the voices of the young Africans shaping its agenda.';
  String _summitTheme = AppConstants.summitTheme;
  String _developerName = 'Eyosias Tamene';
  String _developerUrl = 'https://eyosias.dev';
  String _developerRole = 'Lead Developer';
  String _ownershipText = 'Embassy of the Republic of Burundi in Addis Ababa';
  String _missionTitle = 'Our Mission';
  String _featuresTitle = 'Key Features';
  String _contactWebsite = 'burundi4africa.com';
  String _contactWebsiteUrl = 'https://burundi4africa.com';
  String _contactEmail = 'info@burundichairship.africa';
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

  /// Map icon_name strings from the API to Material icons.
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
      'forum': Icons.forum_rounded,
      'photo_library': Icons.photo_library_rounded,
      'live_tv': Icons.live_tv_rounded,
    };
    return iconMap[iconName] ?? Icons.star_rounded;
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
            child: DsHeader(title: l10n.translate('about'), large: true),
          ),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _wordmarkCard(context, l10n),
                _themeQuote(context),
                DsSectionTitle(_missionTitle),
                DsCard(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    _description,
                    style: Ds.cardBody(context).copyWith(fontSize: 14.5, height: 1.65),
                  ),
                ),
                DsSectionTitle(_featuresTitle),
                _featureGrid(context),
                DsSectionTitle(l10n.translate('about_issued_by')),
                _issuedByCard(context),
                _credits(context, l10n),
                DsSectionTitle(l10n.translate('contact_us')),
                DsTileGroup(
                  children: [
                    DsTile(
                      icon: Icons.language_rounded,
                      iconTint: Ds.tint(context),
                      iconColor: Ds.green,
                      title: _contactWebsite,
                      chevron: false,
                      trailing: Icon(Icons.open_in_new_rounded,
                          size: 16, color: Ds.muted(context)),
                      onTap: () => _launch(_contactWebsiteUrl),
                    ),
                    DsTile(
                      icon: Icons.mail_outline_rounded,
                      iconTint: Ds.tint(context),
                      iconColor: Ds.green,
                      title: _contactEmail,
                      chevron: false,
                      trailing: Icon(Icons.open_in_new_rounded,
                          size: 16, color: Ds.muted(context)),
                      onTap: () => _launch('mailto:$_contactEmail'),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The identity block: the real B4Africa wordmark rather than the app icon,
  /// the chairmanship line, and the version. The single gold rule is the only
  /// place gold appears on the page.
  Widget _wordmarkCard(BuildContext context, AppLocalizations l10n) {
    return DsCard(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      child: Column(
        children: [
          // The artwork is drawn on white, so it keeps its own plate in dark
          // mode instead of sitting on a dark card.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(Ds.rTile),
            ),
            child: Image.asset(
              'assets/images/b4africa_logo.png',
              height: 40,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => Text(
                AppConstants.appName,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Ds.green,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Chairmanship line and version share one row — two stacked bands
          // with a rule between them was three times the height for the same
          // two facts.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  l10n.translate('about_chairmanship_year_line'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                    color: Ds.body(context),
                  ),
                ),
              ),
              Container(
                width: 3,
                height: 3,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: const BoxDecoration(
                  color: Ds.gold,
                  shape: BoxShape.circle,
                ),
              ),
              Text('v${AppConstants.appVersion}', style: Ds.meta(context)),
            ],
          ),
        ],
      ),
    );
  }

  /// The summit theme as a pull quote. It used to be a cream-on-gold banner,
  /// which competed with the wordmark directly above it for attention.
  Widget _themeQuote(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: Ds.green, width: 3)),
      ),
      child: Text(
        _summitTheme,
        style: TextStyle(
          fontSize: 15,
          height: 1.5,
          fontStyle: FontStyle.italic,
          fontWeight: FontWeight.w500,
          color: Ds.ink(context),
        ),
      ),
    );
  }

  /// Two-column grid, one icon treatment throughout. The API still drives the
  /// list and the icons; its per-feature `color` is deliberately ignored.
  Widget _featureGrid(BuildContext context) {
    final langCode = AppLocalizations.of(context).locale.languageCode;

    final List<Map<String, dynamic>> features;
    if (_aboutFeatures != null && _aboutFeatures!.isNotEmpty) {
      features = _aboutFeatures!.map((f) {
        final title = (langCode == 'fr' && (f['title_fr'] as String? ?? '').isNotEmpty)
            ? f['title_fr'] as String
            : f['title'] as String? ?? '';
        return {
          'icon': _mapIconName(f['icon_name'] as String? ?? 'star'),
          'title': title,
        };
      }).toList();
    } else {
      final l10n = AppLocalizations.of(context);
      features = [
        {'icon': Icons.article_rounded, 'title': l10n.translate('news')},
        {'icon': Icons.event_rounded, 'title': l10n.translate('events')},
        {'icon': Icons.auto_stories_rounded, 'title': l10n.translate('magazine')},
        {'icon': Icons.forum_rounded, 'title': l10n.translate('explore')},
        {'icon': Icons.translate_rounded, 'title': l10n.translate('translate')},
        {'icon': Icons.photo_library_rounded, 'title': l10n.translate('gallery')},
      ];
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const gap = 10.0;
          final width = (constraints.maxWidth - gap) / 2;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final f in features)
                SizedBox(
                  width: width,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                    decoration: BoxDecoration(
                      color: Ds.surface(context),
                      borderRadius: BorderRadius.circular(Ds.rTile),
                      border: Border.all(color: Ds.hairline(context)),
                    ),
                    child: Row(
                      children: [
                        Icon(f['icon'] as IconData, size: 20, color: Ds.green),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            f['title'] as String,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              height: 1.25,
                              color: Ds.ink(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  /// The Embassy seal and the ownership line. This is the page's institutional
  /// signature, so it gets a block of its own rather than a grey strip.
  Widget _issuedByCard(BuildContext context) {
    return DsCard(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Image.asset(
              'assets/images/Burundi Embassy in Addis Ababa.png',
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Icon(
                Icons.account_balance_rounded,
                color: Ds.green,
                size: 28,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              _ownershipText,
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                fontWeight: FontWeight.w600,
                color: Ds.ink(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Author credit. A tappable card rather than a line of footer text — the
  /// name and its link are attribution, not fine print.
  Widget _credits(BuildContext context, AppLocalizations l10n) {
    final initials = _developerName
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Semantics(
        button: true,
        link: true,
        label: '$_developerName, $_developerRole',
        child: Material(
          color: Ds.surface(context),
          borderRadius: BorderRadius.circular(Ds.rCard),
          child: InkWell(
            borderRadius: BorderRadius.circular(Ds.rCard),
            onTap: () => _launch(_developerUrl),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Ds.greenDeep, Ds.green],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Text(
                      initials.isEmpty ? '·' : initials,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.translate('designed_by').toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.9,
                            color: Ds.muted(context),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _developerName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                            color: Ds.ink(context),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(_developerRole, style: Ds.meta(context)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.open_in_new_rounded, size: 17, color: Ds.green),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
