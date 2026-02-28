import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';

/// Custom painter that draws a zigzag line pattern
///
/// Used for decorative borders and dividers throughout the home screen
class ZigzagLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.auGold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final path = Path();
    path.moveTo(0, size.height / 2);
    for (double x = 0; x < size.width; x += 15) {
      final y = size.height / 2 + (((x ~/ 15) % 2 == 0) ? -4 : 4);
      path.lineTo(x + 7.5, y);
      path.lineTo(x + 15, size.height / 2);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
