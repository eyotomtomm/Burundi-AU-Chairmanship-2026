import 'package:flutter/material.dart';
import '../../../widgets/app_network_image.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_ds.dart';

/// Grid of quick access buttons for common actions
///
/// Displays a responsive grid of action buttons with icons,
/// supporting live indicators
class QuickAccessGrid extends StatelessWidget {
  /// List of items to display in the grid
  ///
  /// Each item should contain:
  /// - `title`: String - Display text
  /// - `icon`: IconData - Icon to show (fallback when iconImageUrl is absent)
  /// - `iconImageUrl`: String (optional) - Network image URL for the icon
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
    final itemWidth = (screenWidth - 32 - 30) / 4;

    return Wrap(
      spacing: 10,
      runSpacing: 14,
      children: items.map((item) {
        final hasLiveDot = item['hasLiveDot'] == true;
        final badgeText = item['badgeText'] as String? ?? '';
        final badgeColorHex = item['badgeColor'] as String? ?? '';
        final iconImageUrl = item['iconImageUrl'] as String? ?? '';

        final isLocked = item['locked'] == true;
        final isEmergency = item['isEmergency'] == true;
        final isScanner = item['isScanner'] == true;

        // Emergency is the one filled tile in the comp; everything else is a
        // white tile with a coloured glyph.
        final Color tileColor =
            isEmergency ? AppColors.burundiRed : Ds.surface(context);
        final Color glyphColor = isEmergency
            ? Colors.white
            : isLocked
                ? Ds.muted(context)
                : isScanner
                    ? AppColors.scannerBlue
                    : Ds.green;

        Widget iconContent;
        if (iconImageUrl.isNotEmpty) {
          iconContent = ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AppNetworkImage(
              imageUrl: iconImageUrl,
              width: 48,
              height: 48,
              fit: BoxFit.contain,
              placeholder: (_, _) =>
                  Icon(item['icon'] as IconData, color: glyphColor, size: 24),
              errorWidget: (_, _, _) =>
                  Icon(item['icon'] as IconData, color: glyphColor, size: 24),
            ),
          );
        } else {
          iconContent = Icon(item['icon'] as IconData, color: glyphColor, size: 24);
        }

        return _AnimatedQuickTile(
          index: items.indexOf(item),
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
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: tileColor,
                          borderRadius: BorderRadius.circular(Ds.rCard),
                          boxShadow: Ds.shadow(context),
                        ),
                        child: Center(child: iconContent),
                      ),
                      if (badgeText.isNotEmpty)
                        Positioned(
                          top: -6,
                          right: -10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 2),
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
                  const SizedBox(height: 7),
                  Text(
                    item['title'] as String,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                      color: isEmergency ? AppColors.burundiRed : Ds.ink(context),
                    ),
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


/// Quick Access tile motion: a staggered fade-and-rise on first paint, and a
/// spring-y press-down on tap. Pure Flutter — no animation package needed.
class _AnimatedQuickTile extends StatefulWidget {
  final int index;
  final VoidCallback onTap;
  final Widget child;

  const _AnimatedQuickTile({
    required this.index,
    required this.onTap,
    required this.child,
  });

  @override
  State<_AnimatedQuickTile> createState() => _AnimatedQuickTileState();
}

class _AnimatedQuickTileState extends State<_AnimatedQuickTile> {
  bool _pressed = false;
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    // Stagger the entrance by position so the grid ripples in.
    Future.delayed(Duration(milliseconds: 40 * widget.index), () {
      if (mounted) setState(() => _shown = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedOpacity(
        opacity: _shown ? 1 : 0,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
        child: AnimatedSlide(
          offset: _shown ? Offset.zero : const Offset(0, 0.18),
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          child: AnimatedScale(
            scale: _pressed ? 0.90 : 1.0,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
