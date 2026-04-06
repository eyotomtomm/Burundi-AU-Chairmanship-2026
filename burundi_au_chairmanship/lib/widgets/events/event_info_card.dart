import 'package:flutter/material.dart';
import '../../models/event_registration_model.dart';
import '../../config/app_colors.dart';
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
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFE0E0E0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (description.isNotEmpty) ...[
            Text(
              description,
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Date
          if (event.eventDate != null)
            _infoRow(
              Icons.calendar_today,
              _formatFullDate(event.eventDate!),
              isDark,
            ),

          // End date
          if (event.eventEndDate != null) ...[
            const SizedBox(height: 10),
            _infoRow(
              Icons.event_available,
              'Until ${_formatFullDate(event.eventEndDate!)}',
              isDark,
            ),
          ],

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
                  foregroundColor: AppColors.burundiGreen,
                  side: const BorderSide(color: AppColors.burundiGreen),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
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
        Icon(icon, size: 18, color: AppColors.burundiGreen),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white70 : Colors.black87,
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

  void _openDirections(String address) {
    final encodedAddress = Uri.encodeComponent(address);
    launchUrl(
      Uri.parse('https://www.google.com/maps/search/?api=1&query=$encodedAddress'),
      mode: LaunchMode.externalApplication,
    );
  }
}
