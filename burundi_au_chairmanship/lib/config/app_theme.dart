import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_ds.dart';

class AppTheme {
  /// The redesign header (`B4Africa Redesign.dc.html`): green, left-aligned
  /// 19px/w800 title, no elevation, 28px bottom corner radius. Shared by both
  /// themes — the comp keeps the header green in dark mode too.
  static const AppBarTheme _dsAppBar = AppBarTheme(
    backgroundColor: Ds.green,
    foregroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: false,
    toolbarHeight: 64,
    titleSpacing: 12,
    systemOverlayStyle: SystemUiOverlayStyle(
      statusBarBrightness: Brightness.dark,
      statusBarIconBrightness: Brightness.light,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(Ds.rHeader)),
    ),
    titleTextStyle: TextStyle(
      fontSize: 19,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.3,
      color: Colors.white,
    ),
    iconTheme: IconThemeData(color: Colors.white, size: 22),
    actionsIconTheme: IconThemeData(color: Colors.white, size: 22),
  );

  /// Returns a theme-aware BoxShadow for cards and elevated surfaces.
  /// Shadow opacity adapts based on light/dark theme.
  static BoxShadow cardShadow(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shadowColor = Theme.of(context).shadowColor;
    return BoxShadow(
      color: shadowColor.withValues(alpha: isDark ? 0.4 : 0.1),
      blurRadius: 12,
      offset: const Offset(0, 4),
    );
  }

  static const _pageTransitions = PageTransitionsTheme(
    builders: {
      TargetPlatform.android: CupertinoPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
    },
  );

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: AppColors.burundiGreen,
    scaffoldBackgroundColor: AppColors.lightBackground,
    pageTransitionsTheme: _pageTransitions,
    colorScheme: const ColorScheme.light(
      primary: AppColors.burundiGreen,
      secondary: AppColors.burundiRed,
      tertiary: AppColors.auGold,
      surface: AppColors.lightSurface,
      error: AppColors.error,
    ),
    appBarTheme: _dsAppBar,
    cardTheme: CardThemeData(
      color: AppColors.lightSurface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.burundiGreen,
        foregroundColor: AppColors.burundiWhite,
        elevation: 2,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.burundiGreen,
        side: const BorderSide(color: AppColors.burundiGreen, width: 2),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.lightSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.lightDivider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.lightDivider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.burundiGreen, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    textTheme: TextTheme(
      displayLarge: const TextStyle(
        fontSize: 32,
        fontFamily: 'HeatherGreen',
        color: AppColors.lightText,
      ),
      displayMedium: const TextStyle(
        fontSize: 28,
        fontFamily: 'HeatherGreen',
        color: AppColors.lightText,
      ),
      headlineLarge: const TextStyle(
        fontSize: 24,
        fontFamily: 'HeatherGreen',
        color: AppColors.lightText,
      ),
      headlineMedium: const TextStyle(
        fontSize: 20,
        fontFamily: 'HeatherGreen',
        color: AppColors.lightText,
      ),
      titleLarge: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.lightText,
      ),
      titleMedium: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: AppColors.lightText,
      ),
      bodyLarge: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: AppColors.lightText,
      ),
      bodyMedium: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.lightTextSecondary,
      ),
      labelLarge: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.lightText,
      ),
    ),
    // Any remaining native Switch matches the design system's pill toggle.
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
          (states) => Colors.white),
      trackColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? AppColors.burundiGreen
              : const Color(0xFFE0E0E0)),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      trackOutlineWidth: WidgetStateProperty.all(0),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.lightDivider,
      thickness: 1,
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 48),
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.lightSurface,
      selectedItemColor: AppColors.burundiGreen,
      unselectedItemColor: Color(0xFF8A8A8A),
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      unselectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: AppColors.burundiGreen,
    scaffoldBackgroundColor: AppColors.darkBackground,
    pageTransitionsTheme: _pageTransitions,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.burundiGreen,
      secondary: AppColors.burundiRed,
      tertiary: AppColors.auGold,
      surface: AppColors.darkSurface,
      error: AppColors.error,
    ),
    appBarTheme: _dsAppBar,
    cardTheme: CardThemeData(
      color: AppColors.darkSurface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.burundiGreen,
        foregroundColor: AppColors.burundiWhite,
        elevation: 2,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.burundiGreen,
        side: const BorderSide(color: AppColors.burundiGreen, width: 2),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.darkSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.darkDivider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.darkDivider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.burundiGreen, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    textTheme: TextTheme(
      displayLarge: const TextStyle(
        fontSize: 32,
        fontFamily: 'HeatherGreen',
        color: AppColors.darkText,
      ),
      displayMedium: const TextStyle(
        fontSize: 28,
        fontFamily: 'HeatherGreen',
        color: AppColors.darkText,
      ),
      headlineLarge: const TextStyle(
        fontSize: 24,
        fontFamily: 'HeatherGreen',
        color: AppColors.darkText,
      ),
      headlineMedium: const TextStyle(
        fontSize: 20,
        fontFamily: 'HeatherGreen',
        color: AppColors.darkText,
      ),
      titleLarge: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.darkText,
      ),
      titleMedium: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: AppColors.darkText,
      ),
      bodyLarge: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: AppColors.darkText,
      ),
      bodyMedium: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.darkTextSecondary,
      ),
      labelLarge: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.darkText,
      ),
    ),
    // Any remaining native Switch matches the design system's pill toggle.
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
          (states) => Colors.white),
      trackColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? AppColors.burundiGreen
              : const Color(0xFFE0E0E0)),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      trackOutlineWidth: WidgetStateProperty.all(0),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.darkDivider,
      thickness: 1,
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 48),
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.darkSurface,
      selectedItemColor: AppColors.burundiGreen,
      unselectedItemColor: Color(0xFF8A8A8A),
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      unselectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
    ),
  );
}
