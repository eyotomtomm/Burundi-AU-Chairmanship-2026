import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../services/api_service.dart';
import '../../../config/app_colors.dart';
import '../../../config/environment.dart';
import '../../../l10n/app_localizations.dart';

class AgendaTab extends StatefulWidget {
  const AgendaTab({super.key});

  @override
  State<AgendaTab> createState() => _AgendaTabState();
}

class _AgendaTabState extends State<AgendaTab> {
  List<Map<String, dynamic>>? _agendas;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAgendas();
  }

  Future<void> _loadAgendas() async {
    try {
      final api = ApiService();
      final agendas = await api.getPriorityAgendas();
      if (mounted) {
        setState(() {
          _agendas = agendas;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Map icon names from API to Flutter icons
  IconData _getIconFromName(String iconName) {
    final iconMap = {
      'water_drop': Icons.water_drop_rounded,
      'trending_up': Icons.trending_up_rounded,
      'security': Icons.security_rounded,
      'health_and_safety': Icons.health_and_safety_rounded,
      'agriculture': Icons.agriculture_rounded,
      'school': Icons.school_rounded,
      'business': Icons.business_rounded,
      'groups': Icons.groups_rounded,
    };
    return iconMap[iconName] ?? Icons.star_rounded;
  }

  // Map slugs to colors for fallback
  Color _getColorForSlug(String slug) {
    final colorMap = {
      'water-sanitation': const Color(0xFF0077B6),
      'arise-initiative': const Color(0xFFB8860B),
      'peace-security': const Color(0xFF1B5E20),
    };
    return colorMap[slug] ?? AppColors.burundiGreen;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final langCode = Localizations.localeOf(context).languageCode;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA),
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.translate('priority_agenda') ?? 'Priority Agenda',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Burundi\'s AU Chairmanship 2026',
                      style: TextStyle(
                        fontSize: 15,
                        color: isDark ? Colors.white60 : Colors.black45,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Loading or content
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_agendas == null || _agendas!.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Text(
                    l10n.translate('no_data') ?? 'No agendas available',
                    style: TextStyle(
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ),
              )
            else
              // Agenda cards from API
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final agenda = _agendas![index];
                      final title = langCode == 'fr' && agenda['title_fr'] != null && (agenda['title_fr'] as String).isNotEmpty
                          ? agenda['title_fr'] as String
                          : agenda['title'] as String;
                      final description = langCode == 'fr' && agenda['description_fr'] != null && (agenda['description_fr'] as String).isNotEmpty
                          ? agenda['description_fr'] as String
                          : agenda['description'] as String;
                      final slug = agenda['slug'] as String;
                      final iconName = agenda['icon_name'] as String? ?? 'star';
                      final icon = _getIconFromName(iconName);
                      final color = _getColorForSlug(slug);
                      final heroImage = agenda['hero_image'];

                      return Padding(
                        padding: EdgeInsets.only(bottom: index < _agendas!.length - 1 ? 16 : 0),
                        child: _buildAgendaCard(
                          context: context,
                          title: title,
                          subtitle: description,
                          icon: icon,
                          color: color,
                          isDark: isDark,
                          heroImage: heroImage,
                          onTap: () {
                            // Navigate to detail page using slug
                            Navigator.pushNamed(context, '/$slug');
                          },
                        ),
                      );
                    },
                    childCount: _agendas!.length,
                  ),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  Widget _buildAgendaCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
    String? heroImage,
    required VoidCallback onTap,
  }) {
    final hasImage = heroImage != null && heroImage.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.4)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon or image
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: hasImage ? Colors.transparent : color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: hasImage
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: CachedNetworkImage(
                        imageUrl: Environment.fixMediaUrl(heroImage),
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: color.withValues(alpha: 0.12),
                          child: Icon(icon, color: color, size: 28),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: color.withValues(alpha: 0.12),
                          child: Icon(icon, color: color, size: 28),
                        ),
                      ),
                    )
                  : Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 18,
              color: isDark ? Colors.white30 : Colors.black26,
            ),
          ],
        ),
      ),
    );
  }
}
