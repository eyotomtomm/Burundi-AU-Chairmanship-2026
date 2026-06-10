import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_colors.dart';
import '../../config/environment.dart';
import '../../services/api_service.dart';

class FeatureCardDetailScreen extends StatefulWidget {
  final Map<String, dynamic> cardData;

  const FeatureCardDetailScreen({super.key, required this.cardData});

  @override
  State<FeatureCardDetailScreen> createState() => _FeatureCardDetailScreenState();
}

class _FeatureCardDetailScreenState extends State<FeatureCardDetailScreen> {
  Map<String, dynamic> get cardData => widget.cardData;

  @override
  void initState() {
    super.initState();
    _recordView();
  }

  Future<void> _recordView() async {
    try {
      final id = cardData['id'];
      if (id != null) await ApiService().recordFeatureCardView(id is int ? id : int.parse(id.toString()));
    } catch (_) {}
  }

  /// Get localized string value, preferring French if locale is 'fr'.
  String _t(BuildContext context, String key) {
    final lang = Localizations.localeOf(context).languageCode;
    if (lang == 'fr') {
      final fr = cardData['${key}_fr'];
      if (fr != null && fr.toString().isNotEmpty) return fr.toString();
    }
    // For 'title', use the raw API value (since 'title' in the map is pre-localized)
    if (key == 'title') {
      return (cardData['title_raw'] ?? cardData['title'] ?? '').toString();
    }
    return (cardData[key] ?? '').toString();
  }

  /// Get localized list value, preferring French if locale is 'fr'.
  List<dynamic> _tList(BuildContext context, String key) {
    final lang = Localizations.localeOf(context).languageCode;
    if (lang == 'fr') {
      final fr = cardData['${key}_fr'];
      if (fr is List && fr.isNotEmpty) return fr;
    }
    final val = cardData[key];
    return val is List ? val : [];
  }

  Color _hexToColor(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.isEmpty) return const Color(0xFF409843);
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.tryParse(hex, radix: 16) ?? 0xFF409843);
  }

  @override
  Widget build(BuildContext context) {
    final gradStart = _hexToColor(
        cardData['gradient_start'] as String? ?? '#409843');
    final gradEnd = _hexToColor(
        cardData['gradient_end'] as String? ?? '#4CAF50');
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mediaItems = cardData['media'] as List<dynamic>? ?? [];

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildHeroSliver(context, gradStart, gradEnd),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Overview
                  if (_t(context, 'overview').isNotEmpty) ...[
                    _buildSectionTitle(context, _isEnglish(context) ? 'Overview' : 'Apercu', gradStart),
                    const SizedBox(height: 12),
                    _buildContentText(context, _t(context, 'overview'), isDark),
                    const SizedBox(height: 24),
                  ],

                  // Key Points
                  if (_tList(context, 'key_points').isNotEmpty) ...[
                    _buildSectionTitle(context, _isEnglish(context) ? 'Key Points' : 'Points Cles', gradStart),
                    const SizedBox(height: 12),
                    ..._tList(context, 'key_points').map((point) =>
                        _buildBulletPoint(context, point.toString(), gradStart, isDark)),
                    const SizedBox(height: 24),
                  ],

                  // Impact Areas
                  if (_tList(context, 'impact_areas').isNotEmpty) ...[
                    _buildSectionTitle(context, _isEnglish(context) ? 'Impact Areas' : "Domaines d'Impact", gradStart),
                    const SizedBox(height: 12),
                    ..._buildImpactCards(context, isDark),
                    const SizedBox(height: 24),
                  ],

                  // Media Gallery
                  if (mediaItems.isNotEmpty) ...[
                    _buildSectionTitle(context, _isEnglish(context) ? 'Gallery' : 'Galerie', gradStart),
                    const SizedBox(height: 12),
                    _buildMediaGallery(context, mediaItems, isDark),
                    const SizedBox(height: 24),
                  ],

                  // Extra Content
                  if (_t(context, 'extra_content').isNotEmpty) ...[
                    _buildSectionTitle(context, _isEnglish(context) ? 'More Information' : "Plus d'Informations", gradStart),
                    const SizedBox(height: 12),
                    _buildContentText(context, _t(context, 'extra_content'), isDark),
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

  bool _isEnglish(BuildContext context) {
    return Localizations.localeOf(context).languageCode != 'fr';
  }

  Widget _buildHeroSliver(BuildContext context, Color gradStart, Color gradEnd) {
    final icon = cardData['icon'] as IconData? ?? Icons.stars;
    final imageUrl = cardData['image_url'] as String? ?? '';

    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: gradStart,
      foregroundColor: Colors.white,
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        titlePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        title: Text(
          _t(context, 'title'),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
            shadows: [Shadow(blurRadius: 8, color: Colors.black54)],
          ),
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Background image if available, otherwise gradient
            if (imageUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: Environment.fixMediaUrl(imageUrl),
                fit: BoxFit.cover,
                placeholder: (_, _) => Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [gradStart, gradEnd],
                    ),
                  ),
                ),
                errorWidget: (_, _, _) => Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [gradStart, gradEnd],
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
                    colors: [gradStart, gradEnd],
                  ),
                ),
              ),
            // Gradient overlay for text readability
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    gradStart.withValues(alpha: 0.3),
                    gradEnd.withValues(alpha: 0.8),
                  ],
                ),
              ),
            ),
            // Icon — uploaded image or Material icon fallback
            Center(
              child: _buildHeroIcon(icon, 80),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildImpactCards(BuildContext context, bool isDark) {
    final areas = _tList(context, 'impact_areas');
    const cardColors = [
      AppColors.success,
      AppColors.auGold,
      AppColors.info,
      AppColors.burundiGreen,
    ];

    final iconMap = {
      'health_and_safety': Icons.health_and_safety,
      'school': Icons.school,
      'agriculture': Icons.agriculture,
      'trending_up': Icons.trending_up,
      'business': Icons.business,
      'computer': Icons.computer,
      'factory': Icons.factory,
      'local_shipping': Icons.local_shipping,
      'public': Icons.public,
      'security': Icons.security,
      'groups': Icons.groups,
      'landscape': Icons.landscape,
      'music_note': Icons.music_note,
      'restaurant': Icons.restaurant,
      'diversity_3': Icons.diversity_3,
      'shield': Icons.shield,
      'handshake': Icons.handshake,
      'military_tech': Icons.military_tech,
      'gavel': Icons.gavel,
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
            color: isDark
                ? color.withValues(alpha: 0.15)
                : color.withValues(alpha: 0.1),
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
                    Text(
                      title.toString(),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    if (desc.toString().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        desc.toString(),
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark
                              ? Colors.white70
                              : Colors.black.withValues(alpha: 0.7),
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

  Widget _buildHeroIcon(IconData fallbackIcon, double size) {
    final iconImageUrl = cardData['iconImageUrl'] as String? ?? '';
    if (iconImageUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: Environment.fixMediaUrl(iconImageUrl),
        width: size,
        height: size,
        fit: BoxFit.contain,
        color: Colors.white38,
        colorBlendMode: BlendMode.modulate,
        placeholder: (_, _) => Icon(fallbackIcon, size: size, color: Colors.white38),
        errorWidget: (_, _, _) => Icon(fallbackIcon, size: size, color: Colors.white38),
      );
    }
    return Icon(fallbackIcon, size: size, color: Colors.white38);
  }

  Widget _buildSectionTitle(BuildContext context, String title, Color accentColor) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: accentColor,
      ),
    );
  }

  Widget _buildContentText(BuildContext context, String text, bool isDark) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 16,
        height: 1.6,
        color: isDark ? Colors.white70 : Colors.black87,
      ),
    );
  }

  Widget _buildBulletPoint(BuildContext context, String text, Color accentColor, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Icon(Icons.check_circle, size: 20, color: accentColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 16,
                height: 1.6,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build the media gallery — horizontal image scroll + video thumbnails
  Widget _buildMediaGallery(BuildContext context, List<dynamic> mediaItems, bool isDark) {
    final lang = Localizations.localeOf(context).languageCode;

    return SizedBox(
      height: 180,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: mediaItems.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final item = mediaItems[index] as Map<String, dynamic>;
          final mediaType = item['media_type'] ?? 'image';
          final caption = lang == 'fr'
              ? (item['caption_fr'] ?? item['caption'] ?? '')
              : (item['caption'] ?? '');
          final imageUrl = item['image'] as String? ?? '';
          final videoUrl = item['video_url'] as String? ?? '';

          if (mediaType == 'video') {
            return _buildVideoThumbnail(context, videoUrl, caption.toString(), isDark);
          }
          return _buildImageThumbnail(context, imageUrl, caption.toString(), isDark);
        },
      ),
    );
  }

  Widget _buildImageThumbnail(BuildContext context, String imageUrl, String caption, bool isDark) {
    return GestureDetector(
      onTap: imageUrl.isNotEmpty ? () => _showFullImage(context, imageUrl, caption) : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 240,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (imageUrl.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: Environment.fixMediaUrl(imageUrl),
                  fit: BoxFit.cover,
                  placeholder: (_, _) => Container(
                    color: isDark ? Colors.grey[800] : Colors.grey[200],
                    child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                  errorWidget: (_, _, _) => Container(
                    color: isDark ? Colors.grey[800] : Colors.grey[200],
                    child: const Icon(Icons.broken_image, size: 40),
                  ),
                )
              else
                Container(
                  color: isDark ? Colors.grey[800] : Colors.grey[200],
                  child: const Icon(Icons.image, size: 40),
                ),
              if (caption.isNotEmpty)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
                      ),
                    ),
                    child: Text(
                      caption,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoThumbnail(BuildContext context, String videoUrl, String caption, bool isDark) {
    return GestureDetector(
      onTap: videoUrl.isNotEmpty ? () => _launchVideoUrl(videoUrl) : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 240,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[850] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Icon(Icons.videocam, size: 48, color: Colors.white54),
                ),
              ),
              // Play button overlay
              Center(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow, color: Colors.white, size: 36),
                ),
              ),
              if (caption.isNotEmpty)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
                      ),
                    ),
                    child: Text(
                      caption,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFullImage(BuildContext context, String imageUrl, String caption) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: Environment.fixMediaUrl(imageUrl),
                fit: BoxFit.contain,
                placeholder: (_, _) => const SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (_, _, _) => const SizedBox(
                  height: 200,
                  child: Center(child: Icon(Icons.broken_image, size: 48, color: Colors.white)),
                ),
              ),
            ),
            if (caption.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(caption, style: const TextStyle(color: Colors.white, fontSize: 14)),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _launchVideoUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
