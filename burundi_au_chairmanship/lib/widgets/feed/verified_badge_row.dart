import 'package:flutter/material.dart';

import '../../config/app_ds.dart';
import '../verified_badge.dart';

/// An author's name with their verification badge — the one-line identity used
/// wherever a post is shown in miniature.
class VerifiedBadgeRow extends StatelessWidget {
  final String name;
  final String? badge;
  final double fontSize;

  const VerifiedBadgeRow({
    super.key,
    required this.name,
    this.badge,
    this.fontSize = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          child: Text(
            name,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                color: Ds.ink(context)),
          ),
        ),
        if (badge != null) ...[
          const SizedBox(width: 4),
          VerifiedBadge(badgeType: badge, size: fontSize),
        ],
      ],
    );
  }
}
