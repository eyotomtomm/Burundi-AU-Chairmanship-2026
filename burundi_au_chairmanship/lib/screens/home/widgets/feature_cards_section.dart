import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../widgets/app_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../config/app_ds.dart';
import '../../../config/environment.dart';
import '../../../models/event_registration_model.dart';
import '../../../services/api_service.dart';
import '../../feature_card/feature_card_detail_screen.dart';
import '../../events/event_detail_screen.dart';
import '../../news/article_detail_screen.dart';
import '../../magazine/magazine_detail_screen.dart';
import '../../videos/video_detail_screen.dart';
import '../../../widgets/ds/ds_widgets.dart';
import 'section_title.dart';

class FeatureCardsSection extends StatelessWidget {
  final List<Map<String, dynamic>> featureCards;
  final List<EventRegistrationModel>? eventCards;

  const FeatureCardsSection({
    super.key,
    required this.featureCards,
    this.eventCards,
  });

  @override
  Widget build(BuildContext context) {
    if (featureCards.isEmpty) return const SizedBox.shrink();
    final fr = Localizations.localeOf(context).languageCode == 'fr';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
          child: SectionTitle(
              title: fr ? 'Découvrir le Burundi' : 'Discover Burundi'),
        ),
        // Wide photo rail — big enough for the image to actually carry the
        // section, with the next card peeking to invite the swipe.
        SizedBox(
          height: 200,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: featureCards.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final card = featureCards[index];
              return SizedBox(
                width: 268,
                child: _FeatureCard(
                  card: card,
                  index: index,
                  langCode: fr ? 'fr' : 'en',
                  icon: _buildCardIcon(card, 18),
                  onTap: () => handleFeatureCardTap(context, card,
                      eventCards: eventCards),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCardIcon(Map<String, dynamic> card, double size) {
    final iconImageUrl = card['iconImageUrl'] as String? ?? '';
    if (iconImageUrl.isNotEmpty) {
      return AppNetworkImage(
        imageUrl: Environment.fixMediaUrl(iconImageUrl),
        width: size,
        height: size,
        fit: BoxFit.contain,
        placeholder: (_, _) => Icon(
          card['icon'] as IconData? ?? Icons.stars,
          color: Colors.white,
          size: size,
        ),
        errorWidget: (_, _, _) => Icon(
          card['icon'] as IconData? ?? Icons.stars,
          color: Colors.white,
          size: size,
        ),
      );
    }
    return Icon(
      card['icon'] as IconData? ?? Icons.stars,
      color: Colors.white,
      size: size,
    );
  }


  /// Opens whatever a feature card points at. Static so other surfaces
  /// (the home "New today" rail) route admin cards the same way.
  static void handleFeatureCardTap(BuildContext context, Map<String, dynamic> card,
      {List<EventRegistrationModel>? eventCards}) {
    final actionType = card['actionType'] as String?;
    final actionValue = card['actionValue'] as String?;

    if (actionType == 'url' && actionValue != null && actionValue.isNotEmpty) {
      final uri = Uri.tryParse(actionValue);
      if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
        launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }
    if (actionType == 'route' && actionValue != null && actionValue.isNotEmpty && actionValue != '/feature-detail') {
      if (actionValue.startsWith('/')) {
        Navigator.pushNamed(context, actionValue);
      }
      return;
    }

    if (actionType == 'event' && actionValue != null && actionValue.isNotEmpty) {
      final eventId = int.tryParse(actionValue);
      if (eventId != null && eventCards != null) {
        final matchingEvent = eventCards.where((e) => e.id == eventId).toList();
        if (matchingEvent.isNotEmpty) {
          Navigator.push(
            context,
            CupertinoPageRoute(
              builder: (_) => EventDetailScreen(event: matchingEvent.first, scrollToComments: false),
            ),
          );
          return;
        }
      }
      Navigator.pushNamed(context, '/calendar');
      return;
    }

    if (actionType == 'article' && actionValue != null && actionValue.isNotEmpty) {
      _navigateToArticle(context, actionValue);
      return;
    }

    if (actionType == 'magazine' && actionValue != null && actionValue.isNotEmpty) {
      _navigateToMagazine(context, actionValue);
      return;
    }

    if (actionType == 'youth_dialogue') {
      Navigator.pushNamed(context, '/youth-dialogue');
      return;
    }

    if (actionType == 'video' && actionValue != null && actionValue.isNotEmpty) {
      _navigateToVideo(context, actionValue);
      return;
    }

    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => FeatureCardDetailScreen(cardData: card),
      ),
    );
  }

  static void _navigateToArticle(BuildContext context, String articleId) async {
    try {
      final article = await ApiService().getArticle(articleId);
      if (!context.mounted) return;
      Navigator.push(
        context,
        CupertinoPageRoute(
          builder: (_) => ArticleDetailScreen(
            article: article,
            scrollToComments: false,
          ),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      Navigator.pushNamed(context, '/news');
    }
  }

  static void _navigateToMagazine(BuildContext context, String magazineId) async {
    try {
      final magazines = await ApiService().getMagazines();
      final match = magazines.where((m) => m.id == magazineId).toList();
      if (!context.mounted) return;
      if (match.isNotEmpty) {
        final mag = match.first;
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (_) => MagazineDetailScreen(magazine: mag),
          ),
        );
      } else {
        Navigator.pushNamed(context, '/magazine');
      }
    } catch (_) {
      if (!context.mounted) return;
      Navigator.pushNamed(context, '/magazine');
    }
  }

  static void _navigateToVideo(BuildContext context, String videoId) async {
    try {
      final videos = await ApiService().getVideos();
      final match = videos.where((v) => v['id']?.toString() == videoId).toList();
      if (!context.mounted) return;
      if (match.isNotEmpty) {
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (_) => VideoDetailScreen(
            video: match.first,
            scrollToComments: false,
          ),
          ),
        );
      } else {
        Navigator.pushNamed(context, '/videos');
      }
    } catch (_) {
      if (!context.mounted) return;
      Navigator.pushNamed(context, '/videos');
    }
  }
}

/// Photo card with a bottom scrim — the comp's featured-card treatment.
class _FeatureCard extends StatelessWidget {
  final Map<String, dynamic> card;
  final VoidCallback onTap;
  final Widget icon;
  final int index;
  final String langCode;

  const _FeatureCard({
    required this.card,
    required this.onTap,
    required this.icon,
    required this.index,
    required this.langCode,
  });

  @override
  Widget build(BuildContext context) {
    final fr = langCode == 'fr';
    final imageUrl = Environment.fixMediaUrl(card['imageUrl'] as String? ?? '');
    final gradient = (card['gradient'] as List<Color>?) ?? const [Ds.green, Ds.greenDeep];
    final description = card['description'] as String? ?? '';

    // Cards without a photo still get something to look at: the admin's
    // gradient plus an oversized icon bleeding off the corner.
    // NOTE: this fallback MUST stay in its own `final`. Assigning it to a
    // mutable `background` and then reassigning that variable to the
    // CachedNetworkImage makes the placeholder/errorWidget closures capture the
    // *variable* — which by then is the image itself. The placeholder then
    // resolves to the image, forever: StackOverflowError building OctoImage,
    // HomeScreen never finishes its first build, and the app hangs on the
    // splash with no crash and no log. This has regressed twice; don't inline it.
    final Widget fallbackBackground = Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradient,
            ),
          ),
        ),
        Positioned(
          right: -20,
          bottom: -26,
          child: Icon(card['icon'] as IconData? ?? Icons.stars_rounded,
              size: 150, color: Colors.white.withValues(alpha: 0.13)),
        ),
      ],
    );
    final Widget background = imageUrl.isEmpty
        ? fallbackBackground
        : AppNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            placeholder: (_, _) => fallbackBackground,
            errorWidget: (_, _, _) => fallbackBackground,
          );

    return DsCard(
      featured: true,
      clip: true,
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          background,
          // Bottom scrim so the title stays legible over any photo.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x1A000000), Color(0x00000000), Color(0xE0000000)],
                stops: [0.0, 0.32, 1.0],
              ),
            ),
          ),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.32),
                    borderRadius: BorderRadius.circular(Ds.rPill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(width: 18, height: 18, child: FittedBox(child: icon)),
                      const SizedBox(width: 6),
                      Text(
                        '${(index + 1).toString().padLeft(2, '0')} · ${fr ? 'DÉCOUVRIR' : 'DISCOVER'}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.9,
                          color: Ds.gold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 14,
            right: 14,
            bottom: 14,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        card['title'] as String? ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                          letterSpacing: -0.3,
                        ),
                      ),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                  ),
                  child: const Icon(Icons.arrow_forward_rounded,
                      size: 17, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
