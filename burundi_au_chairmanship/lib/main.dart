import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

import 'firebase_options.dart';
import 'config/app_theme.dart';
import 'config/app_constants.dart';
import 'providers/theme_provider.dart';
import 'providers/language_provider.dart';
import 'providers/auth_provider.dart';
import 'services/analytics_service.dart';
import 'services/firebase_messaging_service.dart';
import 'services/remote_config_service.dart';
import 'l10n/app_localizations.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/emergency/emergency_screen.dart';
import 'screens/live_feeds/live_feeds_screen.dart';
import 'screens/resources/resources_screen.dart';
import 'screens/calendar/calendar_screen.dart';
import 'screens/news/news_screen.dart';
import 'screens/magazine/magazine_screen.dart';
import 'screens/translate/translate_screen.dart';
import 'screens/weather/weather_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/agenda/water_sanitation_screen.dart';
import 'screens/agenda/arise_initiative_screen.dart';
import 'screens/agenda/peace_security_screen.dart';
import 'screens/gallery/gallery_screen.dart';
import 'screens/videos/videos_screen.dart';
import 'screens/social_media/social_media_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Initialize Crashlytics
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;
  } catch (e) {
    print('Firebase initialization failed: $e');
    print('App will continue without Firebase features');
    print('To enable Firebase: Follow steps in FIREBASE_SETUP_GUIDE.md');
  }

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize services
  final analytics = AnalyticsService();
  await analytics.init();
  await analytics.logAppLaunch();

  // Initialize Firebase Messaging (if Firebase was initialized)
  try {
    final messaging = FirebaseMessagingService();
    await messaging.initialize();
  } catch (e) {
    print('Firebase Messaging initialization failed: $e');
  }

  // Initialize Remote Config (if Firebase was initialized)
  try {
    final remoteConfig = RemoteConfigService();
    await remoteConfig.initialize();
  } catch (e) {
    print('Remote Config initialization failed: $e');
  }

  // Run the app — binding was initialized in this zone, so runApp must stay here
  runApp(const BurundiAUApp());
}

class BurundiAUApp extends StatelessWidget {
  const BurundiAUApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: Consumer2<ThemeProvider, LanguageProvider>(
        builder: (context, themeProvider, languageProvider, _) {
          return MaterialApp(
            title: AppConstants.appName,
            debugShowCheckedModeBanner: false,

            // Theme
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,

            // Localization
            locale: languageProvider.locale,
            supportedLocales: const [
              Locale('en'),
              Locale('fr'),
            ],
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],

            // Routes
            initialRoute: '/',
            routes: {
              '/': (context) => const SplashScreen(),
              '/auth': (context) => const AuthScreen(),
              '/home': (context) => const HomeScreen(),
              '/emergency': (context) => const EmergencyScreen(),
              '/live-feeds': (context) => const LiveFeedsScreen(),
              '/resources': (context) => const ResourcesScreen(),
              '/calendar': (context) => const CalendarScreen(),
              '/news': (context) => const NewsScreen(),
              '/magazine': (context) => const MagazineScreen(),
              '/translate': (context) => const TranslateScreen(),
              '/weather': (context) => const WeatherScreen(),
              '/profile': (context) => const ProfileScreen(),
              '/water-sanitation': (context) => const WaterSanitationScreen(),
              '/arise-initiative': (context) => const AriseInitiativeScreen(),
              '/peace-security': (context) => const PeaceSecurityScreen(),
              '/gallery': (context) => const GalleryScreen(),
              '/videos': (context) => const VideosScreen(),
              '/social-media': (context) => const SocialMediaScreen(),
            },

            // Route not found
            onUnknownRoute: (settings) {
              return MaterialPageRoute(
                builder: (context) => const HomeScreen(),
              );
            },
          );
        },
      ),
    );
  }
}
