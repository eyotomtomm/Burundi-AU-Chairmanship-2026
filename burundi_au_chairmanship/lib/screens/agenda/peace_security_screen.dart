import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/environment.dart';
import '../../services/api_service.dart';
import '../../widgets/translate_button.dart';

class PeaceSecurityScreen extends StatefulWidget {
  const PeaceSecurityScreen({super.key});

  @override
  State<PeaceSecurityScreen> createState() => _PeaceSecurityScreenState();
}

class _PeaceSecurityScreenState extends State<PeaceSecurityScreen> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? agendaData;
  bool isLoading = true;

  // Theme colors for Peace & Security
  static const _primary = Color(0xFF1B5E20);
  static const _primaryLight = Color(0xFF2E7D32);


  @override
  void initState() {
    super.initState();
    _loadAgendaData();
  }

  Future<void> _loadAgendaData() async {
    try {
      final agendas = await _apiService.getPriorityAgendas();
      agendaData = agendas.firstWhere(
        (a) => a['slug'] == 'peace-security',
        orElse: () => <String, dynamic>{},
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading agenda: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  bool get _isFr => Localizations.localeOf(context).languageCode == 'fr';

  String _formatTitle(String title) {
    if (title.contains('_') || title.contains('-')) {
      title = title.replaceAll('_', ' ').replaceAll('-', ' ');
      title = title.split(' ').map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : w).join(' ');
    }
    return title;
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: const AlwaysStoppedAnimation<Color>(_primary),
              ),
            )
          : CustomScrollView(
              slivers: [
                _buildHeroSliver(),
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Quick stats banner
                      _buildStatsBanner(isDark),

                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Overview
                            if (_t('overview').isNotEmpty) ...[
                              _buildSectionHeader(
                                _isFr ? 'Engagement pour la Paix' : 'Commitment to Peace',
                                Icons.handshake_rounded,
                                isDark,
                              ),
                              const SizedBox(height: 12),
                              _buildContentCard(_t('overview'), isDark),
                              const SizedBox(height: 28),
                            ],

                            // Objectives
                            if (_tList('objectives').isNotEmpty) ...[
                              _buildSectionHeader(
                                _isFr ? 'Actions Prioritaires' : 'Priority Actions',
                                Icons.gavel_rounded,
                                isDark,
                              ),
                              const SizedBox(height: 12),
                              ..._tList('objectives').asMap().entries.map(
                                (entry) => _buildObjectiveCard(
                                  entry.key + 1,
                                  entry.value.toString(),
                                  isDark,
                                ),
                              ),
                              const SizedBox(height: 28),
                            ],

                            // Impact Areas
                            if (_tList('impact_areas').isNotEmpty) ...[
                              _buildSectionHeader(
                                _isFr ? 'Initiatives Clés' : 'Key Initiatives',
                                Icons.shield_rounded,
                                isDark,
                              ),
                              const SizedBox(height: 12),
                              ..._buildImpactCards(isDark),
                              const SizedBox(height: 28),
                            ],

                            // Current Initiatives
                            if (_t('current_initiatives').isNotEmpty) ...[
                              _buildSectionHeader(
                                _isFr ? 'Faire Taire les Armes' : 'Silencing the Guns',
                                Icons.campaign_rounded,
                                isDark,
                              ),
                              const SizedBox(height: 12),
                              _buildContentCard(_t('current_initiatives'), isDark),
                              const SizedBox(height: 28),
                            ],

                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ],
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
      expandedHeight: 260,
      pinned: true,
      backgroundColor: _primary,
      foregroundColor: Colors.white,
      actions: const [TranslateButton()],
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          _t('title').isNotEmpty ? _formatTitle(_t('title')) : (_isFr ? 'Paix et Sécurité' : 'Peace & Security'),
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            letterSpacing: -0.3,
            shadows: [
              Shadow(blurRadius: 12, color: Colors.black54),
              Shadow(blurRadius: 24, color: Colors.black26),
            ],
          ),
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (hasImage)
              CachedNetworkImage(
                imageUrl: Environment.fixMediaUrl(heroImage.toString()),
                fit: BoxFit.cover,
                placeholder: (_, _) => _buildGradientBackground(),
                errorWidget: (_, _, _) => _buildGradientBackground(),
              )
            else
              _buildGradientBackground(),
            // Gradient overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    _primary.withValues(alpha: 0.3),
                    _primary.withValues(alpha: 0.8),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
            // Decorative icon
            Positioned(
              right: 24,
              bottom: 64,
              child: Icon(Icons.security, size: 60, color: Colors.white.withValues(alpha: 0.15)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGradientBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_primary, _primaryLight],
        ),
      ),
    );
  }

  Widget _buildStatsBanner(bool isDark) {
    final objectives = _tList('objectives');
    final impacts = _tList('impact_areas');

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      transform: Matrix4.translationValues(0, -20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _primary.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            '${objectives.length}',
            _isFr ? 'Actions' : 'Actions',
            Icons.gavel_rounded,
            isDark,
          ),
          Container(
            width: 1,
            height: 36,
            color: isDark ? Colors.white12 : Colors.black12,
          ),
          _buildStatItem(
            '${impacts.length}',
            _isFr ? 'Initiatives' : 'Initiatives',
            Icons.shield_rounded,
            isDark,
          ),
          Container(
            width: 1,
            height: 36,
            color: isDark ? Colors.white12 : Colors.black12,
          ),
          _buildStatItem(
            'AU',
            '2026',
            Icons.public_rounded,
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label, IconData icon, bool isDark) {
    return Column(
      children: [
        Icon(icon, size: 20, color: _primary),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.white54 : Colors.black45,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, bool isDark) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _primary.withValues(alpha: isDark ? 0.2 : 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: isDark ? const Color(0xFF4CAF50) : _primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: isDark ? const Color(0xFF4CAF50) : _primary,
              letterSpacing: -0.3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContentCard(String text, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.06) : _primary.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 15,
          height: 1.7,
          color: isDark ? Colors.white70 : Colors.black87,
        ),
      ),
    );
  }

  Widget _buildObjectiveCard(int number, String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.06) : _primary.withValues(alpha: 0.1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_primary, _primaryLight],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  '$number',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildImpactCards(bool isDark) {
    final areas = _tList('impact_areas');
    const cardColors = [
      Color(0xFF1B5E20),
      Color(0xFF2E7D32),
      Color(0xFF388E3C),
      Color(0xFF43A047),
    ];

    final iconMap = {
      'shield': Icons.shield_rounded,
      'handshake': Icons.handshake_rounded,
      'military_tech': Icons.military_tech_rounded,
      'gavel': Icons.gavel_rounded,
      'diversity_3': Icons.diversity_3_rounded,
      'people': Icons.people_rounded,
      'volunteer_activism': Icons.volunteer_activism_rounded,
      'security': Icons.security_rounded,
    };

    return areas.asMap().entries.map((entry) {
      final i = entry.key;
      final area = entry.value;
      final color = cardColors[i % cardColors.length];
      final iconName = area is Map ? (area['icon'] ?? '') : '';
      final icon = iconMap[iconName] ?? Icons.star_rounded;
      final title = area is Map ? (area['title'] ?? '') : area.toString();
      final desc = area is Map ? (area['description'] ?? '') : '';

      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border(
              left: BorderSide(color: color, width: 4),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withValues(alpha: 0.7)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.toString(),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    if (desc.toString().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        desc.toString(),
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                      ),
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
}
