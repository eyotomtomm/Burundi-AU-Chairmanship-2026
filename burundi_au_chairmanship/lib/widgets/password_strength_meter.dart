import 'package:flutter/material.dart';
import '../config/app_colors.dart';

/// A reusable password strength meter widget.
///
/// Shows a color-coded bar and text label indicating password strength
/// based on length, uppercase, lowercase, digit, and special character checks.
class PasswordStrengthMeter extends StatelessWidget {
  final String password;

  const PasswordStrengthMeter({super.key, required this.password});

  /// Compute strength score from 0..5 based on criteria met.
  static int _computeScore(String password) {
    int score = 0;
    if (password.length >= 8) score++;
    if (password.contains(RegExp(r'[A-Z]'))) score++;
    if (password.contains(RegExp(r'[a-z]'))) score++;
    if (password.contains(RegExp(r'[0-9]'))) score++;
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\\/~`]'))) score++;
    return score;
  }

  /// Returns (label, color) for a given score.
  static ({String label, Color color}) _strengthInfo(int score) {
    if (score <= 1) return (label: 'Weak', color: AppColors.burundiRed);
    if (score == 2) return (label: 'Fair', color: Colors.orange);
    if (score == 3) return (label: 'Good', color: Colors.amber);
    return (label: 'Strong', color: AppColors.burundiGreen);
  }

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();

    final score = _computeScore(password);
    final info = _strengthInfo(score);
    final fraction = score / 5.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        // Animated strength bar
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 6,
            child: Stack(
              children: [
                // Background track
                Container(
                  width: double.infinity,
                  color: Colors.grey.withValues(alpha: 0.2),
                ),
                // Animated fill
                AnimatedFractionallySizedBox(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  widthFactor: fraction,
                  child: Container(
                    decoration: BoxDecoration(
                      color: info.color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        // Label
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            info.label,
            key: ValueKey(info.label),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: info.color,
            ),
          ),
        ),
      ],
    );
  }
}

/// An animated FractionallySizedBox that animates its width factor.
class AnimatedFractionallySizedBox extends ImplicitlyAnimatedWidget {
  final double widthFactor;
  final Widget child;

  const AnimatedFractionallySizedBox({
    super.key,
    required this.widthFactor,
    required this.child,
    required super.duration,
    super.curve,
  });

  @override
  AnimatedWidgetBaseState<AnimatedFractionallySizedBox> createState() =>
      _AnimatedFractionallySizedBoxState();
}

class _AnimatedFractionallySizedBoxState
    extends AnimatedWidgetBaseState<AnimatedFractionallySizedBox> {
  Tween<double>? _widthFactor;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _widthFactor = visitor(
      _widthFactor,
      widget.widthFactor,
      (dynamic value) => Tween<double>(begin: value as double),
    ) as Tween<double>?;
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: _widthFactor?.evaluate(animation) ?? widget.widthFactor,
      child: widget.child,
    );
  }
}
