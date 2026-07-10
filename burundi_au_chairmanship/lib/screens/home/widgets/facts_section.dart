import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../models/fact_model.dart';
import '../../facts/fact_detail_screen.dart';

// Burundi flag: Green #409843, Red #E11C23, White #FFFFFF
// AU: Gold #FCD116
const _green = Color(0xFF409843);
const _red = Color(0xFFE11C23);
const _gold = Color(0xFFFCD116);

/// Ankara wax-print inspired pattern with 5 variants using only logo colors.
class _AfricanPatternPainter extends CustomPainter {
  final int variant;
  final Color accent;

  _AfricanPatternPainter({required this.variant, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    switch (variant % 5) {
      case 0:
        _paintAdinkra(canvas, size);
        break;
      case 1:
        _paintSunburst(canvas, size);
        break;
      case 2:
        _paintShields(canvas, size);
        break;
      case 3:
        _paintWaves(canvas, size);
        break;
      case 4:
        _paintAnkara(canvas, size);
        break;
    }
  }

  /// Adinkra — concentric targets, crosses, diamonds
  void _paintAdinkra(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = accent.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final fill = Paint()
      ..color = accent.withValues(alpha: 0.10)
      ..style = PaintingStyle.fill;

    const cell = 34.0;
    for (double y = cell / 2; y < size.height + cell; y += cell) {
      for (double x = cell / 2; x < size.width + cell; x += cell) {
        final t = ((x / cell).floor() + (y / cell).floor()) % 3;
        if (t == 0) {
          canvas.drawCircle(Offset(x, y), 11, stroke);
          canvas.drawCircle(Offset(x, y), 6, stroke);
          canvas.drawCircle(Offset(x, y), 2.5, fill);
        } else if (t == 1) {
          canvas.drawLine(Offset(x - 8, y), Offset(x + 8, y), stroke);
          canvas.drawLine(Offset(x, y - 8), Offset(x, y + 8), stroke);
          canvas.drawCircle(Offset(x, y), 2, fill);
        } else {
          final path = Path()
            ..moveTo(x, y - 9)
            ..lineTo(x + 9, y)
            ..lineTo(x, y + 9)
            ..lineTo(x - 9, y)
            ..close();
          canvas.drawPath(path, stroke);
          canvas.drawCircle(Offset(x, y), 2.5, fill);
        }
      }
    }
  }

  /// Sunburst — radiating circles and rays
  void _paintSunburst(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = accent.withValues(alpha: 0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    final dot = Paint()
      ..color = accent.withValues(alpha: 0.10)
      ..style = PaintingStyle.fill;

    // Large burst top-right
    for (double r = 14; r < 85; r += 11) {
      canvas.drawCircle(Offset(size.width - 18, 28), r, stroke);
    }
    // Rays
    final cx = size.width - 18;
    const cy = 28.0;
    for (int i = 0; i < 12; i++) {
      final a = (i * math.pi * 2) / 12;
      canvas.drawLine(
        Offset(cx + 18 * math.cos(a), cy + 18 * math.sin(a)),
        Offset(cx + 80 * math.cos(a), cy + 80 * math.sin(a)),
        stroke,
      );
    }
    // Small burst bottom-left
    for (double r = 10; r < 55; r += 10) {
      canvas.drawCircle(Offset(28, size.height - 22), r, stroke);
    }
    // Scattered beads
    final rng = math.Random(42);
    for (int i = 0; i < 18; i++) {
      canvas.drawCircle(
        Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height),
        2 + rng.nextDouble() * 3,
        dot,
      );
    }
  }

  /// Shields — Maasai shield shapes with chevron bands
  void _paintShields(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = accent.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final fill = Paint()
      ..color = accent.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;

    void shield(double cx, double cy, double w, double h) {
      final path = Path()
        ..moveTo(cx, cy - h / 2)
        ..cubicTo(cx + w / 2, cy - h / 3, cx + w / 2, cy + h / 3, cx, cy + h / 2)
        ..cubicTo(cx - w / 2, cy + h / 3, cx - w / 2, cy - h / 3, cx, cy - h / 2)
        ..close();
      canvas.drawPath(path, stroke);
      // Stripes
      final sp = Paint()
        ..color = accent.withValues(alpha: 0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7;
      for (double sy = cy - h / 3; sy < cy + h / 3; sy += 7) {
        canvas.drawLine(Offset(cx - w / 3, sy), Offset(cx + w / 3, sy), sp);
      }
      canvas.drawCircle(Offset(cx, cy), 3, fill);
    }

    shield(size.width * 0.78, size.height * 0.35, 52, 76);
    shield(size.width * 0.15, size.height * 0.7, 38, 56);

    // Chevrons top and bottom
    final chev = Paint()
      ..color = accent.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    for (int row = 0; row < 2; row++) {
      final y = size.height * 0.12 + row * 13;
      final p = Path()..moveTo(0, y);
      for (double x = 0; x < size.width + 16; x += 16) {
        p.lineTo(x + 8, y - 7);
        p.lineTo(x + 16, y);
      }
      canvas.drawPath(p, chev);
    }
    for (int row = 0; row < 2; row++) {
      final y = size.height - 14 - row * 12;
      final p = Path()..moveTo(0, y);
      for (double x = 0; x < size.width + 14; x += 14) {
        p.lineTo(x + 7, y - 6);
        p.lineTo(x + 14, y);
      }
      canvas.drawPath(p, chev);
    }
  }

  /// Waves — flowing arcs with dot clusters
  void _paintWaves(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = accent.withValues(alpha: 0.13)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    final dot = Paint()
      ..color = accent.withValues(alpha: 0.09)
      ..style = PaintingStyle.fill;

    for (int row = 0; row < 6; row++) {
      final y = row * 36.0;
      final p = Path()..moveTo(0, y + 18);
      for (double x = 0; x < size.width + 40; x += 40) {
        final flip = (((x / 40).floor() + row) % 2 == 0);
        p.arcToPoint(
          Offset(x + 40, y + 18),
          radius: const Radius.circular(20),
          clockwise: flip,
        );
      }
      canvas.drawPath(p, stroke);
    }
    for (final o in [const Offset(28, 38), const Offset(33, 46), const Offset(23, 46)]) {
      canvas.drawCircle(o, 3, dot);
    }
  }

  /// Ankara — overlapping circles with flower petals
  void _paintAnkara(Canvas canvas, Size size) {
    final ring = Paint()
      ..color = accent.withValues(alpha: 0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final petal = Paint()
      ..color = accent.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;

    final circles = [
      [size.width * 0.25, size.height * 0.4, 48.0],
      [size.width * 0.55, size.height * 0.35, 42.0],
      [size.width * 0.8, size.height * 0.6, 38.0],
    ];
    for (final c in circles) {
      canvas.drawCircle(Offset(c[0], c[1]), c[2], ring);
      ring.strokeWidth = 0.8;
      canvas.drawCircle(Offset(c[0], c[1]), c[2] - 14, ring);
      ring.strokeWidth = 1.4;
    }
    // Petals around first circle
    final cx = circles[0][0], cy = circles[0][1];
    for (int i = 0; i < 8; i++) {
      final a = (i * math.pi * 2) / 8;
      canvas.drawCircle(Offset(cx + 48 * math.cos(a), cy + 48 * math.sin(a)), 9, petal);
    }
    // Hatching corner
    final hatch = Paint()
      ..color = accent.withValues(alpha: 0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;
    for (double d = 0; d < 75; d += 8) {
      canvas.drawLine(Offset(0, size.height - d), Offset(d, size.height), hatch);
    }
  }

  @override
  bool shouldRepaint(covariant _AfricanPatternPainter old) =>
      old.variant != variant || old.accent != accent;
}

// 5 gradient palettes — deep/muted shades so white text stays readable
const _palettes = [
  // Deep green + dark gold
  [Color(0xFF0E2E11), Color(0xFF1A4A1E), Color(0xFF8A7010)],
  // Dark maroon + muted gold
  [Color(0xFF3D0A0E), Color(0xFF5E1218), Color(0xFF8A7010)],
  // Forest green + dark sage
  [Color(0xFF0C2410), Color(0xFF1C3E20), Color(0xFF2E5432)],
  // Deep red-brown + dark amber
  [Color(0xFF2E0808), Color(0xFF4A1010), Color(0xFF6B4A12)],
  // Dark green + dark red
  [Color(0xFF0A1F0D), Color(0xFF163A1A), Color(0xFF5A1515)],
];

// Pattern accent color per palette (gold or white for contrast)
const _accentColors = [_gold, _gold, Colors.white, Colors.white, _gold];

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
    final palette = _palettes[index % _palettes.length];
    final accent = _accentColors[index % _accentColors.length];

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        CupertinoPageRoute(
            builder: (_) => FactDetailScreen(factId: fact.id, fact: fact)),
      ),
      child: Container(
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: palette[0].withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // Gradient background
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: palette,
                      stops: const [0.0, 0.55, 1.0],
                    ),
                  ),
                ),
              ),

              // African pattern overlay
              Positioned.fill(
                child: CustomPaint(
                  painter: _AfricanPatternPainter(
                    variant: index,
                    accent: accent,
                  ),
                ),
              ),

              // Top accent strip
              Positioned(
                top: 0, left: 0, right: 0,
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      palette[2].withValues(alpha: 0.0),
                      palette[2].withValues(alpha: 0.7),
                      palette[2].withValues(alpha: 0.0),
                    ]),
                  ),
                ),
              ),

              // Content
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.28),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _gold.withValues(alpha: 0.4), width: 0.8),
                          ),
                          child: Text(
                            fact.category?.getDisplayName(langCode) ?? '',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: _gold,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            color: _gold.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                            border: Border.all(color: _gold.withValues(alpha: 0.3)),
                          ),
                          child: Icon(
                            isQuote ? Icons.format_quote_rounded : Icons.auto_awesome,
                            size: 16, color: _gold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Body
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isQuote) ...[
                            Text(
                              '\u201C',
                              style: TextStyle(
                                fontSize: 32, height: 0.7, fontWeight: FontWeight.w900,
                                color: _gold.withValues(alpha: 0.7),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Expanded(
                              child: Text(
                                fact.getContentPreview(langCode),
                                style: const TextStyle(
                                  fontSize: 13.5, fontStyle: FontStyle.italic,
                                  color: Colors.white, height: 1.45,
                                ),
                                maxLines: 3, overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (fact.authorName.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Row(children: [
                                  Container(width: 20, height: 2,
                                    decoration: BoxDecoration(color: _gold, borderRadius: BorderRadius.circular(1))),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(
                                    fact.authorName,
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _gold, letterSpacing: 0.3),
                                    maxLines: 1, overflow: TextOverflow.ellipsis,
                                  )),
                                ]),
                              ),
                          ] else ...[
                            Text(
                              fact.getTitle(langCode),
                              style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w800,
                                color: Colors.white, height: 1.2, letterSpacing: -0.2,
                              ),
                              maxLines: 2, overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Expanded(child: Text(
                              fact.getContentPreview(langCode),
                              style: TextStyle(fontSize: 12.5, color: Colors.white.withValues(alpha: 0.85), height: 1.4),
                              maxLines: 3, overflow: TextOverflow.ellipsis,
                            )),
                            if (fact.source.isNotEmpty)
                              Text(
                                fact.getSource(langCode),
                                style: TextStyle(fontSize: 10, color: _gold.withValues(alpha: 0.8), fontWeight: FontWeight.w600),
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Bottom accent
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      _gold.withValues(alpha: 0.0),
                      _gold.withValues(alpha: 0.6),
                      _gold.withValues(alpha: 0.0),
                    ]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
