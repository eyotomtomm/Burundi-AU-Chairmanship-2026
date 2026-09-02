import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../config/app_ds.dart';
import '../../../config/environment.dart';
import '../../../models/magazine_model.dart';
import '../../../widgets/ds/ds_widgets.dart';

/// "Latest · Récents" row: 74px thumbnail, green NEWS kicker, then the
/// headline and how long ago it was published.
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

  String _timeAgo(DateTime date, bool fr) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return fr ? 'il y a ${diff.inMinutes} min' : '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return fr ? 'il y a ${diff.inHours} h' : '${diff.inHours}h ago';
    if (diff.inDays < 7) return fr ? 'il y a ${diff.inDays} j' : '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final fr = langCode == 'fr';
    final kicker =
        article.category?.getDisplayName(langCode).toUpperCase() ??
            (fr ? 'ACTUALITÉS' : 'NEWS');

    return DsCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      onTap: onTap,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(Ds.rTile),
            child: SizedBox(
              width: 74,
              height: 74,
              child: CachedNetworkImage(
                imageUrl: Environment.fixMediaUrl(article.listImage),
                fit: BoxFit.cover,
                placeholder: (_, _) => const DsImagePlaceholder(radius: 0),
                errorWidget: (_, _, _) =>
                    const DsImagePlaceholder(radius: 0, icon: Icons.article_rounded),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  kicker,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: Ds.green),
                ),
                const SizedBox(height: 3),
                Text(
                  article.getTitle(langCode),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                      color: Ds.ink(context)),
                ),
                const SizedBox(height: 4),
                Text(_timeAgo(article.publishDate, fr), style: Ds.meta(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
