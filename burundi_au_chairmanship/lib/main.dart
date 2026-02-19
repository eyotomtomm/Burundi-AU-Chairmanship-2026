import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'config/app_theme.dart';
import 'config/app_constants.dart';
import 'providers/theme_provider.dart';
import 'providers/language_provider.dart';
import 'providers/auth_provider.dart';
import 'services/analytics_service.dart';
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  // Initialize privacy-friendly analytics
  final analytics = AnalyticsService();
  await analytics.init();
  await analytics.logAppLaunch();

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
