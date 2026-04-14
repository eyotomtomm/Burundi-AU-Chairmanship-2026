import 'package:flutter/material.dart';

/// Draws a curved shadow arc along the right edge to simulate a page curl.
class PageCurlPainter extends CustomPainter {
  final double progress; // 0.0 = no curl, 1.0 = full curl
  final bool isForward; // true = curling from right, false = from left

  PageCurlPainter({required this.progress, this.isForward = true});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0) return;

    final curlWidth = size.width * 0.15 * progress;
    final x = isForward ? size.width - curlWidth : curlWidth;

    // Shadow gradient behind the curl
    final shadowPaint = Paint()
      ..shader = LinearGradient(
        begin: isForward ? Alignment.centerRight : Alignment.centerLeft,
        end: isForward ? Alignment.centerLeft : Alignment.centerRight,
        colors: [
          Colors.black.withValues(alpha: 0.25 * progress),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(
        isForward ? x : 0,
        0,
        curlWidth,
        size.height,
      ));

    final shadowRect = Rect.fromLTWH(
      isForward ? x : 0,
      0,
      curlWidth,
      size.height,
    );
    canvas.drawRect(shadowRect, shadowPaint);

    // Glossy highlight line along the curl edge
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3 * progress)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final curlPath = Path();
    final edgeX = isForward ? size.width - curlWidth * 0.3 : curlWidth * 0.3;
    final controlOffset = curlWidth * 0.5;

    curlPath.moveTo(edgeX, 0);
    curlPath.quadraticBezierTo(
      edgeX + (isForward ? controlOffset : -controlOffset),
      size.height * 0.5,
      edgeX,
      size.height,
    );
    canvas.drawPath(curlPath, highlightPaint);

    // Subtle curved shadow arc
    final arcPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.08 * progress)
      ..strokeWidth = curlWidth * 0.6
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    final arcPath = Path();
    final arcX = isForward ? size.width : 0.0;
    arcPath.moveTo(arcX, 0);
    arcPath.quadraticBezierTo(
      arcX + (isForward ? -curlWidth * 0.8 : curlWidth * 0.8),
      size.height * 0.5,
      arcX,
      size.height,
    );
    canvas.drawPath(arcPath, arcPaint);
  }

  @override
  bool shouldRepaint(PageCurlPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.isForward != isForward;
}
