import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';

/// Grid of quick access buttons for common actions
///
/// Displays a responsive grid of action buttons with icons,
/// supporting special styling for emergency (SOS) items and live indicators
class QuickAccessGrid extends StatelessWidget {
  /// List of items to display in the grid
  ///
  /// Each item should contain:
  /// - `title`: String - Display text
  /// - `icon`: IconData - Icon to show
  /// - `onTap`: VoidCallback - Action when tapped
  /// - `isSos`: bool (optional) - Style as emergency button
  /// - `hasLiveDot`: bool (optional) - Show live indicator dot
  final List<Map<String, dynamic>> items;

  const QuickAccessGrid({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final itemWidth = (screenWidth - 32 - 36) / 4;

    return Wrap(
      spacing: 12,
      runSpacing: 16,
      children: items.map((item) {
        final isSos = item['isSos'] == true;
        final hasLiveDot = item['hasLiveDot'] == true;

        return GestureDetector(
          onTap: item['onTap'] as VoidCallback,
          child: SizedBox(
            width: itemWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: isSos
                            ? AppColors.emergency.withValues(alpha: 0.1)
                            : AppColors.burundiGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSos
                              ? AppColors.emergency.withValues(alpha: 0.25)
                              : AppColors.burundiGreen.withValues(alpha: 0.2),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        item['icon'] as IconData,
                        color: isSos ? AppColors.emergency : AppColors.burundiGreen,
                        size: 26,
                      ),
                    ),
                    if (hasLiveDot)
                      Positioned(
                        top: -2,
                        right: -2,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: AppColors.emergency,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).scaffoldBackgroundColor,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  item['title'] as String,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
