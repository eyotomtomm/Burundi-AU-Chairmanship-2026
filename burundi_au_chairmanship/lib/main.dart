import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'firebase_options.dart';
import 'config/app_theme.dart';
import 'config/app_constants.dart';
import 'config/environment.dart';
import 'providers/theme_provider.dart';
import 'providers/language_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/verification_provider.dart';
import 'services/analytics_service.dart';
import 'services/firebase_messaging_service.dart';
import 'services/remote_config_service.dart';
import 'l10n/app_localizations.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/live_feeds/live_feeds_screen.dart';
import 'screens/resources/resources_screen.dart';
import 'screens/calendar/calendar_screen.dart';
import 'screens/news/news_screen.dart';
import 'screens/magazine/magazine_screen.dart';
import 'screens/translate/translate_screen.dart';
import 'screens/weather/weather_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/profile/profile_completion_screen.dart';
import 'screens/agenda/water_sanitation_screen.dart';
import 'screens/agenda/arise_initiative_screen.dart';
import 'screens/agenda/peace_security_screen.dart';
import 'screens/gallery/gallery_screen.dart';
import 'screens/videos/videos_screen.dart';
import 'screens/social_media/social_media_screen.dart';
import 'screens/notifications/notifications_screen.dart';
import 'screens/auth/email_verification_screen.dart';

// Global navigator key for navigation from services
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> _initializeApp() async {
  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Initialize Crashlytics — chain with Sentry for dual reporting
    FlutterError.onError = (details) {
      FirebaseCrashlytics.instance.recordFlutterError(details);
      // Sentry's own FlutterError handler is set up by SentryFlutter.init
    };
  } catch (e) {
    if (kDebugMode) {
      print('Firebase initialization failed: $e');
      print('App will continue without Firebase features');
      print('To enable Firebase: Follow steps in FIREBASE_SETUP_GUIDE.md');
    }
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
    await messaging.initialize(navigatorKey);
  } catch (e) {
    if (kDebugMode) {
      print('Firebase Messaging initialization failed: $e');
    }
  }

  // Initialize Remote Config (if Firebase was initialized)
  try {
    final remoteConfig = RemoteConfigService();
    await remoteConfig.initialize();
  } catch (e) {
    if (kDebugMode) {
      print('Remote Config initialization failed: $e');
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await _initializeApp();

  // Initialize Sentry if DSN is configured
  if (Environment.sentryDsn.isNotEmpty) {
    await SentryFlutter.init(
      (options) {
        options.dsn = Environment.sentryDsn;
        options.environment = Environment.displayName.toLowerCase();
        options.release = 'burundi-au-app@1.0.0+1';
        options.tracesSampleRate = Environment.sentryTracesSampleRate;
        options.profilesSampleRate = Environment.sentryProfilesSampleRate;
        options.sendDefaultPii = true;
        options.attachScreenshot = true;
        options.attachViewHierarchy = true;
        // In debug mode, log Sentry events for visibility
        options.debug = kDebugMode;
      },
      appRunner: () => runApp(
        SentryWidget(child: const BurundiAUApp()),
      ),
    );
  } else {
    // No Sentry DSN — run the app directly
    runApp(const BurundiAUApp());
  }
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
        ChangeNotifierProvider(create: (_) => VerificationProvider()),
      ],
      child: Consumer2<ThemeProvider, LanguageProvider>(
        builder: (context, themeProvider, languageProvider, _) {
          return MaterialApp(
            navigatorKey: navigatorKey,
            title: AppConstants.appName,
            debugShowCheckedModeBanner: false,
            navigatorObservers: [
              if (Environment.sentryDsn.isNotEmpty)
                SentryNavigatorObserver(),
            ],

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
              '/live-feeds': (context) => const LiveFeedsScreen(),
              '/resources': (context) => const ResourcesScreen(),
              '/calendar': (context) => const CalendarScreen(),
              '/news': (context) => const NewsScreen(),
              '/magazine': (context) => const MagazineScreen(),
              '/translate': (context) => const TranslateScreen(),
              '/weather': (context) => const WeatherScreen(),
              '/profile': (context) => const ProfileScreen(),
              '/profile-completion': (context) => const ProfileCompletionScreen(),
              '/email-verification': (context) => const EmailVerificationScreen(),
              '/water-sanitation': (context) => const WaterSanitationScreen(),
              '/arise-initiative': (context) => const AriseInitiativeScreen(),
              '/peace-security': (context) => const PeaceSecurityScreen(),
              '/gallery': (context) => const GalleryScreen(),
              '/videos': (context) => const VideosScreen(),
              '/social-media': (context) => const SocialMediaScreen(),
              '/notifications': (context) => const NotificationsScreen(),
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
