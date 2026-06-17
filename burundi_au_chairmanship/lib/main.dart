import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import 'firebase_options.dart';
import 'config/app_theme.dart';
import 'config/app_constants.dart';
import 'config/environment.dart';
import 'providers/theme_provider.dart';
import 'providers/language_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/verification_provider.dart';
import 'services/analytics_service.dart';
import 'services/api_service.dart';
import 'services/app_link_service.dart';
import 'services/firebase_messaging_service.dart';
import 'services/remote_config_service.dart';
import 'services/content_cache_service.dart';
import 'services/data_saver_service.dart';
import 'package:firebase_in_app_messaging/firebase_in_app_messaging.dart';
import 'l10n/app_localizations.dart';
import 'l10n/app_localizations_generated.dart';
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
import 'screens/support/support_tickets_screen.dart';
import 'screens/support/ticket_conversation_screen.dart';
import 'screens/support/contact_support_screen.dart';
import 'screens/verification/verification_request_screen.dart';
import 'screens/trending/trending_screen.dart';
import 'screens/events/events_screen.dart';
import 'screens/youth_dialogue/youth_dialogue_main_screen.dart';
import 'screens/youth_dialogue/youth_dialogue_documents_screen.dart';
import 'screens/youth_dialogue/youth_dialogue_credential_screen.dart';
import 'screens/maintenance/maintenance_screen.dart';
import 'screens/scanner/qr_scanner_screen.dart';

// Global navigator key for navigation from services
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Firebase Analytics — available globally for screen/event logging
final FirebaseAnalytics firebaseAnalytics = FirebaseAnalytics.instance;

// Keep a strong reference so the service (and its stream subscriptions) are
// never garbage-collected after the fire-and-forget Future completes.
FirebaseMessagingService? _messagingService;

Future<void> _initializeApp() async {
  // Wire up ApiService with the global navigator key for 503 maintenance redirect
  ApiService.navigatorKey = navigatorKey;

  // Initialize Firebase (with timeout — don't block app startup forever)
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 5));

    // Initialize Crashlytics — chain with Sentry for dual reporting
    FlutterError.onError = (details) {
      FirebaseCrashlytics.instance.recordFlutterError(details);
    };
  } catch (e) {
    if (kDebugMode) {
      print('Firebase initialization failed: $e');
      print('App will continue without Firebase features');
    }
  }

  // Initialize Hive for offline content caching
  await Hive.initFlutter();
  await ContentCacheService().init();
  await DataSaverService().init();
  await ContentCacheService().migrateFromSharedPreferences();

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

  // Initialize local analytics (fast, no network)
  final analytics = AnalyticsService();
  await analytics.init();
  await analytics.logAppLaunch();

  // Log app open to Firebase Analytics (non-blocking)
  try {
    await firebaseAnalytics.logAppOpen();
  } catch (_) {}

  // Initialize Firebase services in background — don't block app startup
  _initFirebaseServicesAsync();

  // Record app open in backend (non-blocking, fire-and-forget)
  _recordBackendAppOpen();
}

/// Non-blocking: init messaging + remote config after the app is running
void _initFirebaseServicesAsync() {
  // Fire-and-forget — these run in the background
  Future(() async {
    try {
      _messagingService = FirebaseMessagingService();
      await _messagingService!.initialize(navigatorKey).timeout(const Duration(seconds: 8));
    } catch (e) {
      if (kDebugMode) print('Firebase Messaging init failed: $e');
    }
  });

  Future(() async {
    try {
      final remoteConfig = RemoteConfigService();
      await remoteConfig.initialize().timeout(const Duration(seconds: 8));
    } catch (e) {
      if (kDebugMode) print('Remote Config init failed: $e');
    }
  });

  Future(() async {
    try {
      FirebaseInAppMessaging.instance.setMessagesSuppressed(false);
    } catch (e) {
      if (kDebugMode) print('FIAM init failed: $e');
    }
  });

  Future(() async {
    try {
      await AppLinkService().initialize();
    } catch (e) {
      if (kDebugMode) print('AppLinkService init failed: $e');
    }
  });
}

/// Non-blocking: record app open event in the backend
void _recordBackendAppOpen() {
  Future(() async {
    try {
      final info = await _getDeviceInfo();
      await ApiService().recordAppOpen(
        deviceId: info['device_id'],
        deviceType: info['device_type'],
        deviceOs: info['device_os'],
        appVersion: AppConstants.appVersion,
      );
    } catch (_) {
      // Silent fail — analytics should never block the app
    }
  });
}

/// Persistent device UUID stored in iOS Keychain / Android Keystore.
/// Survives app reinstalls on iOS and encrypted prefs on Android.
const _deviceIdKey = 'persistent_device_id';
const _deviceIdStorage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
  iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
);

/// Cached in-memory so we don't hit the keystore on every API call.
String? _cachedDeviceId;

Future<String> getOrCreateDeviceId() async {
  if (_cachedDeviceId != null) return _cachedDeviceId!;
  try {
    String? stored = await _deviceIdStorage.read(key: _deviceIdKey);
    if (stored != null && stored.isNotEmpty) {
      _cachedDeviceId = stored;
      return stored;
    }
    final newId = const Uuid().v4();
    await _deviceIdStorage.write(key: _deviceIdKey, value: newId);
    _cachedDeviceId = newId;
    return newId;
  } catch (_) {
    // Fallback: generate a non-persistent UUID (better than nothing)
    _cachedDeviceId = const Uuid().v4();
    return _cachedDeviceId!;
  }
}

/// Gather basic device info for analytics
Future<Map<String, String>> _getDeviceInfo() async {
  String deviceType = 'unknown';
  String deviceOs = 'unknown';
  String deviceId = '';
  try {
    deviceId = await getOrCreateDeviceId();
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      deviceType = 'iOS';
      deviceOs = 'iOS';
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      deviceType = 'Android';
      deviceOs = 'Android';
    }
  } catch (_) {}
  return {
    'device_id': deviceId,
    'device_type': deviceType,
    'device_os': deviceOs,
  };
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await _initializeApp();

  // Global error handler: catch all uncaught async errors to prevent random crashes
  PlatformDispatcher.instance.onError = (error, stack) {
    if (kDebugMode) print('Uncaught error: $error\n$stack');
    try {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    } catch (_) {}
    if (Environment.sentryDsn.isNotEmpty) {
      Sentry.captureException(error, stackTrace: stack);
    }
    return true; // Handled — don't crash the app
  };

  // Graceful error widget: show a friendly UI instead of crashing on widget build errors
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                const Text(
                  'Something went wrong',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please restart the app and try again.',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  };

  // Initialize Sentry if DSN is configured
  if (Environment.sentryDsn.isNotEmpty) {
    await SentryFlutter.init(
      (options) {
        options.dsn = Environment.sentryDsn;
        options.environment = Environment.displayName.toLowerCase();
        options.release = 'burundi-au-app@1.0.0+1';
        options.tracesSampleRate = Environment.sentryTracesSampleRate;
        options.profilesSampleRate = Environment.sentryProfilesSampleRate;
        options.sendDefaultPii = false;
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
              FirebaseAnalyticsObserver(analytics: firebaseAnalytics),
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
              AppLocalizationsGenerated.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],

            // Routes — CupertinoPageRoute enables swipe-back gesture
            initialRoute: '/',
            onGenerateRoute: (settings) {
              final routes = <String, WidgetBuilder>{
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
                '/support-tickets': (context) => const SupportTicketsScreen(),
                '/ticket-conversation': (context) => const TicketConversationScreen(),
                '/contact-support': (context) => const ContactSupportScreen(),
                '/verification-request': (context) => const VerificationRequestScreen(),
                '/trending': (context) => const TrendingScreen(),
                '/events': (context) => const EventsScreen(),
                '/youth-dialogue': (context) => const YouthDialogueMainScreen(),
                '/youth-dialogue-apply': (context) => const YouthDialogueMainScreen(),
                '/youth-dialogue-documents': (context) => const YouthDialogueDocumentsScreen(),
                '/youth-dialogue-credential': (context) => const YouthDialogueCredentialScreen(),
                '/qr-scanner': (context) => const QrScannerScreen(),
              };

              // Handle maintenance route with arguments
              if (settings.name == '/maintenance') {
                final data = settings.arguments as Map<String, dynamic>?;
                return CupertinoPageRoute(
                  builder: (_) => MaintenanceScreen(maintenanceData: data),
                  settings: settings,
                );
              }

              final builder = routes[settings.name];
              if (builder != null) {
                return CupertinoPageRoute(
                  builder: builder,
                  settings: settings,
                );
              }

              // Route not found
              return CupertinoPageRoute(
                builder: (context) => const HomeScreen(),
                settings: settings,
              );
            },
          );
        },
      ),
    );
  }
}
