import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Design tokens for the 2026 "B4Africa Redesign" system.
///
/// Values come straight from `B4Africa Redesign.dc.html`: a #F5F5F5 canvas,
/// a green header with a 28px bottom radius, white 16px cards with a soft
/// shadow, pill badges and 36px rounded icon squares in grouped list tiles.
class Ds {
  Ds._();

  // Brand
  static const green = AppColors.burundiGreen; // #409843
  static const greenDeep = Color(0xFF2E7231);
  static const greenDarker = Color(0xFF2A5C2D);
  static const gold = AppColors.auGold; // #FCD116
  static const red = AppColors.burundiRed; // #E11C23
  static const redDeep = Color(0xFFB3161C);

  // Tinted surfaces
  static const greenTint = Color(0xFFEAF4EA);
  static const greenTintAlt = Color(0xFFE8EFE5);
  static const greenTintDeep = Color(0xFFDDE7DA);
  static const goldTint = Color(0xFFFFF7DA);
  static const redTint = Color(0xFFFDECEA);
  static const blueTint = Color(0xFFE7F1FA);
  static const blue = Color(0xFF1565C0);
  static const goldDeep = Color(0xFFB8860B);
  static const goldInk = Color(0xFF8A6D00);
  static const goldInkDeep = Color(0xFF4A3E00);
  static const chevron = Color(0xFFC0C0C0);

  // Radii
  static const rCard = 16.0;
  static const rTile = 12.0;
  static const rIcon = 10.0;
  static const rHeader = 28.0;
  static const rSheet = 20.0;
  static const rPill = 999.0;

  // Header
  static const headerHPad = 20.0;

  /// Vertical space the floating notch bottom bar covers: its 62px body plus
  /// its 14px top and bottom margins, plus the home-indicator inset. Add to
  /// the bottom of any scrollable inside the home tabs so the last item can
  /// scroll clear of the bar instead of sitting under it forever.
  static double navSpace(BuildContext c) =>
      90 + MediaQuery.viewPaddingOf(c).bottom;

  static bool _dark(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark;

  /// Page canvas behind the cards.
  static Color bg(BuildContext c) =>
      _dark(c) ? AppColors.darkBackground : AppColors.lightBackground;

  /// Card / grouped-list surface.
  static Color surface(BuildContext c) =>
      _dark(c) ? AppColors.darkSurface : Colors.white;

  /// Neutral chip / icon-square fill (the #F5F5F5 squares in settings rows).
  static Color subtle(BuildContext c) =>
      _dark(c) ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF5F5F5);

  /// Hairline between rows inside a grouped card.
  static Color hairline(BuildContext c) =>
      _dark(c) ? AppColors.darkDivider : const Color(0xFFF0F0F0);

  /// Outline for unselected chips and inputs.
  static Color outline(BuildContext c) =>
      _dark(c) ? AppColors.darkDivider : const Color(0xFFE0E0E0);

  /// Primary text.
  static Color ink(BuildContext c) =>
      _dark(c) ? AppColors.darkText : AppColors.lightText;

  /// Secondary text (#666 in the comp).
  static Color body(BuildContext c) =>
      _dark(c) ? AppColors.darkTextSecondary : const Color(0xFF666666);

  /// Tertiary text (#999 in the comp).
  static Color muted(BuildContext c) =>
      _dark(c) ? const Color(0xFF8A8A8A) : const Color(0xFF999999);

  /// Tint used behind primary-coloured icon squares.
  static Color tint(BuildContext c) =>
      _dark(c) ? green.withValues(alpha: 0.18) : greenTint;

  static Color goldTintOf(BuildContext c) =>
      _dark(c) ? goldDeep.withValues(alpha: 0.18) : goldTint;

  static Color redTintOf(BuildContext c) =>
      _dark(c) ? red.withValues(alpha: 0.16) : redTint;

  /// `0 2px 8px rgba(0,0,0,0.06)` — the default card shadow.
  static List<BoxShadow> shadow(BuildContext c) => [
        BoxShadow(
          color: Colors.black.withValues(alpha: _dark(c) ? 0.35 : 0.06),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  /// `0 4px 12px rgba(0,0,0,0.10)` — featured / hero cards.
  static List<BoxShadow> shadowLg(BuildContext c) => [
        BoxShadow(
          color: Colors.black.withValues(alpha: _dark(c) ? 0.45 : 0.10),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  // Type ramp (the comp is a system font at these exact sizes/weights)
  static TextStyle screenTitle(BuildContext c) => const TextStyle(
      fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: Colors.white);
  static TextStyle pageTitle(BuildContext c) => const TextStyle(
      fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: Colors.white);
  static TextStyle sectionTitle(BuildContext c) => TextStyle(
      fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.2, color: ink(c));
  static TextStyle cardTitle(BuildContext c) => TextStyle(
      fontSize: 14, fontWeight: FontWeight.w700, height: 1.3, color: ink(c));
  static TextStyle cardBody(BuildContext c) =>
      TextStyle(fontSize: 12, color: body(c), height: 1.35);
  static TextStyle meta(BuildContext c) => TextStyle(fontSize: 12, color: muted(c));
  static TextStyle tileTitle(BuildContext c) =>
      TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ink(c));

  /// `12px / w700 / 1px tracking / #999` — the ALL-CAPS group labels.
  static TextStyle groupLabel(BuildContext c) => TextStyle(
      fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1, color: muted(c));
}
