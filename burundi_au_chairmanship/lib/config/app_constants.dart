/// App-wide constants
///
/// IMPORTANT: This file should only contain build-time constants.
/// - Social media URLs are loaded from /settings/ API
/// - Summit theme is loaded from /settings/ API
class AppConstants {
  // App Info (build-time constants)
  static const String appName = 'Be 4 Africa';
  static const String appVersion = '1.2.5';

  // Storage Keys (build-time constants)
  static const String themeKey = 'theme_mode';
  static const String languageKey = 'language_code';
  static const String userTokenKey = 'user_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String onboardingKey = 'onboarding_complete';

  // Animation Durations (build-time constants)
  static const Duration splashMinDuration = Duration(milliseconds: 1500);
  static const Duration splashMaxDuration = Duration(seconds: 6);
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

  // Country dial codes: ISO code → dial code
  static const Map<String, String> countryDialCodes = {
    'DZ': '+213', 'AO': '+244', 'BJ': '+229', 'BW': '+267',
    'BF': '+226', 'BI': '+257', 'CV': '+238', 'CM': '+237',
    'CF': '+236', 'TD': '+235', 'KM': '+269',
    'CG': '+242', 'CD': '+243', 'CI': '+225',
    'DJ': '+253', 'EG': '+20', 'GQ': '+240', 'ER': '+291',
    'SZ': '+268', 'ET': '+251', 'GA': '+241', 'GM': '+220',
    'GH': '+233', 'GN': '+224', 'GW': '+245', 'KE': '+254',
    'LS': '+266', 'LR': '+231', 'LY': '+218', 'MG': '+261',
    'MW': '+265', 'ML': '+223', 'MR': '+222', 'MU': '+230',
    'MA': '+212', 'MZ': '+258', 'NA': '+264', 'NE': '+227',
    'NG': '+234', 'RW': '+250', 'ST': '+239',
    'SN': '+221', 'SC': '+248', 'SL': '+232', 'SO': '+252',
    'ZA': '+27', 'SS': '+211', 'SD': '+249',
    'TZ': '+255', 'TG': '+228', 'TN': '+216', 'UG': '+256',
    'ZM': '+260', 'ZW': '+263',
    'BE': '+32', 'BR': '+55', 'CA': '+1', 'CN': '+86',
    'FR': '+33', 'DE': '+49', 'IN': '+91', 'JP': '+81',
    'RU': '+7', 'SA': '+966', 'TR': '+90', 'AE': '+971',
    'GB': '+44', 'US': '+1',
  };

  /// Convert a 2-letter ISO country code to a flag emoji
  static String countryFlag(String countryCode) {
    if (countryCode == 'OTHER' || countryCode.length != 2) return '🌍';
    final firstLetter = countryCode.codeUnitAt(0) - 0x41 + 0x1F1E6;
    final secondLetter = countryCode.codeUnitAt(1) - 0x41 + 0x1F1E6;
    return String.fromCharCodes([firstLetter, secondLetter]);
  }
}
