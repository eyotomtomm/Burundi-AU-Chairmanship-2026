import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/app_colors.dart';
import '../config/environment.dart';

class PriorityAgendaDetailScreen extends StatelessWidget {
  final Map<String, dynamic> agenda;

  const PriorityAgendaDetailScreen({
    super.key,
    required this.agenda,
  });

  @override
  Widget build(BuildContext context) {
    final langCode = Localizations.localeOf(context).languageCode;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
      body: CustomScrollView(
        slivers: [
          // Hero Header
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            backgroundColor: AppColors.burundiGreen,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                title.isNotEmpty ? title : 'Priority Agenda',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Hero Image or Gradient
                  if (hasHeroImage)
                    CachedNetworkImage(
                      imageUrl: Environment.fixMediaUrl(heroImage.toString()),
                      memCacheWidth: 800,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.burundiGreen,
                              AppColors.burundiGreen.withValues(alpha: 0.8),
                            ],
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.burundiGreen,
                              AppColors.burundiGreen.withValues(alpha: 0.8),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.burundiGreen,
                            AppColors.burundiGreen.withValues(alpha: 0.8),
                          ],
                        ),
                      ),
                    ),

                  // Dark overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Content
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Description
                if (description != null && description.isNotEmpty) ...[
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.6,
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Overview Section
                if (overview != null && overview.isNotEmpty) ...[
                  _buildSectionTitle(langCode == 'fr' ? 'Aperçu' : 'Overview', isDark),
                  const SizedBox(height: 12),
                  Text(
                    overview,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.6,
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Key Objectives Section
                if (objectives != null && objectives is List && objectives.isNotEmpty) ...[
                  _buildSectionTitle(langCode == 'fr' ? 'Objectifs Clés' : 'Key Objectives', isDark),
                  const SizedBox(height: 12),
                  ...objectives.map<Widget>((objective) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 6),
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppColors.burundiGreen,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              objective.toString(),
                              style: TextStyle(
                                fontSize: 15,
                                height: 1.5,
                                color: isDark ? AppColors.darkText : AppColors.lightText,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 24),
                ],

                // Impact Areas Section
                if (impactAreas != null && impactAreas is List && impactAreas.isNotEmpty) ...[
                  _buildSectionTitle(langCode == 'fr' ? 'Domaines d\'Impact' : 'Impact Areas', isDark),
                  const SizedBox(height: 12),
                  ...impactAreas.map<Widget>((area) {
                    if (area is! Map) return const SizedBox.shrink();
                    return _buildImpactAreaCard(
                      area['title']?.toString() ?? '',
                      area['description']?.toString() ?? '',
                      area['icon']?.toString() ?? 'star',
                      isDark,
                    );
                  }),
                  const SizedBox(height: 24),
                ],

                // Current Initiatives Section
                if (currentInitiatives != null && currentInitiatives.toString().isNotEmpty) ...[
                  _buildSectionTitle(langCode == 'fr' ? 'Initiatives en Cours' : 'Current Initiatives', isDark),
                  const SizedBox(height: 12),
                  Text(
                    currentInitiatives.toString(),
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.6,
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: isDark ? AppColors.darkText : AppColors.lightText,
      ),
    );
  }

  Widget _buildImpactAreaCard(String title, String description, String iconName, bool isDark) {
    final icon = _getIconData(iconName);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.grey[850]
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.grey[700]!
              : Colors.grey[300]!,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.burundiGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: AppColors.burundiGreen,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
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
