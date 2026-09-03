import 'package:flutter/material.dart';
import '../../models/event_registration_model.dart';
import '../../config/app_ds.dart';
import 'package:url_launcher/url_launcher.dart';

class EventInfoCard extends StatelessWidget {
  final EventRegistrationModel event;
  final String langCode;
  final bool isDark;

  const EventInfoCard({
    super.key,
    required this.event,
    required this.langCode,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final description = event.getDescription(langCode);
    final venue = event.getVenue(langCode);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Ds.surface(context),
        borderRadius: BorderRadius.circular(Ds.rCard),
        boxShadow: Ds.shadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (description.isNotEmpty) ...[
            Text(
              description,
              style: TextStyle(
                fontSize: 14,
                height: 1.65,
                color: Ds.body(context),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Date range for multi-day events
          if (event.eventDate != null && event.isMultiDay) ...[
            _infoRow(
              Icons.calendar_today,
              '${_formatShortDate(event.eventDate!)} - ${_formatShortDate(event.eventEndDate!)}',
              isDark,
            ),
            const SizedBox(height: 6),
            _infoRow(
              Icons.date_range,
              '${event.totalDays} days',
              isDark,
            ),
          ] else if (event.eventDate != null)
            _infoRow(
              Icons.calendar_today,
              _formatFullDate(event.eventDate!),
              isDark,
            ),

          // Venue
          if (venue.isNotEmpty) ...[
            const SizedBox(height: 10),
            _infoRow(Icons.location_on, venue, isDark),
          ],

          // Directions button
          if (event.venueAddress.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _openDirections(event.venueAddress),
                icon: const Icon(Icons.directions, size: 18),
                label: const Text('Get Directions'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Ds.green,
                  side: const BorderSide(color: Ds.green, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Ds.rPill),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(width: 0),
        Icon(icon, size: 18, color: Ds.green),
        const SizedBox(width: 9),
        Expanded(
          child: Builder(
            builder: (context) => Text(
              text,
              style: TextStyle(fontSize: 13, color: Ds.ink(context)),
            ),
          ),
        ),
      ],
    );
  }

  String _formatFullDate(DateTime date) {
    final months = ['January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'];
    final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    final amPm = date.hour >= 12 ? 'PM' : 'AM';
    return '${months[date.month - 1]} ${date.day}, ${date.year} at $hour:${date.minute.toString().padLeft(2, '0')} $amPm';
  }

  String _formatShortDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  void _openDirections(String address) {
    final encodedAddress = Uri.encodeComponent(address);
    launchUrl(
      Uri.parse('https://www.google.com/maps/search/?api=1&query=$encodedAddress'),
      mode: LaunchMode.externalApplication,
    );
  }
}
