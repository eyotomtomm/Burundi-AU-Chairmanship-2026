import 'package:flutter/material.dart';
import '../config/app_ds.dart';
import '../widgets/ds/ds_widgets.dart';
import '../config/environment.dart';
import '../widgets/app_network_image.dart';
import '../l10n/app_localizations.dart';

class PriorityAgendaDetailScreen extends StatelessWidget {
  final Map<String, dynamic> agenda;

  const PriorityAgendaDetailScreen({
    super.key,
    required this.agenda,
  });

  @override
  Widget build(BuildContext context) {
    final langCode = Localizations.localeOf(context).languageCode;

    // Format title: replace underscores/hyphens with spaces and capitalize properly
    String rawTitle = langCode == 'fr'
        ? (agenda['title_fr'] ?? agenda['title'] ?? '')
        : (agenda['title'] ?? '');
    if (rawTitle.contains('_') || rawTitle.contains('-')) {
      rawTitle = rawTitle.replaceAll('_', ' ').replaceAll('-', ' ');
      rawTitle = rawTitle.split(' ').map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : w).join(' ');
    }
    final title = rawTitle;
    final description = langCode == 'fr'
        ? (agenda['description_fr'] ?? agenda['description'])
        : agenda['description'];
    final overview = langCode == 'fr'
        ? (agenda['overview_fr'] ?? agenda['overview'])
        : agenda['overview'];
    final objectives = langCode == 'fr'
        ? (agenda['objectives_fr'] ?? agenda['objectives'])
        : agenda['objectives'];
    final impactAreas = langCode == 'fr'
        ? (agenda['impact_areas_fr'] ?? agenda['impact_areas'])
        : agenda['impact_areas'];
    final currentInitiatives = langCode == 'fr'
        ? (agenda['current_initiatives_fr'] ?? agenda['current_initiatives'])
        : agenda['current_initiatives'];

    final heroImage = agenda['hero_image'];
    final hasHeroImage = heroImage != null && heroImage.toString().isNotEmpty;

    return Scaffold(
      backgroundColor: Ds.bg(context),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _buildHeader(context, title, description, heroImage, hasHeroImage, langCode),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(0, 16, 0, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (overview != null && overview.toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
                    child: Text(
                      overview.toString(),
                      style: TextStyle(
                          fontSize: 14, height: 1.65, color: Ds.body(context)),
                    ),
                  ),

                if (objectives != null && objectives is List && objectives.isNotEmpty) ...[
                  _sectionHeading(context,
                      langCode == 'fr' ? 'Objectifs clés' : 'Key objectives'),
                  ...objectives.map<Widget>((objective) => Padding(
                        padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 7),
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                  color: Ds.green, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                objective.toString(),
                                style: TextStyle(
                                    fontSize: 14,
                                    height: 1.55,
                                    color: Ds.body(context)),
                              ),
                            ),
                          ],
                        ),
                      )),
                  const SizedBox(height: 6),
                ],

                if (impactAreas != null && impactAreas is List && impactAreas.isNotEmpty) ...[
                  _sectionHeading(
                      context,
                      langCode == 'fr'
                          ? 'Initiatives clés'
                          : 'Key initiatives'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        for (final area in impactAreas)
                          if (area is Map)
                            _buildInitiativeCard(
                              context,
                              area['title']?.toString() ?? '',
                              area['description']?.toString() ?? '',
                              area['icon']?.toString() ?? 'star',
                            ),
                      ],
                    ),
                  ),
                ],

                if (currentInitiatives != null &&
                    currentInitiatives.toString().isNotEmpty) ...[
                  _sectionHeading(
                      context,
                      langCode == 'fr'
                          ? 'Initiatives en cours'
                          : 'Current initiatives'),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 0, 22, 0),
                    child: Text(
                      currentInitiatives.toString(),
                      style: TextStyle(
                          fontSize: 14, height: 1.65, color: Ds.body(context)),
                    ),
                  ),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String title, dynamic description,
      dynamic heroImage, bool hasHeroImage, String langCode) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
          20, MediaQuery.paddingOf(context).top + 20, 20, 24),
      decoration: const BoxDecoration(
        color: Ds.green,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(Ds.rHeader)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Semantics(
                button: true,
                label: MaterialLocalizations.of(context).backButtonTooltip,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.maybePop(context),
                  child: const SizedBox(
                    width: 30,
                    height: 36,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Icon(Icons.arrow_back_rounded,
                          size: 22, color: Colors.white),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  langCode == 'fr' ? 'NOTRE AGENDA' : 'OUR AGENDA',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                      color: Colors.white.withValues(alpha: 0.8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(Ds.rCard),
                ),
                child: hasHeroImage
                    ? AppNetworkImage(
                        imageUrl: Environment.fixMediaUrl(heroImage.toString()),
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) => const Icon(Icons.flag_rounded,
                            size: 28, color: Colors.white),
                      )
                    : const Icon(Icons.flag_rounded, size: 28, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.isNotEmpty ? title : AppLocalizations.of(context).translate('priority_agenda'),
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          color: Colors.white),
                    ),
                    if (description != null && description.toString().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        description.toString(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.85)),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionHeading(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 10),
        child: Text(title,
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w800, color: Ds.ink(context))),
      );

  Widget _buildInitiativeCard(
      BuildContext context, String title, String description, String iconName) {
    return DsCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          DsIconSquare(_getIconData(iconName),
              tint: Ds.blueTint, color: Ds.blue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Ds.cardTitle(context)),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(description, style: Ds.cardBody(context)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconData(String iconName) {
    final iconMap = {
      'stars': Icons.stars,
      'travel_explore': Icons.travel_explore,
      'public': Icons.public,
      'security': Icons.security,
      'groups': Icons.groups,
      'gavel': Icons.gavel,
      'handshake': Icons.handshake,
      'trending_up': Icons.trending_up,
      'auto_stories': Icons.auto_stories,
      'campaign': Icons.campaign,
      'flag': Icons.flag,
      'workspace_premium': Icons.workspace_premium,
      'landscape': Icons.landscape,
      'music_note': Icons.music_note,
      'restaurant': Icons.restaurant,
      'diversity_3': Icons.diversity_3,
      'water_drop': Icons.water_drop,
      'health_and_safety': Icons.health_and_safety,
      'school': Icons.school,
      'agriculture': Icons.agriculture,
      'business': Icons.business,
      'computer': Icons.computer,
      'factory': Icons.factory,
      'local_shipping': Icons.local_shipping,
    };

    return iconMap[iconName] ?? Icons.star;
  }
}
