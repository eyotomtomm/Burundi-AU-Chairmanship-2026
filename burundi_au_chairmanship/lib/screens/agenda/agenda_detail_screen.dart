import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/environment.dart';
import '../../services/api_service.dart';
import '../../config/app_ds.dart';
import '../discussions/discussions_screen.dart';
import '../../widgets/ds/ds_widgets.dart';
import '../../services/share_service.dart';

/// Section wording for one priority agenda. Only the copy differs between the
/// three agendas — the layout is identical, so it lives here once.
class AgendaLabels {
  final String overview, objectives, impacts, initiatives;
  final String objectivesStat, impactsStat;
  const AgendaLabels({
    required this.overview,
    required this.objectives,
    required this.impacts,
    required this.initiatives,
    required this.objectivesStat,
    required this.impactsStat,
  });
}

/// The one priority-agenda detail page, in the 2026 design: green header with
/// the OUR AGENDA overline, stat row, then DS cards. Water & Sanitation,
/// A-RISE and Peace & Security are all this screen with different content.
class AgendaDetailScreen extends StatefulWidget {
  final String slug;
  final IconData icon;
  final String fallbackTitle;
  final String fallbackTitleFr;
  final AgendaLabels labels;
  final AgendaLabels labelsFr;

  /// Discussion category to open the debate board on. Null hides the board.
  final String? debateCategory;

  const AgendaDetailScreen({
    super.key,
    required this.slug,
    this.debateCategory,
    required this.icon,
    required this.fallbackTitle,
    required this.fallbackTitleFr,
    required this.labels,
    required this.labelsFr,
  });

  @override
  State<AgendaDetailScreen> createState() => _AgendaDetailScreenState();
}

class _AgendaDetailScreenState extends State<AgendaDetailScreen> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? agendaData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAgendaData();
  }

  Future<void> _loadAgendaData() async {
    try {
      final agendas = await _apiService.getPriorityAgendas();
      agendaData = agendas.firstWhere(
        (a) => a['slug'] == widget.slug,
        orElse: () => <String, dynamic>{},
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading agenda: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
    final id = agendaData?['id'];
    if (id != null) {
      try {
        await _apiService
            .recordAgendaView(id is int ? id : int.parse(id.toString()));
      } catch (_) {}
    }
  }

  bool get _isFr => Localizations.localeOf(context).languageCode == 'fr';
  AgendaLabels get _l => _isFr ? widget.labelsFr : widget.labels;

  String _formatTitle(String title) {
    if (title.contains('_') || title.contains('-')) {
      title = title.replaceAll('_', ' ').replaceAll('-', ' ');
      title = title
          .split(' ')
          .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : w)
          .join(' ');
    }
    return title;
  }

  String _t(String key) {
    if (agendaData == null) return '';
    if (_isFr) {
      final fr = agendaData!['${key}_fr'];
      if (fr != null && fr.toString().isNotEmpty) return fr.toString();
    }
    return (agendaData![key] ?? '').toString();
  }

  List<dynamic> _tList(String key) {
    if (agendaData == null) return [];
    if (_isFr) {
      final fr = agendaData!['${key}_fr'];
      if (fr is List && fr.isNotEmpty) return fr;
    }
    final val = agendaData![key];
    return val is List ? val : [];
  }

  @override
  Widget build(BuildContext context) {
    final objectives = _tList('objectives');
    final impacts = _tList('impact_areas');

    if (isLoading) {
      return Scaffold(
        backgroundColor: Ds.bg(context),
        body: const Center(
            child: CircularProgressIndicator(strokeWidth: 2, color: Ds.green)),
      );
    }

    return Scaffold(
      backgroundColor: Ds.bg(context),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          _buildHeader(context),
          if (widget.debateCategory != null) _buildDebateCard(context),
          DsStatRow([
            DsStat('${objectives.length}', _l.objectivesStat),
            DsStat('${impacts.length}', _l.impactsStat),
            const DsStat('AU', '2026'),
          ]),
          if (_t('overview').isNotEmpty) ...[
            _heading(context, _l.overview),
            _paragraph(context, _t('overview')),
          ],
          if (objectives.isNotEmpty) ...[
            _heading(context, _l.objectives),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  for (var i = 0; i < objectives.length; i++)
                    _buildObjectiveCard(context, i + 1, objectives[i].toString()),
                ],
              ),
            ),
          ],
          if (impacts.isNotEmpty) ...[
            _heading(context, _l.impacts),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(children: _buildImpactCards(impacts)),
            ),
          ],
          if (_t('current_initiatives').isNotEmpty) ...[
            _heading(context, _l.initiatives),
            _paragraph(context, _t('current_initiatives')),
          ],
        ],
      ),
    );
  }

  Widget _buildDebateCard(BuildContext context) {
    final fr = Localizations.localeOf(context).languageCode == 'fr';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Material(
        color: Ds.tint(context),
        borderRadius: BorderRadius.circular(Ds.rCard),
        child: InkWell(
          borderRadius: BorderRadius.circular(Ds.rCard),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  DiscussionsScreen(initialCategory: widget.debateCategory),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.forum_rounded, color: Ds.green),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fr ? 'Voix des jeunes' : 'Youth Voices',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Ds.ink(context)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        fr
                            ? 'Publiez, débattez et votez sur les politiques'
                            : 'Post, debate and vote on policy',
                        style:
                            TextStyle(fontSize: 13, color: Ds.body(context)),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Ds.chevron),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _heading(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 10),
        child: Text(title,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Ds.ink(context))),
      );

  Widget _paragraph(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 0),
        child: Text(text,
            style:
                TextStyle(fontSize: 14, height: 1.65, color: Ds.body(context))),
      );

  /// Green header from the comp's "Agenda — Opened": overline, icon, title.
  Widget _buildHeader(BuildContext context) {
    final heroImage = agendaData?['hero_image'];
    final hasImage = heroImage != null && heroImage.toString().isNotEmpty;
    final title = _t('title').isNotEmpty
        ? _formatTitle(_t('title'))
        : (_isFr ? widget.fallbackTitleFr : widget.fallbackTitle);
    final subtitle = _t('description');

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
              GestureDetector(
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
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _isFr ? 'NOTRE AGENDA' : 'OUR AGENDA',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                      color: Colors.white.withValues(alpha: 0.8)),
                ),
              ),
              if (agendaData?['id'] != null)
                Builder(
                  builder: (btnContext) => GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => ShareService.item(
                      btnContext,
                      kind: 'agendas',
                      id: agendaData!['id'],
                      title: title,
                    ),
                    child: const SizedBox(
                      width: 36,
                      height: 36,
                      child: Icon(Icons.share_rounded,
                          size: 20, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(Ds.rCard),
                ),
                child: hasImage
                    ? CachedNetworkImage(
                        imageUrl: Environment.fixMediaUrl(heroImage.toString()),
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) => Icon(widget.icon,
                            size: 28, color: Colors.white),
                      )
                    : Icon(widget.icon, size: 28, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            color: Colors.white)),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.85))),
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

  /// Numbered objective / pillar, on the shared card.
  Widget _buildObjectiveCard(BuildContext context, int number, String text) {
    return DsCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Ds.goldTintOf(context),
              borderRadius: BorderRadius.circular(Ds.rIcon),
            ),
            alignment: Alignment.center,
            child: Text('$number',
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Ds.goldDeep)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style:
                    TextStyle(fontSize: 14, height: 1.5, color: Ds.ink(context))),
          ),
        ],
      ),
    );
  }

  /// Icons the backend may name on an impact area, across all three agendas.
  static const _iconMap = {
    'agriculture': Icons.agriculture_rounded,
    'business': Icons.business_rounded,
    'campaign': Icons.campaign_rounded,
    'computer': Icons.computer_rounded,
    'diversity_3': Icons.diversity_3_rounded,
    'eco': Icons.eco_rounded,
    'factory': Icons.factory_rounded,
    'gavel': Icons.gavel_rounded,
    'handshake': Icons.handshake_rounded,
    'health_and_safety': Icons.health_and_safety_rounded,
    'hub': Icons.hub_rounded,
    'local_shipping': Icons.local_shipping_rounded,
    'military_tech': Icons.military_tech_rounded,
    'people': Icons.people_rounded,
    'school': Icons.school_rounded,
    'security': Icons.security_rounded,
    'shield': Icons.shield_rounded,
    'swap_horiz': Icons.swap_horiz_rounded,
    'trending_up': Icons.trending_up_rounded,
    'volunteer_activism': Icons.volunteer_activism_rounded,
    'water_drop': Icons.water_drop_rounded,
  };

  List<Widget> _buildImpactCards(List<dynamic> areas) {
    return areas.map<Widget>((area) {
      final iconName = area is Map ? (area['icon'] ?? '').toString() : '';
      final title = (area is Map ? (area['title'] ?? '') : area).toString();
      final desc = area is Map ? (area['description'] ?? '').toString() : '';

      return DsCard(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            DsIconSquare(
              _iconMap[iconName] ?? widget.icon,
              tint: Ds.goldTintOf(context),
              color: Ds.goldDeep,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Ds.cardTitle(context)),
                  if (desc.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(desc, style: Ds.cardBody(context)),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
}
