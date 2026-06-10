import 'package:flutter/material.dart';

/// Verified badge widget — supports GOLD, BLUE, GREEN, or NONE.
class VerifiedBadge extends StatelessWidget {
  final String? badgeType; // 'GOLD', 'BLUE', 'GREEN', 'NONE', or null
  final double size;

  const VerifiedBadge({
    super.key,
    this.badgeType,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) {
    if (badgeType == null || badgeType == 'NONE') return const SizedBox.shrink();

    final Color badgeColor;
    switch (badgeType) {
      case 'GOLD':
        badgeColor = const Color(0xFFFFD700); // Gold
        break;
      case 'BLUE':
        badgeColor = const Color(0xFF1DA1F2); // Blue
        break;
      case 'GREEN':
      default:
        badgeColor = const Color(0xFF409843); // Green
        break;
    }

    return Icon(
      Icons.verified,
      color: badgeColor,
      size: size,
    );
  }
}

/// Legacy verified badge (simple green checkmark) - kept for backward compatibility
class SimpleVerifiedBadge extends StatelessWidget {
  final double size;

  const SimpleVerifiedBadge({
    super.key,
    this.size = 18,
  });

  @override
  Widget build(BuildContext context) {
    return const Icon(
      Icons.verified,
      color: Color(0xFF409843),
      size: 18,
    );
  }
}
