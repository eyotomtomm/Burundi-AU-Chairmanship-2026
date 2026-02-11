import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../config/app_colors.dart';

class AfricanPatternPainter extends CustomPainter {
  final Color primaryColor;
  final Color secondaryColor;
  final Color accentColor;
  final double opacity;
  final bool boldPattern;

  AfricanPatternPainter({
    this.primaryColor = AppColors.patternOrange,
    this.secondaryColor = AppColors.patternBrown,
    this.accentColor = AppColors.auGold,
    this.opacity = 0.15,
    this.boldPattern = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = boldPattern ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = boldPattern ? 3.0 : 2.0;

    final double patternSize = boldPattern ? 80.0 : 60.0;
    final int cols = (size.width / patternSize).ceil() + 1;
    final int rows = (size.height / patternSize).ceil() + 1;

    for (int i = 0; i < rows; i++) {
      for (int j = 0; j < cols; j++) {
        final double x = j * patternSize;
        final double y = i * patternSize;

        if ((i + j) % 4 == 0) {
          _drawDiamondPattern(canvas, paint, x, y, patternSize);
        } else if ((i + j) % 4 == 1) {
          _drawChevronPattern(canvas, paint, x, y, patternSize);
        } else if ((i + j) % 4 == 2) {
          _drawZigZagPattern(canvas, paint, x, y, patternSize);
        } else {
          _drawTrianglePattern(canvas, paint, x, y, patternSize);
        }
      }
    }
  }

  void _drawDiamondPattern(Canvas canvas, Paint paint, double x, double y, double size) {
    paint.color = primaryColor.withValues(alpha: opacity);
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 2;

    final path = Path();
    final center = Offset(x + size / 2, y + size / 2);
    final halfSize = size / 3;

    path.moveTo(center.dx, center.dy - halfSize);
    path.lineTo(center.dx + halfSize, center.dy);
    path.lineTo(center.dx, center.dy + halfSize);
    path.lineTo(center.dx - halfSize, center.dy);
    path.close();

    canvas.drawPath(path, paint);

    // Inner diamond
    paint.color = secondaryColor.withValues(alpha: opacity * 0.8);
    final innerPath = Path();
    final innerHalfSize = halfSize * 0.5;

    innerPath.moveTo(center.dx, center.dy - innerHalfSize);
    innerPath.lineTo(center.dx + innerHalfSize, center.dy);
    innerPath.lineTo(center.dx, center.dy + innerHalfSize);
    innerPath.lineTo(center.dx - innerHalfSize, center.dy);
    innerPath.close();

    canvas.drawPath(innerPath, paint);

    // Center dot
    paint.style = PaintingStyle.fill;
    paint.color = accentColor.withValues(alpha: opacity);
    canvas.drawCircle(center, 4, paint);
  }

  void _drawChevronPattern(Canvas canvas, Paint paint, double x, double y, double size) {
    paint.color = accentColor.withValues(alpha: opacity);
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 2.5;

    final centerX = x + size / 2;
    final startY = y + size * 0.2;
    final chevronHeight = size * 0.15;
    final chevronWidth = size * 0.4;

    for (int i = 0; i < 3; i++) {
      final path = Path();
      final currentY = startY + i * chevronHeight * 1.5;

      path.moveTo(centerX - chevronWidth, currentY + chevronHeight);
      path.lineTo(centerX, currentY);
      path.lineTo(centerX + chevronWidth, currentY + chevronHeight);

      canvas.drawPath(path, paint);
    }
  }

  void _drawTrianglePattern(Canvas canvas, Paint paint, double x, double y, double size) {
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 2;

    // Upper triangle
    paint.color = secondaryColor.withValues(alpha: opacity);
    final path = Path();
    final halfSize = size / 3;

    path.moveTo(x + size / 2, y + size / 4);
    path.lineTo(x + size / 2 + halfSize, y + size / 2 + halfSize / 2);
    path.lineTo(x + size / 2 - halfSize, y + size / 2 + halfSize / 2);
    path.close();

    canvas.drawPath(path, paint);

    // Small triangles around
    paint.color = primaryColor.withValues(alpha: opacity * 0.6);
    for (int i = 0; i < 3; i++) {
      final angle = 2 * math.pi * i / 3 - math.pi / 2;
      final cx = x + size / 2 + math.cos(angle) * halfSize * 0.8;
      final cy = y + size / 2 + math.sin(angle) * halfSize * 0.8;

      canvas.drawCircle(Offset(cx, cy), 3, paint..style = PaintingStyle.fill);
    }
  }

  void _drawZigZagPattern(Canvas canvas, Paint paint, double x, double y, double size) {
    paint.color = primaryColor.withValues(alpha: opacity);
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 2;

    // Horizontal zigzag
    final path = Path();
    final segmentWidth = size / 5;
    final amplitude = size / 8;

    path.moveTo(x + size * 0.1, y + size / 2);
    for (int i = 0; i < 4; i++) {
      final startX = x + size * 0.1 + i * segmentWidth;
      final peakY = y + size / 2 + (i % 2 == 0 ? -amplitude : amplitude);
      path.lineTo(startX + segmentWidth / 2, peakY);
      path.lineTo(startX + segmentWidth, y + size / 2);
    }
    canvas.drawPath(path, paint);

    // Decorative dots
    paint.style = PaintingStyle.fill;
    paint.color = accentColor.withValues(alpha: opacity * 0.7);
    canvas.drawCircle(Offset(x + size / 2, y + size / 4), 4, paint);
    canvas.drawCircle(Offset(x + size / 2, y + size * 0.75), 4, paint);

    // Small diamonds at corners
    paint.color = secondaryColor.withValues(alpha: opacity * 0.5);
    _drawSmallDiamond(canvas, paint, x + size * 0.15, y + size * 0.15, 8);
    _drawSmallDiamond(canvas, paint, x + size * 0.85, y + size * 0.85, 8);
  }

  void _drawSmallDiamond(Canvas canvas, Paint paint, double cx, double cy, double size) {
    final path = Path();
    path.moveTo(cx, cy - size / 2);
    path.lineTo(cx + size / 2, cy);
    path.lineTo(cx, cy + size / 2);
    path.lineTo(cx - size / 2, cy);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class BoldGeometricPattern extends CustomPainter {
  final Color color;
  final double opacity;

  BoldGeometricPattern({
    required this.color,
    this.opacity = 0.1,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    // Draw large zigzag lines across the canvas
    for (int i = 0; i < 5; i++) {
      final y = size.height * (i + 1) / 6;
      final path = Path();
      path.moveTo(0, y);

      final segments = 8;
      final segmentWidth = size.width / segments;
      final amplitude = 30.0;

      for (int j = 0; j < segments; j++) {
        final x = (j + 1) * segmentWidth;
        final peakY = y + (j % 2 == 0 ? -amplitude : amplitude);
        path.lineTo(x - segmentWidth / 2, peakY);
        path.lineTo(x, y);
      }

      canvas.drawPath(path, paint);
    }

    // Draw large diamonds
    paint.strokeWidth = 2;
    final diamondSize = 60.0;
    for (int i = 0; i < 3; i++) {
      for (int j = 0; j < 2; j++) {
        final cx = size.width * (i + 1) / 4;
        final cy = size.height * (j + 1) / 3;
        _drawDiamond(canvas, paint, cx, cy, diamondSize);
      }
    }
  }

  void _drawDiamond(Canvas canvas, Paint paint, double cx, double cy, double size) {
    final path = Path();
    path.moveTo(cx, cy - size / 2);
    path.lineTo(cx + size / 2, cy);
    path.lineTo(cx, cy + size / 2);
    path.lineTo(cx - size / 2, cy);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class AfricanBorderPattern extends StatelessWidget {
  final Widget child;
  final double borderWidth;
  final Color? borderColor;

  const AfricanBorderPattern({
    super.key,
    required this.child,
    this.borderWidth = 8,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = borderColor ?? AppColors.auGold;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: color, width: borderWidth),
        borderRadius: BorderRadius.circular(20),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20 - borderWidth),
        child: CustomPaint(
          painter: _AfricanBorderPatternPainter(color: color),
          child: child,
        ),
      ),
    );
  }
}

class _AfricanBorderPatternPainter extends CustomPainter {
  final Color color;

  _AfricanBorderPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;

    // Corner triangles
    final cornerSize = 30.0;

    // Top-left
    final topLeftPath = Path()
      ..moveTo(0, 0)
      ..lineTo(cornerSize, 0)
      ..lineTo(0, cornerSize)
      ..close();
    canvas.drawPath(topLeftPath, paint);

    // Top-right
    final topRightPath = Path()
      ..moveTo(size.width, 0)
      ..lineTo(size.width - cornerSize, 0)
      ..lineTo(size.width, cornerSize)
      ..close();
    canvas.drawPath(topRightPath, paint);

    // Bottom-left
    final bottomLeftPath = Path()
      ..moveTo(0, size.height)
      ..lineTo(cornerSize, size.height)
      ..lineTo(0, size.height - cornerSize)
      ..close();
    canvas.drawPath(bottomLeftPath, paint);

    // Bottom-right
    final bottomRightPath = Path()
      ..moveTo(size.width, size.height)
      ..lineTo(size.width - cornerSize, size.height)
      ..lineTo(size.width, size.height - cornerSize)
      ..close();
    canvas.drawPath(bottomRightPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class AfricanPatternBackground extends StatelessWidget {
  final Widget child;
  final Color? patternColor;
  final double opacity;
  final bool boldPattern;

  const AfricanPatternBackground({
    super.key,
    required this.child,
    this.patternColor,
    this.opacity = 0.1,
    this.boldPattern = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: AfricanPatternPainter(
              primaryColor: patternColor ?? AppColors.patternOrange,
              opacity: opacity,
              boldPattern: boldPattern,
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class KaryendaDrumAnimated extends StatefulWidget {
  final double size;
  final bool playing;

  const KaryendaDrumAnimated({
    super.key,
    this.size = 200,
    this.playing = true,
  });

  @override
  State<KaryendaDrumAnimated> createState() => _KaryendaDrumAnimatedState();
}

class _KaryendaDrumAnimatedState extends State<KaryendaDrumAnimated>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();

    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) {
        return SizedBox(
          width: widget.size * 1.2,
          height: widget.size * 1.5,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // Glow behind drum
              Positioned.fill(
                child: Center(
                  child: Container(
                    width: widget.size * 0.8,
                    height: widget.size,
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.auGold.withValues(alpha: 0.3 * _glowController.value),
                          blurRadius: 30 + 20 * _glowController.value,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Drum body
              Center(
                child: CustomPaint(
                  size: Size(widget.size, widget.size * 1.2),
                  painter: _KaryendaDrumPainter(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}


class _KaryendaDrumPainter extends CustomPainter {
  static const Color _red = Color(0xFFCE1126);
  static const Color _green = Color(0xFF1EB53A);
  static const Color _white = Color(0xFFFFFFFF);
  static const Color _darkBrown = Color(0xFF3D2314);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final topY = size.height * 0.22;
    final drumH = size.height * 0.72;
    final topW = size.width * 0.62;
    // Goblet shape: wide top, narrow waist, flared base
    final neckY = topY + drumH * 0.65; // where it narrows
    final neckW = topW * 0.50;
    final baseW = topW * 0.58;
    final baseY = topY + drumH;

    // ── Ground shadow ──
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, baseY + 4),
        width: baseW * 0.7,
        height: 12,
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // ── Goblet drum body path ──
    final drumPath = Path();
    drumPath.moveTo(cx - topW / 2, topY);
    // Right side: top -> straight down to neck -> flare out to base
    drumPath.lineTo(cx + topW / 2, topY);
    drumPath.cubicTo(
      cx + topW / 2 + 2, topY + drumH * 0.35,
      cx + neckW / 2 + 4, topY + drumH * 0.55,
      cx + neckW / 2, neckY,
    );
    // Neck to base flare
    drumPath.cubicTo(
      cx + neckW / 2 - 2, neckY + drumH * 0.08,
      cx + baseW / 2 - 4, baseY - drumH * 0.12,
      cx + baseW / 2, baseY,
    );
    // Bottom edge
    drumPath.lineTo(cx - baseW / 2, baseY);
    // Left side: base -> neck -> top
    drumPath.cubicTo(
      cx - baseW / 2 + 4, baseY - drumH * 0.12,
      cx - neckW / 2 + 2, neckY + drumH * 0.08,
      cx - neckW / 2, neckY,
    );
    drumPath.cubicTo(
      cx - neckW / 2 - 4, topY + drumH * 0.55,
      cx - topW / 2 - 2, topY + drumH * 0.35,
      cx - topW / 2, topY,
    );
    drumPath.close();

    // ── Fill drum body ──
    canvas.save();
    canvas.clipPath(drumPath);

    final bodyRect = Rect.fromLTWH(cx - topW / 2 - 4, topY, topW + 8, drumH);

    // Red base
    canvas.drawRect(bodyRect, Paint()..color = _red);

    // ── White diagonal saltire (X cross) ──
    final flagH = drumH * 0.65; // flag area is upper portion
    final xThickness = topW * 0.16;

    final saltirePaint = Paint()..color = _white;

    // Diagonal TL -> BR
    final s1 = Path();
    s1.moveTo(cx - topW / 2 - 4, topY);
    s1.lineTo(cx - topW / 2 + xThickness - 4, topY);
    s1.lineTo(cx + topW / 2 + 4, topY + flagH);
    s1.lineTo(cx + topW / 2 - xThickness + 4, topY + flagH);
    s1.close();
    canvas.drawPath(s1, saltirePaint);

    // Diagonal TR -> BL
    final s2 = Path();
    s2.moveTo(cx + topW / 2 + 4, topY);
    s2.lineTo(cx + topW / 2 - xThickness + 4, topY);
    s2.lineTo(cx - topW / 2 - 4, topY + flagH);
    s2.lineTo(cx - topW / 2 + xThickness - 4, topY + flagH);
    s2.close();
    canvas.drawPath(s2, saltirePaint);

    // ── Green triangles (left & right) ──
    final greenPaint = Paint()..color = _green;

    final leftTri = Path();
    leftTri.moveTo(cx - topW / 2 - 4, topY);
    leftTri.lineTo(cx - topW / 2 - 4, topY + flagH);
    leftTri.lineTo(cx - xThickness * 0.2, topY + flagH / 2);
    leftTri.close();
    canvas.drawPath(leftTri, greenPaint);

    final rightTri = Path();
    rightTri.moveTo(cx + topW / 2 + 4, topY);
    rightTri.lineTo(cx + topW / 2 + 4, topY + flagH);
    rightTri.lineTo(cx + xThickness * 0.2, topY + flagH / 2);
    rightTri.close();
    canvas.drawPath(rightTri, greenPaint);

    // ── White circle with three red six-pointed stars (Burundi flag) ──
    final starCenterY = topY + flagH / 2;
    final circleRadius = flagH * 0.22;

    // White circle background
    canvas.drawCircle(
      Offset(cx, starCenterY),
      circleRadius,
      Paint()..color = _white,
    );
    // Circle outline
    canvas.drawCircle(
      Offset(cx, starCenterY),
      circleRadius,
      Paint()
        ..color = _green.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    final starSize = flagH * 0.08;
    _drawSixPointStar(canvas, cx, starCenterY - flagH * 0.12, starSize, _red);
    _drawSixPointStar(canvas, cx - flagH * 0.10, starCenterY + flagH * 0.06, starSize, _red);
    _drawSixPointStar(canvas, cx + flagH * 0.10, starCenterY + flagH * 0.06, starSize, _red);

    // ── Black band with "BURUNDI...GISHORA" text ──
    final bandY = neckY - drumH * 0.06;
    final bandH = drumH * 0.09;
    canvas.drawRect(
      Rect.fromLTWH(cx - topW, bandY, topW * 2, bandH),
      Paint()..color = Colors.black,
    );

    final textPainter = TextPainter(
      text: TextSpan(
        text: 'BURUNDI',
        style: TextStyle(
          color: _white,
          fontSize: bandH * 0.55,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(cx - textPainter.width / 2, bandY + bandH * 0.2),
    );

    // ── Bottom stripes (red/white/green bands at base) ──
    final stripeStart = neckY + drumH * 0.06;
    final stripeH = (baseY - stripeStart) / 5;
    final stripeColors = [_white, _red, _white, _green, _red];
    for (int i = 0; i < stripeColors.length; i++) {
      canvas.drawRect(
        Rect.fromLTWH(cx - baseW, stripeStart + stripeH * i, baseW * 2, stripeH + 1),
        Paint()..color = stripeColors[i],
      );
    }
    // Green at very bottom
    canvas.drawRect(
      Rect.fromLTWH(cx - baseW, baseY - stripeH, baseW * 2, stripeH),
      Paint()..color = _green,
    );

    // ── 3D shading on drum body ──
    final highlightPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.black.withValues(alpha: 0.15),
          Colors.transparent,
          Colors.transparent,
          Colors.black.withValues(alpha: 0.18),
        ],
        stops: const [0.0, 0.2, 0.8, 1.0],
      ).createShader(bodyRect);
    canvas.drawRect(bodyRect, highlightPaint);

    canvas.restore();

    // ── Drum outline ──
    canvas.drawPath(
      drumPath,
      Paint()
        ..color = _darkBrown
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // ── Braided leather lacing (thick fur/hide at top) ──
    final lacingH = drumH * 0.12;
    final lacingY = topY - lacingH * 0.6;
    final lacingRect = Rect.fromLTWH(cx - topW / 2 - 2, lacingY, topW + 4, lacingH);

    // Brown fur/hide base
    canvas.drawRRect(
      RRect.fromRectAndRadius(lacingRect, const Radius.circular(4)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFB8860B),
            const Color(0xFF8B6914),
            const Color(0xFFA0522D),
            const Color(0xFF8B4513),
          ],
          stops: const [0.0, 0.3, 0.6, 1.0],
        ).createShader(lacingRect),
    );

    // Braided texture lines
    final braidPaint = Paint()
      ..color = const Color(0xFF6B3A1F).withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final braidCount = 16;
    for (int i = 0; i < braidCount; i++) {
      final x = cx - topW / 2 + (topW / braidCount) * i;
      // Criss-cross braiding
      final path = Path();
      path.moveTo(x, lacingY + 2);
      path.quadraticBezierTo(
        x + topW / braidCount / 2,
        lacingY + lacingH * 0.5,
        x + topW / braidCount,
        lacingY + lacingH - 2,
      );
      canvas.drawPath(path, braidPaint);
    }

    // Fuzzy top edge (fur texture)
    final furPaint = Paint()
      ..color = const Color(0xFFB8860B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (double x = cx - topW / 2; x < cx + topW / 2; x += 4) {
      final furH = 3 + (x.hashCode % 5).toDouble();
      canvas.drawLine(
        Offset(x, lacingY),
        Offset(x + 1, lacingY - furH),
        furPaint,
      );
    }

    // Lacing outline
    canvas.drawRRect(
      RRect.fromRectAndRadius(lacingRect, const Radius.circular(4)),
      Paint()
        ..color = _darkBrown.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // ── 3 small decorative circles inside the brown lacing ──
    final lacingCenterY = lacingY + lacingH / 2;
    final circleR = 4.0;
    final circleStrokePaint = Paint()
      ..color = AppColors.auGold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    // Left circle - inside the lacing, left third
    canvas.drawCircle(Offset(cx - topW * 0.28, lacingCenterY), circleR, circleStrokePaint);
    // Center circle - inside the lacing, center
    canvas.drawCircle(Offset(cx, lacingCenterY), circleR, circleStrokePaint);
    // Right circle - inside the lacing, right third
    canvas.drawCircle(Offset(cx + topW * 0.28, lacingCenterY), circleR, circleStrokePaint);

    // ── Bottom edge detail ──
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, baseY),
        width: baseW,
        height: 8,
      ),
      Paint()..color = _darkBrown,
    );
  }

  void _drawSixPointStar(Canvas canvas, double cx, double cy, double r, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final t1 = Path();
    for (int i = 0; i < 3; i++) {
      final angle = (i * 120 - 90) * math.pi / 180;
      final x = cx + r * math.cos(angle);
      final y = cy + r * math.sin(angle);
      if (i == 0) { t1.moveTo(x, y); } else { t1.lineTo(x, y); }
    }
    t1.close();
    canvas.drawPath(t1, paint);

    final t2 = Path();
    for (int i = 0; i < 3; i++) {
      final angle = (i * 120 + 90) * math.pi / 180;
      final x = cx + r * math.cos(angle);
      final y = cy + r * math.sin(angle);
      if (i == 0) { t2.moveTo(x, y); } else { t2.lineTo(x, y); }
    }
    t2.close();
    canvas.drawPath(t2, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
