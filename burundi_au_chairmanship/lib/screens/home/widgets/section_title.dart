import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';

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
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.burundiGreen, AppColors.auGold],
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        if (showSeeAll)
          TextButton(
            onPressed: onSeeAll,
            child: const Row(
              children: [
                Text(
                  'See All',
                  style: TextStyle(color: AppColors.burundiGreen),
                ),
                Icon(Icons.chevron_right, color: AppColors.burundiGreen, size: 18),
              ],
            ),
          ),
      ],
    );
  }
}
