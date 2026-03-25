/// App-wide constants
///
/// IMPORTANT: This file should only contain build-time constants.
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

  // Nationality choices (ISO code → display name), matches backend NATIONALITY_CHOICES
  static const Map<String, String> nationalityChoices = {
    // AU Member States
    'DZ': 'Algeria', 'AO': 'Angola', 'BJ': 'Benin', 'BW': 'Botswana',
    'BF': 'Burkina Faso', 'BI': 'Burundi', 'CV': 'Cabo Verde', 'CM': 'Cameroon',
    'CF': 'Central African Republic', 'TD': 'Chad', 'KM': 'Comoros',
    'CG': 'Congo (Brazzaville)', 'CD': 'Congo (DRC)', 'CI': "Côte d'Ivoire",
    'DJ': 'Djibouti', 'EG': 'Egypt', 'GQ': 'Equatorial Guinea', 'ER': 'Eritrea',
    'SZ': 'Eswatini', 'ET': 'Ethiopia', 'GA': 'Gabon', 'GM': 'Gambia',
    'GH': 'Ghana', 'GN': 'Guinea', 'GW': 'Guinea-Bissau', 'KE': 'Kenya',
    'LS': 'Lesotho', 'LR': 'Liberia', 'LY': 'Libya', 'MG': 'Madagascar',
    'MW': 'Malawi', 'ML': 'Mali', 'MR': 'Mauritania', 'MU': 'Mauritius',
    'MA': 'Morocco', 'MZ': 'Mozambique', 'NA': 'Namibia', 'NE': 'Niger',
    'NG': 'Nigeria', 'RW': 'Rwanda', 'ST': 'São Tomé and Príncipe',
    'SN': 'Senegal', 'SC': 'Seychelles', 'SL': 'Sierra Leone', 'SO': 'Somalia',
    'ZA': 'South Africa', 'SS': 'South Sudan', 'SD': 'Sudan',
    'TZ': 'Tanzania', 'TG': 'Togo', 'TN': 'Tunisia', 'UG': 'Uganda',
    'ZM': 'Zambia', 'ZW': 'Zimbabwe',
    // Key international
    'BE': 'Belgium', 'BR': 'Brazil', 'CA': 'Canada', 'CN': 'China',
    'FR': 'France', 'DE': 'Germany', 'IN': 'India', 'JP': 'Japan',
    'RU': 'Russia', 'SA': 'Saudi Arabia', 'TR': 'Turkey', 'AE': 'UAE',
    'GB': 'United Kingdom', 'US': 'United States',
    'OTHER': 'Other',
  };
}
