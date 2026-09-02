import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../config/app_ds.dart';
import '../../../config/environment.dart';
import '../../../models/magazine_model.dart';
import '../../../widgets/ds/ds_widgets.dart';
import '../../magazine/magazine_detail_screen.dart';

/// "Latest · Récents" row for a magazine issue: 74px cover and a gold
/// MAGAZINE · NEW ISSUE kicker.
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
    final fr = langCode == 'fr';
    final kicker = magazine.isFeatured
        ? (fr ? 'MAGAZINE · NOUVEAU NUMÉRO' : 'MAGAZINE · NEW ISSUE')
        : 'MAGAZINE';

    return DsCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      onTap: () => Navigator.push(
        context,
        CupertinoPageRoute(builder: (_) => MagazineDetailScreen(magazine: magazine)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(Ds.rTile),
            child: SizedBox(
              width: 74,
              height: 74,
              child: magazine.coverImageUrl.isEmpty
                  ? const DsImagePlaceholder(
                      radius: 0, icon: Icons.auto_stories_rounded)
                  : CachedNetworkImage(
                      imageUrl: Environment.fixMediaUrl(magazine.listImage),
                      fit: BoxFit.cover,
                      placeholder: (_, _) => const DsImagePlaceholder(
                          radius: 0, icon: Icons.auto_stories_rounded),
                      errorWidget: (_, _, _) => const DsImagePlaceholder(
                          radius: 0, icon: Icons.auto_stories_rounded),
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
                      color: Ds.goldDeep),
                ),
                const SizedBox(height: 3),
                Text(
                  magazine.getTitle(langCode),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                      color: Ds.ink(context)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right_rounded, size: 18, color: Ds.chevron),
        ],
      ),
    );
  }
}

/// Section heading for the magazine block, in the shared "See all" style.
class MagazineSectionTitle extends StatelessWidget {
  final String langCode;
  final VoidCallback? onSeeAll;
  final String? customTitle;

  const MagazineSectionTitle({
    super.key,
    required this.langCode,
    this.onSeeAll,
    this.customTitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(
          child: Text(
            customTitle ??
                (langCode == 'fr' ? 'Derniers numéros' : 'Latest magazines'),
            style: Ds.sectionTitle(context),
          ),
        ),
        GestureDetector(
          onTap: onSeeAll,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              langCode == 'fr' ? 'Voir tout' : 'See all',
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: Ds.green),
            ),
          ),
        ),
      ],
    );
  }
}
