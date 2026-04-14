import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';

/// Grid of quick access buttons for common actions
///
/// Displays a responsive grid of action buttons with icons,
/// supporting live indicators
class QuickAccessGrid extends StatelessWidget {
  /// List of items to display in the grid
  ///
  /// Each item should contain:
  /// - `title`: String - Display text
  /// - `icon`: IconData - Icon to show
  /// - `onTap`: VoidCallback - Action when tapped
  /// - `hasLiveDot`: bool (optional) - Show live indicator dot
  final List<Map<String, dynamic>> items;

  const QuickAccessGrid({super.key, required this.items});

  static Color _hexToColor(String hex, Color fallback) {
    if (hex.isEmpty) return fallback;
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    try {
      return Color(int.parse(hex, radix: 16));
    } catch (_) {
      return fallback;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final itemWidth = (screenWidth - 32 - 36) / 4;

    return Wrap(
      spacing: 12,
      runSpacing: 16,
      children: items.map((item) {
        final hasLiveDot = item['hasLiveDot'] == true;
        final badgeText = item['badgeText'] as String? ?? '';
        final badgeColorHex = item['badgeColor'] as String? ?? '';

        final isLocked = item['locked'] == true;
        final itemColor = isLocked ? Colors.grey : AppColors.burundiGreen;

        return GestureDetector(
          onTap: item['onTap'] as VoidCallback,
          child: Opacity(
            opacity: isLocked ? 0.55 : 1.0,
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
                        color: itemColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: itemColor.withValues(alpha: 0.2),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        item['icon'] as IconData,
                        color: itemColor,
                        size: 26,
                      ),
                    ),
                    // "NEW" / "HOT" / custom text badge
                    if (badgeText.isNotEmpty)
                      Positioned(
                        top: -8,
                        right: -12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: _hexToColor(badgeColorHex, AppColors.burundiRed),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: Theme.of(context).scaffoldBackgroundColor,
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            badgeText.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              height: 1,
                            ),
                          ),
                        ),
                      )
                    // Fallback to red live dot
                    else if (hasLiveDot)
                      Positioned(
                        top: -2,
                        right: -2,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: AppColors.burundiRed,
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
          ),
        );
      }).toList(),
    );
  }
}
