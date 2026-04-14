import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../../services/api_service.dart';
import '../../../config/app_colors.dart';
import '../../../config/environment.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/login_gate.dart';
import '../../../widgets/shimmer_loading.dart';

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
    final l10n = AppLocalizations.of(context);
    final isAuth = context.watch<AuthProvider>().isAuthenticated;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          HapticFeedback.mediumImpact();
          await _loadAgendas();
        },
        color: AppColors.burundiGreen,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            // Gradient app bar — matches magazine/weather style
            SliverAppBar(
              expandedHeight: 120,
              pinned: true,
              automaticallyImplyLeading: false,
              foregroundColor: Colors.white,
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  l10n.translate('priority_agenda'),
                  style: const TextStyle(
                    fontFamily: 'HeatherGreen',
                    fontSize: 20,
                    color: Colors.white,
                  ),
                ),
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.burundiGreen, Color(0xFF065A1A)],
                    ),
                  ),
                ),
              ),
            ),

            // Loading or content
            if (_isLoading)
              const SliverToBoxAdapter(
                child: ShimmerAgendaListSkeleton(),
              )
            else if (_agendas == null || _agendas!.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Text(
                    l10n.translate('no_data'),
                    style: TextStyle(
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ),
              )
            else
              // Agenda cards from API (gated for guests: 1 free + banner + 2 blurred)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final slot = LoginGate.slotFor(
                        index: index,
                        actualCount: _agendas!.length,
                        isAuthenticated: isAuth,
                        freeItems: LoginGate.agendaFreeItems,
                      );

                      Widget buildCardFor(int dataIndex) {
                        final agenda = _agendas![dataIndex];
                        String rawTitle = langCode == 'fr' && agenda['title_fr'] != null && (agenda['title_fr'] as String).isNotEmpty
                            ? agenda['title_fr'] as String
                            : agenda['title'] as String;
                        if (rawTitle.contains('_') || rawTitle.contains('-')) {
                          rawTitle = rawTitle.replaceAll('_', ' ').replaceAll('-', ' ');
                          rawTitle = rawTitle.split(' ').map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : w).join(' ');
                        }
                        final title = rawTitle;
                        final description = langCode == 'fr' && agenda['description_fr'] != null && (agenda['description_fr'] as String).isNotEmpty
                            ? agenda['description_fr'] as String
                            : agenda['description'] as String;
                        final slug = agenda['slug'] as String;
                        final iconName = agenda['icon_name'] as String? ?? 'star';
                        final icon = _getIconFromName(iconName);
                        final color = _getColorForSlug(slug);
                        final heroImage = agenda['hero_image'];

                        return _buildAgendaCard(
                          context: context,
                          title: title,
                          subtitle: description,
                          icon: icon,
                          color: color,
                          isDark: isDark,
                          heroImage: heroImage,
                          onTap: () => Navigator.pushNamed(context, '/$slug'),
                        );
                      }

                      switch (slot) {
                        case LoginGateSlot.free:
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: buildCardFor(index),
                          );
                        case LoginGateSlot.banner:
                          return const LoginGateBanner(
                            margin: EdgeInsets.only(bottom: 16),
                          );
                        case LoginGateSlot.blurred:
                          final dataIndex = LoginGate.dataIndexFor(index, LoginGate.agendaFreeItems);
                          if (dataIndex == null || dataIndex >= _agendas!.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: LockedContentWrap(
                              locked: true,
                              borderRadius: const BorderRadius.all(Radius.circular(24)),
                              child: buildCardFor(dataIndex),
                            ),
                          );
                        case LoginGateSlot.hidden:
                          return const SizedBox.shrink();
                      }
                    },
                    childCount: LoginGate.itemCountFor(
                      actualCount: _agendas!.length,
                      isAuthenticated: isAuth,
                      freeItems: LoginGate.agendaFreeItems,
                    ),
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
