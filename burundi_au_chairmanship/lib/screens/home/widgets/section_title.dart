import 'package:flutter/material.dart';
import '../../../config/app_ds.dart';

/// Section heading: 16px/w700 title with an optional green "See all".
class SectionTitle extends StatelessWidget {
  final String title;
  final bool showSeeAll;
  final VoidCallback? onSeeAll;

  const SectionTitle({
    super.key,
    required this.title,
    this.showSeeAll = false,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(child: Text(title, style: Ds.sectionTitle(context))),
        if (showSeeAll)
          GestureDetector(
            onTap: onSeeAll,
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.only(left: 12),
              child: Text(
                'See all',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: Ds.green),
              ),
            ),
          ),
      ],
    );
  }
}
