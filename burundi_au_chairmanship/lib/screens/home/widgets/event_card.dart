import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../config/app_ds.dart';
import '../../../models/event_registration_model.dart';
import '../../../widgets/ds/ds_widgets.dart';

/// "Upcoming events · À venir" row: a 48px date block, the title and venue,
/// then either a status pill or a chevron.
class EventCard extends StatelessWidget {
  final EventRegistrationModel event;
  final String langCode;
  final VoidCallback onTap;

  const EventCard({
    super.key,
    required this.event,
    required this.langCode,
    required this.onTap,
  });

  bool get _isGreeting => event.cardType == 'greeting';

  @override
  Widget build(BuildContext context) {
    final fr = langCode == 'fr';
    final date = event.eventDate;
    final venue = event.getVenue(langCode);
    final time = date == null ? '' : DateFormat('HH:mm').format(date);
    final meta = [if (time.isNotEmpty) time, if (venue.isNotEmpty) venue].join(' · ');

    return DsCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: onTap,
      child: Row(
        children: [
          if (!_isGreeting) ...[
            _dateBlock(context, date, langCode),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.getTitle(langCode),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Ds.cardTitle(context),
                ),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Ds.cardBody(context)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (event.hasRegistered)
            DsPill(fr ? 'Inscrit' : 'Registered', dense: true)
          else
            const Icon(Icons.chevron_right_rounded, size: 18, color: Ds.chevron),
        ],
      ),
    );
  }

  Widget _dateBlock(BuildContext context, DateTime? date, String lang) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Ds.tint(context),
        borderRadius: BorderRadius.circular(Ds.rTile),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            date == null ? '—' : DateFormat('MMM', lang).format(date).toUpperCase(),
            style: const TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700, color: Ds.green),
          ),
          Text(
            date == null ? '' : '${date.day}',
            style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                height: 1,
                color: Ds.greenDeep),
          ),
        ],
      ),
    );
  }
}
