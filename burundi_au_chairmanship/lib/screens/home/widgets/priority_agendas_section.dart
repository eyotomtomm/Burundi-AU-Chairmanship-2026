import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../config/app_colors.dart';
import '../../../config/environment.dart';
import '../../../widgets/login_gate.dart';

class PriorityAgendasSection extends StatelessWidget {
  final List<Map<String, dynamic>> agendas;
  final bool isAuthenticated;
  final String langCode;

  const PriorityAgendasSection({
    super.key,
    required this.agendas,
    required this.isAuthenticated,
    required this.langCode,
  });

  static const Map<String, List<Color>> _slugColors = {
    'water-sanitation': [Color(0xFF0077B6), Color(0xFF00B4D8)],
    'arise-initiative': [Color(0xFFB8860B), Color(0xFFDAA520)],
    'peace-security': [Color(0xFF1B5E20), Color(0xFF2E7D32)],
  };

  static const Map<String, Map<String, String>> _slugLabels = {
    'water-sanitation': {'en': 'SDG 6', 'fr': 'ODD 6', 'icon_label': 'water_drop'},
    'arise-initiative': {'en': 'AU 2063', 'fr': 'UA 2063', 'icon_label': 'trending_up'},
    'peace-security': {'en': 'APSA', 'fr': 'AAPS', 'icon_label': 'shield'},
  };

  @override
  Widget build(BuildContext context) {
    final totalCount = LoginGate.itemCountFor(
      actualCount: agendas.length,
      isAuthenticated: isAuthenticated,
      freeItems: LoginGate.agendaFreeItems,
    );

    return Column(
      children: List.generate(totalCount, (index) {
        final slot = LoginGate.slotFor(
          index: index,
          actualCount: agendas.length,
          isAuthenticated: isAuthenticated,
          freeItems: LoginGate.agendaFreeItems,
        );
        switch (slot) {
          case LoginGateSlot.free:
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _buildAgendaCard(context, agendas[index]),
            );
          case LoginGateSlot.banner:
            return const LoginGateBanner(
              margin: EdgeInsets.only(bottom: 14),
            );
          case LoginGateSlot.blurred:
            final dataIndex = LoginGate.dataIndexFor(index, LoginGate.agendaFreeItems);
            if (dataIndex == null || dataIndex >= agendas.length) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: LockedContentWrap(
                locked: true,
                borderRadius: const BorderRadius.all(Radius.circular(18)),
                child: _buildAgendaCard(context, agendas[dataIndex]),
              ),
            );
          case LoginGateSlot.hidden:
            return const SizedBox.shrink();
        }
      }),
    );
  }

  Widget _buildAgendaCard(BuildContext context, Map<String, dynamic> agenda) {
    final slug = agenda['slug'] as String?;
    final title = langCode == 'fr' ? (agenda['title_fr'] ?? agenda['title']) : agenda['title'];
    final description = langCode == 'fr' ? (agenda['description_fr'] ?? agenda['description']) : agenda['description'];
    final heroImage = agenda['hero_image'];
    final hasImage = heroImage != null && heroImage.toString().isNotEmpty;
    final fallbackColors = (slug != null && _slugColors.containsKey(slug))
        ? _slugColors[slug]!
        : [AppColors.burundiGreen, AppColors.auGold];
    final label = (slug != null && _slugLabels.containsKey(slug))
        ? (langCode == 'fr' ? _slugLabels[slug]!['fr']! : _slugLabels[slug]!['en']!)
        : '';

    return InkWell(
      onTap: () {
        final agendaSlug = agenda['slug'] as String?;
        if (agendaSlug != null) {
          Navigator.pushNamed(context, '/$agendaSlug');
        }
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: fallbackColors[0].withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: fallbackColors[1].withValues(alpha: 0.15),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background
              if (hasImage)
                CachedNetworkImage(
                  imageUrl: Environment.fixMediaUrl(heroImage.toString()),
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: fallbackColors,
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: fallbackColors,
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
                        fallbackColors[0],
                        Color.lerp(fallbackColors[0], fallbackColors[1], 0.5)!,
                        fallbackColors[1],
                      ],
                      stops: const [0.0, 0.6, 1.0],
                    ),
                  ),
                ),

              // Color-tinted overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [
                      fallbackColors[0].withValues(alpha: hasImage ? 0.5 : 0.15),
                      Colors.black.withValues(alpha: hasImage ? 0.55 : 0.25),
                    ],
                  ),
                ),
              ),

              // Glossy shimmer
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: const Alignment(-1.0, -1.0),
                        end: const Alignment(0.0, 0.0),
                        colors: [
                          Colors.white.withValues(alpha: 0.12),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Badge label
              if (label.isNotEmpty)
                Positioned(
                  top: 10,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: fallbackColors[1].withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        shadows: [
                          Shadow(color: Colors.black26, blurRadius: 2),
                        ],
                      ),
                    ),
                  ),
                ),

              // Content
              Padding(
                padding: EdgeInsets.fromLTRB(20, label.isNotEmpty ? 32 : 16, 16, 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withValues(alpha: 0.25),
                            Colors.white.withValues(alpha: 0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: fallbackColors[1].withValues(alpha: 0.3),
                            blurRadius: 12,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Icon(
                        _getIconFromAgenda(agenda),
                        size: 30,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: fallbackColors[1].withValues(alpha: 0.5),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            title as String,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.2,
                              shadows: [
                                Shadow(
                                  color: Colors.black38,
                                  blurRadius: 4,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            description as String,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Colors.white.withValues(alpha: 0.85),
                              height: 1.35,
                              shadows: const [
                                Shadow(
                                  color: Colors.black26,
                                  blurRadius: 3,
                                ),
                              ],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withValues(alpha: 0.2),
                            Colors.white.withValues(alpha: 0.08),
                          ],
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                      ),
                      child: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom accent strip
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        fallbackColors[1],
                        fallbackColors[0],
                        fallbackColors[1],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static IconData _getIconFromAgenda(Map<String, dynamic> agenda) {
    final iconName = agenda['icon_name'] as String?;
    const iconMap = {
      'water_drop': Icons.water_drop,
      'trending_up': Icons.trending_up,
      'security': Icons.security,
      'public': Icons.public,
      'groups': Icons.groups,
      'gavel': Icons.gavel,
      'handshake': Icons.handshake,
      'landscape': Icons.landscape,
      'school': Icons.school,
      'health_and_safety': Icons.health_and_safety,
      'agriculture': Icons.agriculture,
      'business': Icons.business,
    };
    return iconMap[iconName] ?? Icons.star;
  }
}
