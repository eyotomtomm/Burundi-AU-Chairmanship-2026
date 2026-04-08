import 'dart:math';
import 'package:flutter/material.dart';
import '../config/app_colors.dart';

/// A lightweight confetti overlay widget using CustomPainter.
///
/// Renders falling particles in green, red, and gold colors.
/// Trigger programmatically via [ConfettiOverlay.show].
class ConfettiOverlay extends StatefulWidget {
  const ConfettiOverlay({super.key});

  /// Shows a confetti overlay on top of the current screen for 3 seconds.
  static void show(BuildContext context) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _ConfettiAnimation(
        onComplete: () => entry.remove(),
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
      duration: const Duration(seconds: 3),
    );

    // Generate particles
    _particles = List.generate(80, (_) => _Particle(_random));

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

class _Particle {
  final double x; // 0..1 horizontal position
  final double startY; // negative start offset
  final double speed; // fall speed multiplier
  final double size;
  final Color color;
  final double rotation;
  final double wobble; // horizontal wobble amplitude

  _Particle(Random random)
      : x = random.nextDouble(),
        startY = -random.nextDouble() * 0.3,
        speed = 0.5 + random.nextDouble() * 0.8,
        size = 4 + random.nextDouble() * 6,
        color = _randomColor(random),
        rotation = random.nextDouble() * pi * 2,
        wobble = (random.nextDouble() - 0.5) * 0.1;

  static Color _randomColor(Random random) {
    const colors = [
      AppColors.burundiGreen,
      AppColors.burundiRed,
      AppColors.auGold,
      AppColors.burundiGreen,
      AppColors.auGold,
    ];
    return colors[random.nextInt(colors.length)];
  }
}

class _ConfettiPainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;

  _ConfettiPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      // Calculate position
      final y = (p.startY + progress * p.speed * 1.5) * size.height;
      final x = (p.x + sin(progress * pi * 4 + p.rotation) * p.wobble) * size.width;

      if (y > size.height || y < -20) continue;

      // Fade out near the end
      final opacity = progress < 0.7 ? 1.0 : (1.0 - (progress - 0.7) / 0.3);

      final paint = Paint()
        ..color = p.color.withValues(alpha: opacity.clamp(0.0, 1.0))
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.rotation + progress * pi * 2);

      // Draw a small rectangle (confetti piece)
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6),
          const Radius.circular(1),
        ),
        paint,
      );

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) => oldDelegate.progress != progress;
}
