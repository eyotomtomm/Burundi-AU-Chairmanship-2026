import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../config/app_ds.dart';
import '../../../config/environment.dart';
import '../../../widgets/ds/ds_widgets.dart';
import '../../../widgets/login_gate.dart';

/// "Our agenda · Notre agenda" — a photo card per priority agenda: the
/// agenda's hero image under a scrim tinted with its own accent colour, so
/// water, ARISE and peace read as three distinct things at a glance.
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

  /// Scrim colours per agenda: blue water, gold ARISE, green peace.
  static const Map<String, (Color, Color)> _slugAccents = {
    'water-sanitation': (Ds.blue, Color(0xFF0B3C7A)),
    'arise-initiative': (Ds.goldDeep, Ds.goldInkDeep),
    'peace-security': (Ds.green, Ds.greenDarker),
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
            return _buildAgendaCard(context, agendas[index], index);
          case LoginGateSlot.banner:
            return const LoginGateBanner(margin: EdgeInsets.only(bottom: 10));
          case LoginGateSlot.blurred:
            final dataIndex =
                LoginGate.dataIndexFor(index, LoginGate.agendaFreeItems);
            if (dataIndex == null || dataIndex >= agendas.length) {
              return const SizedBox.shrink();
            }
            return LockedContentWrap(
              locked: true,
              borderRadius: const BorderRadius.all(Radius.circular(Ds.rCard)),
              child: _buildAgendaCard(context, agendas[dataIndex], dataIndex),
            );
          case LoginGateSlot.hidden:
            return const SizedBox.shrink();
        }
      }),
    );
  }

  Widget _buildAgendaCard(
      BuildContext context, Map<String, dynamic> agenda, int index) {
    final fr = langCode == 'fr';
    final slug = agenda['slug'] as String?;
    final title =
        (fr ? (agenda['title_fr'] ?? agenda['title']) : agenda['title'])
                ?.toString() ??
            '';
    final description = (fr
                ? (agenda['description_fr'] ?? agenda['description'])
                : agenda['description'])
            ?.toString() ??
        '';
    final image = Environment.fixMediaUrl(
        (agenda['hero_image'] ?? '').toString());
    final (accent, accentDeep) =
        _slugAccents[slug] ?? (Ds.green, Ds.greenDeep);
    final icon = _getIconFromAgenda(agenda);

    // No photo yet: the accent gradient plus an oversized icon watermark
    // still gives the card something to look at.
    final Widget backdrop = Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [accent, accentDeep],
            ),
          ),
        ),
        Positioned(
          right: -18,
          bottom: -24,
          child: Icon(icon, size: 132, color: Colors.white.withValues(alpha: 0.12)),
        ),
      ],
    );

    return DsCard(
      margin: const EdgeInsets.only(bottom: 12),
      featured: true,
      clip: true,
      onTap: slug == null ? null : () => Navigator.pushNamed(context, '/$slug'),
      child: SizedBox(
        height: 148,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (image.isEmpty)
              backdrop
            else
              CachedNetworkImage(
                imageUrl: image,
                fit: BoxFit.cover,
                placeholder: (_, _) => backdrop,
                errorWidget: (_, _, _) => backdrop,
              ),
            // Accent-tinted scrim keeps white text readable on any photo.
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    accent.withValues(alpha: 0.30),
                    accentDeep.withValues(alpha: 0.92),
                  ],
                  stops: const [0.0, 0.85],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.30),
                          borderRadius: BorderRadius.circular(Ds.rPill),
                        ),
                        child: Text(
                          '${fr ? 'PRIORITÉ' : 'PRIORITY'} ${(index + 1).toString().padLeft(2, '0')}',
                          style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.9,
                              color: Ds.gold),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(Ds.rIcon),
                        ),
                        child: Icon(icon, size: 19, color: Colors.white),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                        letterSpacing: -0.3,
                        color: Colors.white),
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Text(
                            description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12,
                                height: 1.35,
                                color: Colors.white.withValues(alpha: 0.88)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.22),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.arrow_forward_rounded,
                              size: 16, color: Colors.white),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static IconData _getIconFromAgenda(Map<String, dynamic> agenda) {
    final iconName = agenda['icon_name'] as String?;
    const iconMap = {
      'water_drop': Icons.water_drop_rounded,
      'trending_up': Icons.trending_up_rounded,
      'security': Icons.security_rounded,
      'public': Icons.public_rounded,
      'groups': Icons.groups_rounded,
      'gavel': Icons.gavel_rounded,
      'handshake': Icons.handshake_rounded,
      'landscape': Icons.landscape_rounded,
      'school': Icons.school_rounded,
      'health_and_safety': Icons.health_and_safety_rounded,
      'agriculture': Icons.agriculture_rounded,
      'business': Icons.business_rounded,
    };
    return iconMap[iconName] ?? Icons.star_rounded;
  }
}
