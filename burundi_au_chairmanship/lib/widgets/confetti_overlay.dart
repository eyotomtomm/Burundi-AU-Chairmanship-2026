import 'dart:math';
import 'package:flutter/material.dart';

/// A self-contained confetti animation widget using CustomPainter.
///
/// Renders 80-100 falling particles in Burundi/AU colors
/// (gold, green, red, blue, white) with gravity, horizontal drift,
/// rotation, and fade-out over ~3 seconds.
///
/// Trigger programmatically via [ConfettiOverlay.show].
class ConfettiOverlay extends StatefulWidget {
  const ConfettiOverlay({super.key});

  /// Shows a confetti overlay on top of the current screen for ~3 seconds.
  static void show(BuildContext context) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _ConfettiAnimation(
        onComplete: () {
          entry.remove();
        },
      ),
    );
    overlay.insert(entry);
  }

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay> {
  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

// ---------------------------------------------------------------------------
// Internal animation widget that drives the confetti lifecycle
// ---------------------------------------------------------------------------

class _ConfettiAnimation extends StatefulWidget {
  final VoidCallback onComplete;

  const _ConfettiAnimation({required this.onComplete});

  @override
  State<_ConfettiAnimation> createState() => _ConfettiAnimationState();
}

class _ConfettiAnimationState extends State<_ConfettiAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Particle> _particles;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );

    // Generate between 80 and 100 particles
    final count = 80 + _random.nextInt(21); // 80..100
    _particles = List.generate(count, (_) => _Particle(_random));

    _controller.forward();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            size: MediaQuery.of(context).size,
            painter: _ConfettiPainter(
              particles: _particles,
              progress: _controller.value,
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Particle shape variants
// ---------------------------------------------------------------------------

enum _ParticleShape { rectangle, circle, square }

// ---------------------------------------------------------------------------
// Individual particle data (immutable after creation)
// ---------------------------------------------------------------------------

class _Particle {
  /// Horizontal start position (0..1 of screen width).
  final double x;

  /// Vertical start offset; negative so particles begin above the viewport.
  final double startY;

  /// Base vertical speed multiplier (gravity-like).
  final double speed;

  /// Primary dimension of the confetti piece in logical pixels.
  final double size;

  /// Color drawn from Burundi / AU palette.
  final Color color;

  /// Initial rotation angle in radians.
  final double initialRotation;

  /// Rotation speed multiplier (radians per full animation cycle).
  final double rotationSpeed;

  /// Amplitude of horizontal sine-wave drift (fraction of screen width).
  final double driftAmplitude;

  /// Frequency multiplier for horizontal drift oscillation.
  final double driftFrequency;

  /// Shape of the particle.
  final _ParticleShape shape;

  /// Aspect ratio for rectangles (height = size * aspect).
  final double aspect;

  _Particle(Random r)
      : x = r.nextDouble(),
        startY = -r.nextDouble() * 0.4 - 0.05,
        speed = 0.4 + r.nextDouble() * 0.7,
        size = 4.0 + r.nextDouble() * 7.0,
        color = _pickColor(r),
        initialRotation = r.nextDouble() * pi * 2,
        rotationSpeed = (1.0 + r.nextDouble() * 3.0) * (r.nextBool() ? 1 : -1),
        driftAmplitude = 0.02 + r.nextDouble() * 0.06,
        driftFrequency = 2.0 + r.nextDouble() * 4.0,
        shape = _pickShape(r),
        aspect = 0.4 + r.nextDouble() * 0.4;

  // Burundi flag: green, red, white
  // AU: gold, green
  // Plus blue for accent
  static const _colors = [
    Color(0xFF409843), // Burundi Green
    Color(0xFFE11C23), // Burundi Red
    Color(0xFFFFFFFF), // White
    Color(0xFFD4AF37), // AU Gold
    Color(0xFFD4AF37), // AU Gold (double-weighted for prominence)
    Color(0xFF409843), // Green (double-weighted)
    Color(0xFFE11C23), // Red accent
  ];

  static Color _pickColor(Random r) => _colors[r.nextInt(_colors.length)];

  static _ParticleShape _pickShape(Random r) {
    // 50% rectangles, 30% circles, 20% squares
    final v = r.nextDouble();
    if (v < 0.5) return _ParticleShape.rectangle;
    if (v < 0.8) return _ParticleShape.circle;
    return _ParticleShape.square;
  }
}

// ---------------------------------------------------------------------------
// CustomPainter that renders all particles for a given animation progress
// ---------------------------------------------------------------------------

class _ConfettiPainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;

  _ConfettiPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      // Gravity: accelerate downward (quadratic easing on vertical position).
      // position = startY + speed * (progress + 0.5 * progress^2) * screenHeight
      final gravityFactor = progress + 0.5 * progress * progress;
      final y = (p.startY + gravityFactor * p.speed * 1.3) * size.height;

      // Horizontal drift via sine wave
      final drift = sin(progress * pi * 2 * p.driftFrequency + p.initialRotation) *
          p.driftAmplitude;
      final x = (p.x + drift) * size.width;

      // Skip particles that have fallen off-screen or are still far above
      if (y > size.height + 20 || y < -40) continue;

      // Opacity: full until 65% progress, then fade to 0 by 100%
      final double opacity;
      if (progress < 0.65) {
        opacity = 1.0;
      } else {
        opacity = ((1.0 - progress) / 0.35).clamp(0.0, 1.0);
      }

      final paint = Paint()
        ..color = p.color.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;

      // Current rotation angle
      final angle = p.initialRotation + progress * pi * 2 * p.rotationSpeed;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle);

      switch (p.shape) {
        case _ParticleShape.rectangle:
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: Offset.zero,
                width: p.size,
                height: p.size * p.aspect,
              ),
              const Radius.circular(1.0),
            ),
            paint,
          );
          break;
        case _ParticleShape.circle:
          canvas.drawCircle(Offset.zero, p.size * 0.4, paint);
          break;
        case _ParticleShape.square:
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: Offset.zero,
                width: p.size * 0.7,
                height: p.size * 0.7,
              ),
              const Radius.circular(1.5),
            ),
            paint,
          );
          break;
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
