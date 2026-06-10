import 'package:flutter/material.dart';

/// Verified badge widget that displays Gold or Blue badges
class VerifiedBadge extends StatelessWidget {
  final String? badgeType; // 'GOLD' or 'BLUE' or null
  final double size;

  const VerifiedBadge({
    super.key,
    this.badgeType,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) {
    if (badgeType == null) return const SizedBox.shrink();

    Color badgeColor;

    if (badgeType == 'GOLD') {
      badgeColor = const Color(0xFFFFD700); // Gold
    } else {
      badgeColor = const Color(0xFF409843); // Green (default)
    }

    return Icon(
      Icons.verified,
      color: badgeColor,
      size: size,
    );
  }
}

/// Legacy verified badge (simple blue checkmark) - kept for backward compatibility
class SimpleVerifiedBadge extends StatelessWidget {
  final double size;

  const SimpleVerifiedBadge({
    super.key,
    this.size = 18,
  });

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.verified,
      color: const Color(0xFF409843), // Green
      size: size,
    );
  }
}
