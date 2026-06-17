import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../config/app_colors.dart';
import '../../../config/environment.dart';
import '../../../models/event_registration_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/api_service.dart';
import '../../feature_card/feature_card_detail_screen.dart';
import '../../events/event_detail_screen.dart';
import '../../news/article_detail_screen.dart';
import '../../magazine/magazine_detail_screen.dart';
import '../../videos/video_detail_screen.dart';
import '../painters/card_pattern_painter.dart';

class FeatureCardsSection extends StatelessWidget {
  final PageController pageController;
  final List<Map<String, dynamic>> featureCards;
  final int currentRawPage;
  final ValueChanged<int> onPageChanged;
  final List<EventRegistrationModel>? eventCards;

  const FeatureCardsSection({
    super.key,
    required this.pageController,
    required this.featureCards,
    required this.currentRawPage,
    required this.onPageChanged,
    this.eventCards,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 16),
        SizedBox(
          height: 180,
          child: PageView.builder(
            controller: pageController,
            onPageChanged: onPageChanged,
            itemBuilder: (context, index) {
              if (featureCards.isEmpty) return const SizedBox.shrink();
              final card = featureCards[index % featureCards.length];
              final gradientColors = card['gradient'] as List<Color>;
              final imageUrl = card['imageUrl'] as String?;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                child: GestureDetector(
                  onTap: () => _handleFeatureCardTap(context, card),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: gradientColors[0].withValues(alpha: 0.4),
                            blurRadius: 15,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (imageUrl != null && imageUrl.isNotEmpty)
                            CachedNetworkImage(
                              imageUrl: imageUrl,
                              fit: BoxFit.cover,
                              memCacheWidth: 800,
                              placeholder: (context, url) => Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: gradientColors,
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: gradientColors,
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
                                  colors: gradientColors,
                                ),
                              ),
                            ),
                          // Gradient overlay
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  gradientColors[0].withValues(alpha: 0.4),
                                  gradientColors[1].withValues(alpha: 0.85),
                                ],
                              ),
                            ),
                          ),
                          // Pattern overlay
                          CustomPaint(
                            size: const Size(double.infinity, 180),
                            painter: CardPatternPainter(),
                          ),
                          // Content
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        card['title'] as String,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontFamily: 'HeatherGreen',
                                          fontWeight: FontWeight.bold,
                                          shadows: [
                                            Shadow(
                                              color: Colors.black45,
                                              blurRadius: 3,
                                              offset: Offset(0, 1),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        card['description'] as String,
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.95),
                                          fontSize: 13,
                                          height: 1.4,
                                          shadows: const [
                                            Shadow(
                                              color: Colors.black38,
                                              blurRadius: 2,
                                              offset: Offset(0, 1),
                                            ),
                                          ],
                                        ),
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: _buildCardIcon(card, 40),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        // Dot indicators
        if (featureCards.isNotEmpty)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(featureCards.length, (index) {
              final activeIndex = currentRawPage % featureCards.length;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: activeIndex == index ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: activeIndex == index
                      ? AppColors.burundiGreen
                      : AppColors.burundiGreen.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
      ],
    );
  }

  Widget _buildCardIcon(Map<String, dynamic> card, double size) {
    final iconImageUrl = card['iconImageUrl'] as String? ?? '';
    if (iconImageUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: Environment.fixMediaUrl(iconImageUrl),
        width: size,
        height: size,
        memCacheWidth: 128,
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

  void _handleFeatureCardTap(BuildContext context, Map<String, dynamic> card) {
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
        final matchingEvent = eventCards!.where((e) => e.id == eventId).toList();
        if (matchingEvent.isNotEmpty) {
          Navigator.push(
            context,
            CupertinoPageRoute(
              builder: (_) => EventDetailScreen(event: matchingEvent.first, scrollToComments: context.read<AuthProvider>().isAuthenticated),
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

  void _navigateToArticle(BuildContext context, String articleId) async {
    try {
      final article = await ApiService().getArticle(articleId);
      if (!context.mounted) return;
      Navigator.push(
        context,
        CupertinoPageRoute(
          builder: (_) => ArticleDetailScreen(
            article: article,
            scrollToComments: context.read<AuthProvider>().isAuthenticated,
          ),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      Navigator.pushNamed(context, '/news');
    }
  }

  void _navigateToMagazine(BuildContext context, String magazineId) async {
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

  void _navigateToVideo(BuildContext context, String videoId) async {
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
            scrollToComments: context.read<AuthProvider>().isAuthenticated,
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
