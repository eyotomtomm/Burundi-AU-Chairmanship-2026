import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/app_colors.dart';
import '../../services/api_service.dart';

class AriseInitiativeScreen extends StatefulWidget {
  const AriseInitiativeScreen({super.key});

  @override
  State<AriseInitiativeScreen> createState() => _AriseInitiativeScreenState();
}

class _AriseInitiativeScreenState extends State<AriseInitiativeScreen> {
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
        (a) => a['slug'] == 'arise-initiative',
        orElse: () => <String, dynamic>{},
      );
    } catch (e) {
      debugPrint('Error loading agenda: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  String _t(String key) {
    if (agendaData == null) return '';
    final lang = Localizations.localeOf(context).languageCode;
    if (lang == 'fr') {
      final fr = agendaData!['${key}_fr'];
      if (fr != null && fr.toString().isNotEmpty) return fr.toString();
    }
    return (agendaData![key] ?? '').toString();
  }

  List<dynamic> _tList(String key) {
    if (agendaData == null) return [];
    final lang = Localizations.localeOf(context).languageCode;
    if (lang == 'fr') {
      final fr = agendaData!['${key}_fr'];
      if (fr is List && fr.isNotEmpty) return fr;
    }
    final val = agendaData![key];
    return val is List ? val : [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                _buildHeroSliver(),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Overview
                        if (_t('overview').isNotEmpty) ...[
                          _buildSectionTitle('About A-RISE'),
                          const SizedBox(height: 12),
                          _buildContentText(_t('overview')),
                          const SizedBox(height: 24),
                        ],

                        // Objectives
                        if (_tList('objectives').isNotEmpty) ...[
                          _buildSectionTitle('Strategic Pillars'),
                          const SizedBox(height: 12),
                          ..._tList('objectives').map((obj) =>
                            _buildBulletPoint(obj.toString())),
                          const SizedBox(height: 24),
                        ],

                        // Impact Areas
                        if (_tList('impact_areas').isNotEmpty) ...[
                          _buildSectionTitle('Focus Areas'),
                          const SizedBox(height: 12),
                          ..._buildImpactCards(),
                          const SizedBox(height: 24),
                        ],

                        // Current Initiatives
                        if (_t('current_initiatives').isNotEmpty) ...[
                          _buildSectionTitle('Expected Outcomes'),
                          const SizedBox(height: 12),
                          _buildContentText(_t('current_initiatives')),
                          const SizedBox(height: 24),
                        ],

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHeroSliver() {
    final heroImage = agendaData?['hero_image'];
    final hasImage = heroImage != null && heroImage.toString().isNotEmpty;

    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: const Color(0xFFB8860B),
      foregroundColor: Colors.white,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          _t('title').isNotEmpty ? _t('title') : 'A-RISE Initiative',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            shadows: [Shadow(blurRadius: 8, color: Colors.black54)],
          ),
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (hasImage)
              CachedNetworkImage(
                imageUrl: heroImage.toString().replaceAll('127.0.0.1', 'localhost'),
                fit: BoxFit.cover,
                placeholder: (_, _) => Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFB8860B), Color(0xFFDAA520)],
                    ),
                  ),
                ),
                errorWidget: (_, _, _) => Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFB8860B), Color(0xFFDAA520)],
                    ),
                  ),
                ),
              )
            else
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFB8860B), Color(0xFFDAA520)],
                  ),
                ),
              ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.1),
                    Colors.black.withValues(alpha: 0.6),
                  ],
                ),
              ),
            ),
            const Center(
              child: Icon(Icons.trending_up, size: 80, color: Colors.white38),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildImpactCards() {
    final areas = _tList('impact_areas');
    const cardColors = [
      AppColors.auGold,
      AppColors.info,
      AppColors.burundiGreen,
      AppColors.success,
    ];

    final iconMap = {
      'business': Icons.business,
      'factory': Icons.factory,
      'computer': Icons.computer,
      'local_shipping': Icons.local_shipping,
      'trending_up': Icons.trending_up,
      'school': Icons.school,
      'swap_horiz': Icons.swap_horiz,
      'eco': Icons.eco,
    };

    return areas.asMap().entries.map((entry) {
      final i = entry.key;
      final area = entry.value;
      final color = cardColors[i % cardColors.length];
      final iconName = area is Map ? (area['icon'] ?? '') : '';
      final icon = iconMap[iconName] ?? Icons.star;
      final title = area is Map ? (area['title'] ?? '') : area.toString();
      final desc = area is Map ? (area['description'] ?? '') : '';

      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title.toString(),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    if (desc.toString().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(desc.toString(),
                        style: TextStyle(fontSize: 14, color: Colors.black.withValues(alpha: 0.7))),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  Widget _buildSectionTitle(String title) {
    return Text(title,
      style: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: Color(0xFFB8860B),
      ));
  }

  Widget _buildContentText(String text) {
    return Text(text,
      style: const TextStyle(fontSize: 16, height: 1.6, color: Colors.black87));
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Icon(Icons.arrow_forward, size: 20, color: Color(0xFFB8860B)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 16, height: 1.6)),
          ),
        ],
      ),
    );
  }
}
