import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../config/app_ds.dart';
import '../../../config/environment.dart';
import '../../../models/fact_model.dart';
import '../../../widgets/ds/ds_widgets.dart';
import '../../facts/fact_detail_screen.dart';

/// "Discover Africa" rail card — white surface, photo top, green kicker,
/// matching the news/event cards in the comp.
class FactCard extends StatelessWidget {
  final Fact fact;
  final String langCode;
  final int index;

  const FactCard({
    super.key,
    required this.fact,
    required this.langCode,
    this.index = 0,
  });

  @override
  Widget build(BuildContext context) {
    final isQuote = fact.isQuote;
    final imageUrl = Environment.fixMediaUrl(fact.image);
    final kicker = (fact.category?.getDisplayName(langCode) ??
            (isQuote
                ? (langCode == 'fr' ? 'CITATION' : 'QUOTE')
                : (langCode == 'fr' ? 'LE SAVIEZ-VOUS' : 'DID YOU KNOW')))
        .toUpperCase();

    return DsCard(
      clip: true,
      onTap: () => Navigator.push(
        context,
        CupertinoPageRoute(
            builder: (_) => FactDetailScreen(factId: fact.id, fact: fact)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 78,
            width: double.infinity,
            child: imageUrl.isEmpty
                ? DsImagePlaceholder(
                    radius: 0,
                    icon: isQuote
                        ? Icons.format_quote_rounded
                        : Icons.auto_awesome_rounded,
                  )
                : CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, _) =>
                        const DsImagePlaceholder(radius: 0),
                    errorWidget: (_, _, _) => const DsImagePlaceholder(
                        radius: 0, icon: Icons.auto_awesome_rounded),
                  ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    kicker,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: Ds.green),
                  ),
                  const SizedBox(height: 3),
                  Expanded(
                    child: Text(
                      isQuote
                          ? fact.getContentPreview(langCode)
                          : fact.getTitle(langCode),
                      maxLines: isQuote ? 3 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                        fontStyle: isQuote ? FontStyle.italic : FontStyle.normal,
                        color: Ds.ink(context),
                      ),
                    ),
                  ),
                  if (isQuote && fact.authorName.isNotEmpty)
                    Text('— ${fact.authorName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Ds.meta(context))
                  else if (!isQuote)
                    Text(
                      fact.getContentPreview(langCode),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Ds.cardBody(context),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
