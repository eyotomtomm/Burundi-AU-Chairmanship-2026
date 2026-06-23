import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../config/app_colors.dart';
import '../../../config/environment.dart';
import '../../../models/magazine_model.dart';
import '../../../services/like_service.dart';
import '../../../services/data_saver_service.dart';
import '../../../widgets/liked_by_avatars.dart';

class NewsCard extends StatelessWidget {
  final Article article;
  final String langCode;
  final VoidCallback onTap;

  const NewsCard({
    super.key,
    required this.article,
    required this.langCode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final catColor = article.category?.parsedColor ?? AppColors.burundiGreen;
    final catLabel = article.category?.getDisplayName(langCode) ?? '';
    final date = '${article.publishDate.day}/${article.publishDate.month}/${article.publishDate.year}';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 260,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image with category badge
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              child: SizedBox(
                height: 120,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (article.imageUrl.isNotEmpty)
                      CachedNetworkImage(
                        imageUrl: Environment.fixMediaUrl(article.imageUrl),
                        memCacheWidth: DataSaverService().heroCacheWidth ?? 400,
                        fit: BoxFit.cover,
                        placeholder: (_, _) => Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                catColor.withValues(alpha: 0.6),
                                catColor.withValues(alpha: 0.3),
                              ],
                            ),
                          ),
                        ),
                        errorWidget: (_, _, _) => Container(
                          color: catColor.withValues(alpha: 0.2),
                          child: Icon(Icons.article_rounded, size: 40, color: Colors.white.withValues(alpha: 0.5)),
                        ),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              catColor.withValues(alpha: 0.8),
                              catColor.withValues(alpha: 0.4),
                            ],
                          ),
                        ),
                        child: Center(
                          child: Icon(Icons.article_rounded, size: 40, color: Colors.white.withValues(alpha: 0.5)),
                        ),
                      ),
                    // Category badge
                    if (catLabel.isNotEmpty)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: catColor,
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            catLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(
                                  color: Colors.black26,
                                  blurRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    // Date badge
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.auGold,
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          date,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                color: Colors.black26,
                                blurRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      article.getTitle(langCode),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    // Engagement stats row
                    Row(
                      children: [
                        Icon(Icons.visibility_rounded, size: 13,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                        const SizedBox(width: 3),
                        Text(
                          '${article.viewCount}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 11,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Icon(Icons.chat_bubble_outline_rounded, size: 13,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                        const SizedBox(width: 3),
                        Text(
                          '${article.commentCount}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 11,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Builder(builder: (_) {
                          final likeService = LikeService();
                          likeService.seed(EntityType.article, article.id,
                            isLiked: article.isLiked, likeCount: article.likeCount, recentLikers: article.recentLikers);
                          final ls = likeService.getState(EntityType.article, article.id);
                          final likeColor = ls.isLiked
                              ? AppColors.burundiRed
                              : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary);
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                ls.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                size: 16, color: likeColor,
                              ),
                              const SizedBox(width: 3),
                              Text('${ls.likeCount}', style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 12, fontWeight: FontWeight.w600, color: likeColor)),
                              const SizedBox(width: 3),
                              Text('Like', style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 11, color: likeColor)),
                              if (ls.recentLikers.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                LikedByAvatars(likers: ls.recentLikers, totalLikes: ls.likeCount, avatarRadius: 8, overlap: 6),
                              ],
                            ],
                          );
                        }),
                        const Spacer(),
                        Flexible(
                          child: Text(
                            article.author,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 10,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
