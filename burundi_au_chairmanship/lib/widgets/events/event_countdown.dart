import 'package:flutter/material.dart';
import '../../models/event_registration_model.dart';

class EventCountdown extends StatelessWidget {
  final EventRegistrationModel event;
  final Duration? timeLeft;
  final bool isDark;

  const EventCountdown({
    super.key,
    required this.event,
    required this.timeLeft,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (event.eventDate == null) return const SizedBox.shrink();

    final isPast = event.isEventPast;

    if (isPast) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, color: Colors.grey.shade600),
            const SizedBox(width: 8),
            Text(
              'Event Ended',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    if (timeLeft == null) return const SizedBox.shrink();

    final days = timeLeft!.inDays;
    final hours = timeLeft!.inHours % 24;
    final minutes = timeLeft!.inMinutes % 60;
    final seconds = timeLeft!.inSeconds % 60;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF409843), Color(0xFF2D6E31)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Text(
            'Event Starts In',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _countdownBox('$days', 'Days'),
              _countdownDivider(),
              _countdownBox(hours.toString().padLeft(2, '0'), 'Hours'),
              _countdownDivider(),
              _countdownBox(minutes.toString().padLeft(2, '0'), 'Min'),
              _countdownDivider(),
              _countdownBox(seconds.toString().padLeft(2, '0'), 'Sec'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _countdownBox(String value, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ],
    );
  }

  Widget _countdownDivider() {
    return const Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Text(
        ':',
        style: TextStyle(
          color: Colors.white70,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
