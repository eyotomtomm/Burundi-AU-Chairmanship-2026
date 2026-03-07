/// App-wide constants
///
/// IMPORTANT: This file should only contain build-time constants.
/// - Emergency contacts are loaded from /emergency-contacts/ API
/// - Social media URLs are loaded from /settings/ API
/// - Summit theme is loaded from /settings/ API
class AppConstants {
  // App Info (build-time constants)
  static const String appName = 'Burundi AU Chairmanship';
  static const String appVersion = '1.0.0';

  // Storage Keys (build-time constants)
  static const String themeKey = 'theme_mode';
  static const String languageKey = 'language_code';
  static const String userTokenKey = 'user_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String onboardingKey = 'onboarding_complete';

  // Animation Durations (build-time constants)
  static const Duration splashDuration = Duration(seconds: 7);
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const Duration longAnimationDuration = Duration(milliseconds: 500);

  // Fallback values (these should be loaded from API in production)
  static const String summitTheme = 'Africa We Want: Building a Resilient and Prosperous Continent';
  static const String websiteUrl = 'https://www.burundi.gov.bi';

  // DEPRECATED: Use Environment.apiBaseUrl instead
  @Deprecated('Use Environment.apiBaseUrl instead')
  static const String baseApiUrl = 'http://localhost:8000/api';
}
