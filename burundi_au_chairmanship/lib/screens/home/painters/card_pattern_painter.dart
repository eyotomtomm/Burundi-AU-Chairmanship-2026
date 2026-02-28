import 'package:flutter/material.dart';

/// Custom painter that draws a decorative zigzag pattern at the bottom of cards
///
/// Used to add visual interest to card layouts in the home screen
class CardPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Zigzag at bottom
    final path = Path();
    path.moveTo(0, size.height - 15);
    for (double x = 0; x < size.width; x += 20) {
      path.lineTo(x + 10, size.height - 25);
      path.lineTo(x + 20, size.height - 15);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
