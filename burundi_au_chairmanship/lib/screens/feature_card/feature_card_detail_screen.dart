import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/data_saver_service.dart';
import '../../widgets/app_network_image.dart';
import '../../l10n/app_localizations.dart';
import '../../config/environment.dart';
import '../../services/api_service.dart';
import '../../config/app_ds.dart';
import '../../widgets/ds/ds_widgets.dart';
import 'media_video_player_screen.dart';
import '../../services/share_service.dart';

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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mediaItems = cardData['media'] as List<dynamic>? ?? [];
    final en = _isEnglish(context);
    final subtitle = _t(context, 'description');

    return Scaffold(
      backgroundColor: Ds.bg(context),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          _buildHeroPhoto(context),

          // Title card lifted over the photo's lower edge.
          Transform.translate(
            offset: const Offset(0, -28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DsCard(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DsPill(en ? 'DISCOVER BURUNDI' : 'DÉCOUVRIR LE BURUNDI'),
                      const SizedBox(height: 10),
                      Text(
                        _t(context, 'title'),
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                            height: 1.25,
                            color: Ds.ink(context)),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(subtitle,
                            style: TextStyle(
                                fontSize: 13, height: 1.4, color: Ds.body(context))),
                      ],
                    ],
                  ),
                ),

                if (_t(context, 'overview').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 16, 22, 0),
                    child: Text(
                      _t(context, 'overview'),
                      style: TextStyle(
                          fontSize: 14, height: 1.65, color: Ds.body(context)),
                    ),
                  ),

                if (_tList(context, 'key_points').isNotEmpty) ...[
                  _heading(context, en ? 'Key points' : 'Points clés'),
                  ..._tList(context, 'key_points').indexed.map((e) =>
                      _buildBulletPoint(context, e.$2.toString(), e.$1)),
                ],

                if (_tList(context, 'impact_areas').isNotEmpty) ...[
                  _heading(context,
                      en ? 'Impact areas' : "Domaines d'impact"),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(children: _buildImpactCards(context, isDark)),
                  ),
                ],

                if (mediaItems.isNotEmpty) ...[
                  _heading(context, en ? 'Gallery' : 'Galerie'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildMediaGallery(context, mediaItems, isDark),
                  ),
                ],

                if (_t(context, 'extra_content').isNotEmpty) ...[
                  _heading(context, en ? 'More information' : "Plus d'informations"),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 0, 22, 0),
                    child: Text(
                      _t(context, 'extra_content'),
                      style: TextStyle(
                          fontSize: 14, height: 1.65, color: Ds.body(context)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heading(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 10),
        child: Text(title,
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w800, color: Ds.ink(context))),
      );

  /// Cinematic hero: photo, brand scrim, and the title sitting on the image.
  Widget _buildHeroPhoto(BuildContext context) {
    final imageUrl = Environment.fixMediaUrl(
        (cardData['imageUrl'] ?? cardData['image_url'] ?? cardData['image'] ?? '')
            .toString());
    final gradient = (cardData['gradient'] as List<Color>?) ??
        const [Ds.green, Ds.greenDeep];

    final fallback = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
      ),
    );

    return SizedBox(
      height: 320,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (imageUrl.isEmpty)
            fallback
          else
            AppNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              hero: true,
              placeholder: (_, _) => fallback,
              errorWidget: (_, _, _) => fallback,
            ),
          // Top shade for the back button, bottom shade for the title card.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x73000000),
                  Color(0x00000000),
                  Color(0x59000000),
                ],
                stops: [0.0, 0.4, 1.0],
              ),
            ),
          ),
          Positioned(
            left: 16,
            top: MediaQuery.paddingOf(context).top + 8,
            child: _circleButton(Icons.arrow_back_rounded,
                () => Navigator.pop(context),
                MaterialLocalizations.of(context).backButtonTooltip),
          ),
          Positioned(
            right: 16,
            top: MediaQuery.paddingOf(context).top + 8,
            child: Builder(
              builder: (btnContext) => _circleButton(
                Icons.share_rounded,
                () => ShareService.item(
                  btnContext,
                  kind: 'features',
                  id: cardData['id'],
                  title: _t(btnContext, 'title'),
                ),
                AppLocalizations.of(context).translate('share'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleButton(IconData icon, VoidCallback onTap, String label) =>
      Semantics(
        button: true,
        label: label,
        child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: Colors.white),
        ),
        ),
      );

  bool _isEnglish(BuildContext context) {
    return Localizations.localeOf(context).languageCode != 'fr';
  }

  static const Map<String, IconData> _impactIcons = {
    'health_and_safety': Icons.health_and_safety_rounded,
    'school': Icons.school_rounded,
    'agriculture': Icons.agriculture_rounded,
    'trending_up': Icons.trending_up_rounded,
    'business': Icons.business_rounded,
    'computer': Icons.computer_rounded,
    'factory': Icons.factory_rounded,
    'local_shipping': Icons.local_shipping_rounded,
    'public': Icons.public_rounded,
    'security': Icons.security_rounded,
    'groups': Icons.groups_rounded,
    'landscape': Icons.landscape_rounded,
    'music_note': Icons.music_note_rounded,
    'restaurant': Icons.restaurant_rounded,
    'diversity_3': Icons.diversity_3_rounded,
    'shield': Icons.shield_rounded,
    'handshake': Icons.handshake_rounded,
    'military_tech': Icons.military_tech_rounded,
    'gavel': Icons.gavel_rounded,
  };

  List<Widget> _buildImpactCards(BuildContext context, bool isDark) {
    const accents = [Ds.blue, Ds.green, Ds.goldDeep, Ds.red];
    return _tList(context, 'impact_areas').indexed.map<Widget>((entry) {
      final area = entry.$2;
      final accent = accents[entry.$1 % accents.length];
      final iconName = area is Map ? (area['icon'] ?? '').toString() : '';
      final title = (area is Map ? (area['title'] ?? '') : area).toString();
      final desc = area is Map ? (area['description'] ?? '').toString() : '';

      return DsCard(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            DsIconSquare(
              _impactIcons[iconName] ?? Icons.star_rounded,
              tint: accent.withValues(alpha: isDark ? 0.18 : 0.12),
              color: accent,
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

  Widget _buildBulletPoint(BuildContext context, String text, int index) {
    // Cycle the flag palette so a long list keeps some rhythm.
    const accents = [Ds.green, Ds.goldDeep, Ds.blue, Ds.red];
    final accent = accents[index % accents.length];

    return DsCard(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(Ds.rIcon),
            ),
            alignment: Alignment.center,
            child: Text('${index + 1}',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: accent)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                  fontSize: 14, height: 1.5, color: Ds.ink(context)),
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
                AppNetworkImage(
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

  Widget _videoPlaceholder(bool isDark) => Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[850] : Colors.grey[300],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Icon(Icons.videocam, size: 48, color: Colors.white54),
        ),
      );

  Widget _buildVideoThumbnail(BuildContext context, String videoUrl, String caption, bool isDark) {
    final poster = MediaVideoPlayerScreen.posterFor(videoUrl);
    return GestureDetector(
      onTap: videoUrl.isNotEmpty
          ? () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MediaVideoPlayerScreen(
                    videoUrl: videoUrl,
                    caption: caption,
                  ),
                ),
              )
          : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 240,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // YouTube gives us a poster frame for free; uploaded files
              // have no thumbnail, so they keep the placeholder.
              if (poster != null)
                AppNetworkImage(
                  imageUrl: poster,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => _videoPlaceholder(isDark),
                  placeholder: (_, _) => _videoPlaceholder(isDark),
                )
              else
                _videoPlaceholder(isDark),
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
                memCacheWidth: DataSaverService().fullImageCacheWidth,
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

}
