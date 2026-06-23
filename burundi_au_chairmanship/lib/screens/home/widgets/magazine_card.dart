import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../config/app_colors.dart';
import '../../../config/environment.dart';
import '../../../models/magazine_model.dart';
import '../../magazine/magazine_detail_screen.dart';

class MagazineCard extends StatelessWidget {
  final MagazineEdition magazine;
  final String langCode;

  const MagazineCard({
    super.key,
    required this.magazine,
    required this.langCode,
  });

  @override
  Widget build(BuildContext context) {
    final title = magazine.getTitle(langCode);
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (_) => MagazineDetailScreen(magazine: magazine),
          ),
        );
      },
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: magazine.coverImageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: Environment.fixMediaUrl(magazine.thumbnailUrl.isNotEmpty ? magazine.thumbnailUrl : magazine.coverImageUrl),
                      memCacheWidth: 400,
                      width: 140,
                      height: 170,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        width: 140,
                        height: 170,
                        color: Colors.grey[300],
                        child: const Center(
                          child: CupertinoActivityIndicator(),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: 140,
                        height: 170,
                        color: Colors.grey[300],
                        child: const Icon(Icons.menu_book, size: 40, color: Colors.grey),
                      ),
                    )
                  : Container(
                      width: 140,
                      height: 170,
                      color: Colors.grey[300],
                      child: const Icon(Icons.menu_book, size: 40, color: Colors.grey),
                    ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MagazineSectionTitle extends StatelessWidget {
  final String langCode;
  final VoidCallback? onSeeAll;

  const MagazineSectionTitle({
    super.key,
    required this.langCode,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.burundiGreen, AppColors.auGold],
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              langCode == 'fr' ? 'Derniers Magazines' : 'Latest Magazines',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        TextButton(
          onPressed: onSeeAll,
          child: Row(
            children: [
              Text(
                langCode == 'fr' ? 'Voir tout' : 'See All',
                style: const TextStyle(color: AppColors.burundiGreen),
              ),
              const Icon(Icons.chevron_right, color: AppColors.burundiGreen, size: 18),
            ],
          ),
        ),
      ],
    );
  }
}
