import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/app_ds.dart';
import '../../config/environment.dart';
import '../../l10n/app_localizations.dart';
import '../../services/api_service.dart';
import '../../widgets/app_network_image.dart';
import '../../widgets/async_content_view.dart';
import '../../widgets/ds/ds_widgets.dart';
import '../../widgets/shimmer_loading.dart';

/// The three priorities of the chairmanship, as three doors.
///
/// The More menu used to jump straight into A-RISE, which left the other two
/// priorities reachable only by scrolling the home tab. This is the index that
/// tile should have pointed at all along; each card opens the agenda's own
/// existing page (`/water-sanitation`, `/arise-initiative`, `/peace-security`).
class PriorityAgendaHubScreen extends StatefulWidget {
  const PriorityAgendaHubScreen({super.key});

  @override
  State<PriorityAgendaHubScreen> createState() =>
      _PriorityAgendaHubScreenState();
}

class _PriorityAgendaHubScreenState extends State<PriorityAgendaHubScreen> {
  /// Scrim colours per agenda, matching the home-tab section so a priority
  /// keeps the same identity wherever it appears: blue water, gold A-RISE,
  /// green peace.
  static const Map<String, (Color, Color)> _slugAccents = {
    'water-sanitation': (Ds.blue, Color(0xFF0B3C7A)),
    'arise-initiative': (Ds.goldDeep, Ds.goldInkDeep),
    'peace-security': (Ds.green, Ds.greenDarker),
  };

  static const Map<String, IconData> _slugIcons = {
    'water-sanitation': Icons.water_drop_rounded,
    'arise-initiative': Icons.trending_up_rounded,
    'peace-security': Icons.security_rounded,
  };

  /// The three priorities are fixed for this chairmanship, so a failed request
  /// should still leave the user with three working doors rather than a dead
  /// end. Titles mirror the fallbacks in the individual agenda screens.
  static const List<Map<String, dynamic>> _known = [
    {
      'slug': 'water-sanitation',
      'title': 'Water & Sanitation',
      'title_fr': 'Eau et Assainissement',
    },
    {
      'slug': 'arise-initiative',
      'title': 'A-RISE Initiative',
      'title_fr': 'Initiative A-RISE',
    },
    {
      'slug': 'peace-security',
      'title': 'Peace & Security',
      'title_fr': 'Paix et Sécurité',
    },
  ];

  static const List<String> _order = [
    'water-sanitation',
    'arise-initiative',
    'peace-security',
  ];

  List<Map<String, dynamic>> _agendas = const [];
  AsyncContentState _state = AsyncContentState.loading;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted && _state != AsyncContentState.loading) {
      setState(() => _state = AsyncContentState.loading);
    }
    try {
      final data = await ApiService().getPriorityAgendas();
      if (!mounted) return;
      setState(() {
        _agendas = _sorted(data.isEmpty ? _known : data);
        _state = AsyncContentState.content;
      });
    } catch (_) {
      if (!mounted) return;
      // The priorities themselves are known even when the API is not
      // reachable, so show them rather than an error page.
      setState(() {
        _agendas = _sorted(_known);
        _state = AsyncContentState.content;
      });
    }
  }

  /// Keep the three in their published order regardless of what the API
  /// returns; anything unrecognised keeps its own order after them.
  List<Map<String, dynamic>> _sorted(List<Map<String, dynamic>> items) {
    final ranked = [...items];
    ranked.sort((a, b) {
      final ai = _order.indexOf((a['slug'] ?? '').toString());
      final bi = _order.indexOf((b['slug'] ?? '').toString());
      return (ai < 0 ? _order.length : ai).compareTo(bi < 0 ? _order.length : bi);
    });
    return ranked;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final fr = Localizations.localeOf(context).languageCode == 'fr';

    return Scaffold(
      backgroundColor: Ds.bg(context),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            DsHeader(title: l10n.translate('priority_agenda')),
            Expanded(
              child: AsyncContentView(
                state: _state,
                onRetry: _load,
                onRefresh: _load,
                loadingWidget: _buildSkeleton(),
                child: RefreshIndicator(
                  onRefresh: _load,
                  color: Ds.green,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                        16, 4, 16, Ds.navSpace(context) + 16),
                    children: [
                      Text(
                        l10n.translate('priority_agenda_intro'),
                        style: Ds.cardBody(context).copyWith(height: 1.45),
                      ),
                      const SizedBox(height: 16),
                      for (var i = 0; i < _agendas.length; i++)
                        _AgendaDoor(
                          agenda: _agendas[i],
                          index: i,
                          fr: fr,
                          accents: _slugAccents,
                          icons: _slugIcons,
                        ),
                      const SizedBox(height: 4),
                      DsFootnote(l10n.translate('priority_agenda_footnote')),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeleton() => ListView(
        padding: EdgeInsets.fromLTRB(16, 4, 16, Ds.navSpace(context) + 16),
        children: [
          ShimmerLoading(child: _bar(double.infinity, 14)),
          const SizedBox(height: 8),
          ShimmerLoading(child: _bar(220, 14)),
          const SizedBox(height: 20),
          for (var i = 0; i < 3; i++) ...[
            ShimmerLoading(child: _bar(double.infinity, 172, Ds.rCard)),
            const SizedBox(height: 14),
          ],
        ],
      );

  Widget _bar(double width, double height, [double radius = 6]) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Ds.surface(context),
          borderRadius: BorderRadius.circular(radius),
        ),
      );
}

/// One priority, rendered as a full-width door into its own page.
class _AgendaDoor extends StatelessWidget {
  final Map<String, dynamic> agenda;
  final int index;
  final bool fr;
  final Map<String, (Color, Color)> accents;
  final Map<String, IconData> icons;

  const _AgendaDoor({
    required this.agenda,
    required this.index,
    required this.fr,
    required this.accents,
    required this.icons,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final slug = (agenda['slug'] ?? '').toString();
    final title = (fr
                ? (agenda['title_fr'] ?? agenda['title'])
                : agenda['title'])
            ?.toString() ??
        '';
    final description = (fr
                ? (agenda['description_fr'] ?? agenda['description'])
                : agenda['description'])
            ?.toString() ??
        '';
    final image =
        Environment.fixMediaUrl((agenda['hero_image'] ?? '').toString());
    final (accent, accentDeep) = accents[slug] ?? (Ds.green, Ds.greenDeep);
    final icon = icons[slug] ?? Icons.flag_rounded;

    // Cards carry real copy, so let them grow with the user's text size
    // instead of clipping at a fixed height.
    final scale = MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.6);
    final height = 172.0 * scale;

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
          right: -20,
          bottom: -28,
          child: Icon(icon,
              size: 148, color: Colors.white.withValues(alpha: 0.12)),
        ),
      ],
    );

    return Semantics(
      button: true,
      label: title,
      child: DsCard(
        margin: const EdgeInsets.only(bottom: 14),
        featured: true,
        clip: true,
        onTap: slug.isEmpty
            ? null
            : () {
                HapticFeedback.lightImpact();
                Navigator.pushNamed(context, '/$slug');
              },
        child: SizedBox(
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (image.isEmpty)
                backdrop
              else
                AppNetworkImage(
                  imageUrl: image,
                  fit: BoxFit.cover,
                  hero: true,
                  placeholder: (_, _) => backdrop,
                  errorWidget: (_, _, _) => backdrop,
                ),
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
                padding: const EdgeInsets.all(16),
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
                            '${l10n.translate('priority_label')} '
                            '${(index + 1).toString().padLeft(2, '0')}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.9,
                              color: Ds.gold,
                            ),
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
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                        letterSpacing: -0.3,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Text(
                            description.isNotEmpty
                                ? description
                                : l10n.translate('priority_agenda_open'),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.35,
                              color: Colors.white.withValues(alpha: 0.88),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.22),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.arrow_forward_rounded,
                              size: 17, color: Colors.white),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
