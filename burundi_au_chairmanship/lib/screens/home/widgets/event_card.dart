import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../config/app_colors.dart';
import '../../../config/environment.dart';
import '../../../models/event_registration_model.dart';

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
    if (_isGreeting) return _buildGreetingCard();
    return _buildEventCard();
  }

  Widget _buildGreetingCard() {
    final title = event.getTitle(langCode);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 260,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFD4A017).withValues(alpha: 0.25),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background image or festive gradient
              if (event.eventPoster != null && event.eventPoster!.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: Environment.fixMediaUrl(event.eventPoster!),
                  fit: BoxFit.cover,
                  placeholder: (context, url) => _greetingGradient(),
                  errorWidget: (context, url, error) => _greetingGradient(),
                )
              else
                _greetingGradient(),

              // Warm overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF1A0A2E).withValues(alpha: 0.15),
                      const Color(0xFF1A0A2E).withValues(alpha: 0.7),
                    ],
                    stops: const [0.2, 1.0],
                  ),
                ),
              ),

              // Gold corner accents
              Positioned(
                top: 8,
                left: 8,
                child: _goldCorner(topLeft: true),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: _goldCorner(topLeft: false),
              ),

              // Greeting badge (top-right)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFD4A017), Color(0xFFF0D060)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome, color: Colors.white, size: 12),
                      SizedBox(width: 4),
                      Text(
                        'Greeting',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom content
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Decorative line
                      Container(
                        width: 36,
                        height: 2,
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFD4A017), Color(0xFFF0D060)],
                          ),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                          shadows: [
                            Shadow(color: Colors.black45, blurRadius: 3, offset: Offset(0, 1)),
                          ],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (event.eventDate != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.celebration, color: const Color(0xFFF0D060).withValues(alpha: 0.9), size: 13),
                            const SizedBox(width: 4),
                            Text(
                              _formatDate(event.eventDate!),
                              style: TextStyle(
                                color: const Color(0xFFF0D060).withValues(alpha: 0.9),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _goldCorner({required bool topLeft}) {
    return SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(
        painter: _CardCornerPainter(topLeft: topLeft),
      ),
    );
  }

  Widget _buildEventCard() {
    final title = event.getTitle(langCode);
    final venue = event.getVenue(langCode);
    final countdown = event.timeUntilEvent;
    final isPast = event.isEventPast;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 260,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background image or gradient
              if (event.eventPoster != null && event.eventPoster!.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: Environment.fixMediaUrl(event.eventPoster!),
                  fit: BoxFit.cover,
                  placeholder: (context, url) => _gradientFallback(),
                  errorWidget: (context, url, error) => _gradientFallback(),
                )
              else
                _gradientFallback(),

              // Dark gradient overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.1),
                      Colors.black.withValues(alpha: 0.75),
                    ],
                    stops: const [0.3, 1.0],
                  ),
                ),
              ),

              // Countdown badge (top-right)
              if (countdown != null || isPast)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isPast
                          ? Colors.grey.shade700
                          : AppColors.burundiRed,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isPast ? 'Ended' : _formatCountdown(countdown!),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

              // Registration status badge (top-left)
              if (event.hasRegistered)
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.burundiGreen,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, color: Colors.white, size: 12),
                        SizedBox(width: 4),
                        Text(
                          'Registered',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Bottom content
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                          shadows: [
                            Shadow(color: Colors.black45, blurRadius: 3, offset: Offset(0, 1)),
                          ],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (venue.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.location_on, color: Colors.white70, size: 13),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                venue,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (event.eventDate != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today, color: Colors.white70, size: 13),
                            const SizedBox(width: 4),
                            Text(
                              _formatDate(event.eventDate!),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _gradientFallback() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1EB53A), Color(0xFF065A1A)],
        ),
      ),
      child: const Center(
        child: Icon(Icons.event, size: 48, color: Colors.white30),
      ),
    );
  }

  Widget _greetingGradient() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2D1B69), Color(0xFF1A0A2E), Color(0xFF0D0521)],
        ),
      ),
      child: Center(
        child: Icon(Icons.auto_awesome, size: 48, color: const Color(0xFFD4A017).withValues(alpha: 0.3)),
      ),
    );
  }

  String _formatCountdown(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays}d left';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h left';
    } else {
      return '${duration.inMinutes}m left';
    }
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

class _CardCornerPainter extends CustomPainter {
  final bool topLeft;
  _CardCornerPainter({required this.topLeft});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD4A017).withValues(alpha: 0.6)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path();
    if (topLeft) {
      path.moveTo(0, size.height * 0.7);
      path.lineTo(0, 0);
      path.lineTo(size.width * 0.7, 0);
    } else {
      path.moveTo(size.width * 0.3, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width, size.height * 0.7);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
