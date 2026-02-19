import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  static final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      // App
      'app_name': 'Burundi AU Chairmanship',
      'welcome': 'Welcome',
      'continue': 'Continue',
      'skip': 'Skip',
      'cancel': 'Cancel',
      'save': 'Save',
      'close': 'Close',
      'search': 'Search',
      'loading': 'Loading...',
      'error': 'Error',
      'retry': 'Retry',
      'no_data': 'No data available',
      'success': 'Success',

      // Navigation
      'home': 'Home',
      'magazine': 'Magazine',
      'consular': 'Consular',
      'locations': 'Locations',
      'more': 'More',

      // Auth
      'sign_in': 'Sign In',
      'sign_up': 'Sign Up',
      'sign_out': 'Sign Out',
      'email': 'Email',
      'password': 'Password',
      'confirm_password': 'Confirm Password',
      'full_name': 'Full Name',
      'forgot_password': 'Forgot Password?',
      'no_account': "Don't have an account?",
      'have_account': 'Already have an account?',
      'or_continue_with': 'Or continue with',
      'skip_for_now': 'Skip for now',
      'create_account': 'Create Account',
      'welcome_back': 'Welcome Back!',
      'sign_in_continue': 'Sign in to continue',
      'create_account_text': 'Create your account to get started',

      // Home
      'au_chairmanship': 'AU Chairmanship 2025',
      'burundi_chairmanship': 'Burundi AU Chairmanship',
      'explore_features': 'Explore Features',
      'latest_news': 'Latest News',
      'upcoming_events': 'Upcoming Events',
      'quick_access': 'Quick Access',

      // Features
      'digital_magazine': 'Digital Magazine',
      'digital_magazine_desc': 'Read the latest publications and news',
      'consular_services': 'Consular Services',
      'consular_services_desc': 'Access consular services and information',
      'embassy_locations': 'Embassy Locations',
      'embassy_locations_desc': 'Find embassy and event locations',
      'live_feeds': 'Live Feeds',
      'live_feeds_desc': 'Watch live broadcasts and events',
      'resources': 'Resources',
      'resources_desc': 'Access documents and resources',
      'quick_reference': 'Quick Reference',
      'quick_reference_desc': 'Important contacts and information',
      'emergency_sos': 'Emergency SOS',
      'emergency_sos_desc': 'Quick access to emergency services',

      // Emergency
      'call_embassy': 'Call Embassy',
      'call_police': 'Call Police',
      'call_ambulance': 'Call Ambulance',
      'call_fire': 'Call Fire Service',
      'emergency_contacts': 'Emergency Contacts',
      'your_location': 'Your Location',
      'share_location': 'Share Location',
      'emergency_help': 'Emergency Help',
      'tap_for_help': 'Tap for immediate assistance',

      // Consular
      'visa_services': 'Visa Services',
      'passport_services': 'Passport Services',
      'citizen_services': 'Citizen Services',
      'notary_services': 'Notary Services',
      'travel_advisory': 'Travel Advisory',
      'appointment': 'Book Appointment',

      // Magazine
      'latest_edition': 'Latest Edition',
      'featured_edition': 'Featured Edition',
      'past_editions': 'Past Editions',
      'featured_articles': 'Featured Articles',
      'articles': 'Articles',
      'read_more': 'Read More',
      'download': 'Download',

      // Locations
      'embassies': 'Embassies',
      'embassies_consulates': 'Embassies & Consulates',
      'events': 'Events',
      'get_directions': 'Get Directions',
      'call': 'Call',
      'view_on_map': 'View on Map',

      // Emergency
      'embassy': 'Embassy',
      'police': 'Police',
      'ambulance': 'Ambulance',
      'fire_department': 'Fire Department',

      // Settings
      'settings': 'Settings',
      'language': 'Language',
      'english': 'English',
      'french': 'French',
      'theme': 'Theme',
      'dark': 'Dark',
      'light': 'Light',
      'dark_mode': 'Dark Mode',
      'light_mode': 'Light Mode',
      'notifications': 'Notifications',
      'about': 'About',
      'privacy_policy': 'Privacy Policy',
      'share_app': 'Share App',
      'rate_app': 'Rate App',
      'contact_support': 'Contact Support',
      'tap_to_sign_in': 'Tap to sign in',
      'terms_of_service': 'Terms of Service',
      'version': 'Version',
      'contact_us': 'Contact Us',

      // Splash
      'republic_of_burundi': 'Republic of Burundi',
      'african_union': 'African Union',
      'chairmanship_2025': 'Chairmanship 2025',

      // Live Feeds
      'live': 'LIVE',
      'watch_now': 'Watch Now',
      'upcoming': 'Upcoming',
      'recorded': 'Recorded',

      // Quick Access extras
      'translate': 'Translate',
      'weather': 'Weather',
      'calendar': 'Calendar',
      'no_events': 'No events available',

      // Profile
      'profile': 'Profile',
      'edit_profile': 'Edit Profile',
      'my_account': 'My Account',
      'delete_account': 'Delete Account',
      'delete_account_desc': 'Permanently delete your account and data',
      'delete_account_confirm': 'This will permanently delete your account and all associated data. This action cannot be undone.\n\nAre you sure you want to continue?',
      'export_data': 'Export My Data',
      'export_data_desc': 'Download all your account data',
      'account_deleted': 'Your account has been deleted.',
      'profile_updated': 'Profile updated successfully.',
      'update_name': 'Update Name',
      'enter_name': 'Enter your name',
      'account_settings': 'Account Settings',
      'personal_info': 'Personal Information',
      'data_privacy': 'Data & Privacy',
      'danger_zone': 'Danger Zone',
    },
    'fr': {
      // App
      'app_name': 'Présidence UA du Burundi',
      'welcome': 'Bienvenue',
      'continue': 'Continuer',
      'skip': 'Passer',
      'cancel': 'Annuler',
      'save': 'Enregistrer',
      'close': 'Fermer',
      'search': 'Rechercher',
      'loading': 'Chargement...',
      'error': 'Erreur',
      'retry': 'Réessayer',
      'no_data': 'Aucune donnée disponible',
      'success': 'Succès',

      // Navigation
      'home': 'Accueil',
      'magazine': 'Magazine',
      'consular': 'Consulaire',
      'locations': 'Emplacements',
      'more': 'Plus',

      // Auth
      'sign_in': 'Se connecter',
      'sign_up': "S'inscrire",
      'sign_out': 'Se déconnecter',
      'email': 'E-mail',
      'password': 'Mot de passe',
      'confirm_password': 'Confirmer le mot de passe',
      'full_name': 'Nom complet',
      'forgot_password': 'Mot de passe oublié?',
      'no_account': "Vous n'avez pas de compte?",
      'have_account': 'Vous avez déjà un compte?',
      'or_continue_with': 'Ou continuer avec',
      'skip_for_now': 'Passer pour le moment',
      'create_account': 'Créer un compte',
      'welcome_back': 'Bon retour!',
      'sign_in_continue': 'Connectez-vous pour continuer',
      'create_account_text': 'Créez votre compte pour commencer',

      // Home
      'au_chairmanship': 'Présidence UA 2025',
      'burundi_chairmanship': 'Présidence UA du Burundi',
      'explore_features': 'Explorer les fonctionnalités',
      'latest_news': 'Dernières nouvelles',
      'upcoming_events': 'Événements à venir',
      'quick_access': 'Accès rapide',

      // Features
      'digital_magazine': 'Magazine numérique',
      'digital_magazine_desc': 'Lisez les dernières publications et actualités',
      'consular_services': 'Services consulaires',
      'consular_services_desc': 'Accédez aux services et informations consulaires',
      'embassy_locations': "Emplacements de l'ambassade",
      'embassy_locations_desc': "Trouvez les emplacements de l'ambassade et des événements",
      'live_feeds': 'Diffusions en direct',
      'live_feeds_desc': 'Regardez les diffusions et événements en direct',
      'resources': 'Ressources',
      'resources_desc': 'Accédez aux documents et ressources',
      'quick_reference': 'Référence rapide',
      'quick_reference_desc': 'Contacts et informations importants',
      'emergency_sos': 'SOS Urgence',
      'emergency_sos_desc': "Accès rapide aux services d'urgence",

      // Emergency
      'call_embassy': "Appeler l'ambassade",
      'call_police': 'Appeler la police',
      'call_ambulance': "Appeler l'ambulance",
      'call_fire': 'Appeler les pompiers',
      'emergency_contacts': "Contacts d'urgence",
      'your_location': 'Votre position',
      'share_location': 'Partager la position',
      'emergency_help': "Aide d'urgence",
      'tap_for_help': 'Appuyez pour une assistance immédiate',

      // Consular
      'visa_services': 'Services de visa',
      'passport_services': 'Services de passeport',
      'citizen_services': 'Services aux citoyens',
      'notary_services': 'Services notariaux',
      'travel_advisory': 'Conseils aux voyageurs',
      'appointment': 'Prendre rendez-vous',

      // Magazine
      'latest_edition': 'Dernière édition',
      'featured_edition': 'Édition en vedette',
      'past_editions': 'Éditions passées',
      'featured_articles': 'Articles en vedette',
      'articles': 'Articles',
      'read_more': 'Lire la suite',
      'download': 'Télécharger',

      // Locations
      'embassies': 'Ambassades',
      'embassies_consulates': 'Ambassades et Consulats',
      'events': 'Événements',
      'get_directions': 'Obtenir les directions',
      'call': 'Appeler',
      'view_on_map': 'Voir sur la carte',

      // Emergency
      'embassy': 'Ambassade',
      'police': 'Police',
      'ambulance': 'Ambulance',
      'fire_department': 'Pompiers',

      // Settings
      'settings': 'Paramètres',
      'language': 'Langue',
      'english': 'Anglais',
      'french': 'Français',
      'theme': 'Thème',
      'dark': 'Sombre',
      'light': 'Clair',
      'dark_mode': 'Mode sombre',
      'light_mode': 'Mode clair',
      'notifications': 'Notifications',
      'about': 'À propos',
      'privacy_policy': 'Politique de confidentialité',
      'share_app': "Partager l'application",
      'rate_app': "Noter l'application",
      'contact_support': 'Contacter le support',
      'tap_to_sign_in': 'Appuyez pour vous connecter',
      'terms_of_service': "Conditions d'utilisation",
      'version': 'Version',
      'contact_us': 'Nous contacter',

      // Splash
      'republic_of_burundi': 'République du Burundi',
      'african_union': 'Union Africaine',
      'chairmanship_2025': 'Présidence 2025',

      // Live Feeds
      'live': 'EN DIRECT',
      'watch_now': 'Regarder maintenant',
      'upcoming': 'À venir',
      'recorded': 'Enregistré',

      // Quick Access extras
      'translate': 'Traduire',
      'weather': 'Météo',
      'calendar': 'Calendrier',
      'no_events': 'Aucun événement disponible',

      // Profile
      'profile': 'Profil',
      'edit_profile': 'Modifier le profil',
      'my_account': 'Mon compte',
      'delete_account': 'Supprimer le compte',
      'delete_account_desc': 'Supprimer définitivement votre compte et vos données',
      'delete_account_confirm': 'Cela supprimera définitivement votre compte et toutes les données associées. Cette action est irréversible.\n\nÊtes-vous sûr de vouloir continuer?',
      'export_data': 'Exporter mes données',
      'export_data_desc': 'Télécharger toutes vos données de compte',
      'account_deleted': 'Votre compte a été supprimé.',
      'profile_updated': 'Profil mis à jour avec succès.',
      'update_name': 'Modifier le nom',
      'enter_name': 'Entrez votre nom',
      'account_settings': 'Paramètres du compte',
      'personal_info': 'Informations personnelles',
      'data_privacy': 'Données et confidentialité',
      'danger_zone': 'Zone de danger',
    },
  };

  String translate(String key) {
    return _localizedValues[locale.languageCode]?[key] ?? key;
  }

  // Convenience getters
  String get appName => translate('app_name');
  String get welcome => translate('welcome');
  String get continueText => translate('continue');
  String get skip => translate('skip');
  String get cancel => translate('cancel');
  String get save => translate('save');
  String get close => translate('close');
  String get search => translate('search');
  String get loading => translate('loading');
  String get error => translate('error');
  String get retry => translate('retry');
  String get noData => translate('no_data');
  String get success => translate('success');

  // Navigation
  String get home => translate('home');
  String get magazine => translate('magazine');
  String get consular => translate('consular');
  String get locations => translate('locations');
  String get more => translate('more');

  // Auth
  String get signIn => translate('sign_in');
  String get signUp => translate('sign_up');
  String get signOut => translate('sign_out');
  String get email => translate('email');
  String get password => translate('password');
  String get confirmPassword => translate('confirm_password');
  String get fullName => translate('full_name');
  String get forgotPassword => translate('forgot_password');
  String get noAccount => translate('no_account');
  String get haveAccount => translate('have_account');
  String get orContinueWith => translate('or_continue_with');
  String get skipForNow => translate('skip_for_now');
  String get createAccount => translate('create_account');
  String get welcomeBack => translate('welcome_back');
  String get signInContinue => translate('sign_in_continue');
  String get createAccountText => translate('create_account_text');

  // Features
  String get digitalMagazine => translate('digital_magazine');
  String get digitalMagazineDesc => translate('digital_magazine_desc');
  String get consularServices => translate('consular_services');
  String get consularServicesDesc => translate('consular_services_desc');
  String get embassyLocations => translate('embassy_locations');
  String get embassyLocationsDesc => translate('embassy_locations_desc');
  String get liveFeeds => translate('live_feeds');
  String get liveFeedsDesc => translate('live_feeds_desc');
  String get resources => translate('resources');
  String get resourcesDesc => translate('resources_desc');
  String get quickReference => translate('quick_reference');
  String get quickReferenceDesc => translate('quick_reference_desc');
  String get emergencySos => translate('emergency_sos');
  String get emergencySosDesc => translate('emergency_sos_desc');

  // Emergency
  String get callEmbassy => translate('call_embassy');
  String get callPolice => translate('call_police');
  String get callAmbulance => translate('call_ambulance');
  String get callFire => translate('call_fire');
  String get emergencyContacts => translate('emergency_contacts');
  String get yourLocation => translate('your_location');
  String get shareLocation => translate('share_location');
  String get emergencyHelp => translate('emergency_help');
  String get tapForHelp => translate('tap_for_help');

  // Settings
  String get settings => translate('settings');
  String get language => translate('language');
  String get english => translate('english');
  String get french => translate('french');
  String get theme => translate('theme');
  String get darkMode => translate('dark_mode');
  String get lightMode => translate('light_mode');
  String get notifications => translate('notifications');
  String get about => translate('about');
  String get privacyPolicy => translate('privacy_policy');
  String get termsOfService => translate('terms_of_service');
  String get version => translate('version');
  String get contactUs => translate('contact_us');

  // Splash
  String get republicOfBurundi => translate('republic_of_burundi');
  String get africanUnion => translate('african_union');
  String get chairmanship2025 => translate('chairmanship_2025');
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'fr'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
