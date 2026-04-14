import 'dart:io' show Platform;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_constants.dart';
import '../services/api_service.dart';
import '../widgets/in_app_notification_banner.dart';

/// Top-level function for handling background messages
///
/// This must be a top-level function (not a class method) to work with
/// Firebase background message handlers.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Only log in debug mode to prevent sensitive data leakage
  if (kDebugMode) {
    print('Background message received: ${message.messageId}');
    print('Title: ${message.notification?.title}');
    print('Body: ${message.notification?.body}');
  }
  // Log delivery event (fire-and-forget). Safe to call from a background
  // isolate because ApiService() is a lightweight singleton with its own
  // http client and SharedPreferences-backed auth headers.
  final nid = message.data['notification_id']?.toString();
  if (nid != null && nid.isNotEmpty && nid != '0') {
    try {
      await ApiService().post(
        'notifications/$nid/event/',
        {'type': 'delivered'},
      );
    } catch (_) {
      /* analytics must never break the handler */
    }
  }
}

/// Service for Firebase Cloud Messaging (Push Notifications)
///
/// Handles:
/// - FCM token management (with multi-account support)
/// - Foreground notifications (via local notifications)
/// - Background notifications
/// - Notification tap handling with open tracking
/// - Permission detection with periodic prompts
class FirebaseMessagingService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  GlobalKey<NavigatorState>? _navigatorKey;

  /// Static handle to the navigator key so standalone helpers (e.g. banner
  /// tap handlers) can navigate without a BuildContext.
  static GlobalKey<NavigatorState>? navigatorKey;

  /// The current FCM token (cached for logout deactivation)
  String? _currentToken;

  /// Public read-only access to the cached FCM token so other services
  /// (heartbeat, event tracking) can attach it as an ``X-FCM-Token`` header
  /// without round-tripping to Firebase.
  String? get currentToken => _currentToken;

  /// Track processed message IDs to prevent duplicate notifications
  final Set<String> _processedMessageIds = {};
  static const int _maxProcessedIds = 100;

  /// SharedPreferences key for tracking permission prompt timing
  static const String _permissionPromptKey = 'notification_permission_last_asked';

  /// Initialize Firebase Messaging and request permissions
  ///
  /// Should be called during app startup
  Future<void> initialize(GlobalKey<NavigatorState> navigatorKey) async {
    _navigatorKey = navigatorKey;
    FirebaseMessagingService.navigatorKey = navigatorKey;
    // Request notification permissions
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      announcement: false,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
    );

    if (kDebugMode) {
      print('Notification permission status: ${settings.authorizationStatus}');
    }

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      // Get FCM token and send to backend
      String? token = await _messaging.getToken();
      if (token != null) {
        _currentToken = token;
        // Security: NEVER log FCM tokens in production (accessible in system logs)
        if (kDebugMode) {
          print('FCM Token obtained (length: ${token.length})');
        }
        await _sendTokenToBackend(token);
      }

      // Listen for token refresh
      _messaging.onTokenRefresh.listen((token) {
        _currentToken = token;
        _sendTokenToBackend(token);
      });
    } else if (settings.authorizationStatus == AuthorizationStatus.denied ||
               settings.authorizationStatus == AuthorizationStatus.notDetermined) {
      // Schedule a permission prompt check (will show on next opportunity)
      _schedulePermissionPrompt();
    }

    // Report device info to backend
    _reportDeviceInfo();

    // Initialize local notifications for foreground messages
    await _initializeLocalNotifications();

    // Set up message handlers
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle notification that opened the app from terminated state
    RemoteMessage? initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }
  }

  /// Check if permission is granted
  Future<bool> isPermissionGranted() async {
    final settings = await _messaging.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized;
  }

  /// Check if we should show a permission prompt to the user.
  /// Only prompts once per week to avoid being annoying.
  Future<bool> shouldShowPermissionPrompt() async {
    final granted = await isPermissionGranted();
    if (granted) return false;

    final prefs = await SharedPreferences.getInstance();
    final lastAsked = prefs.getInt(_permissionPromptKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final oneWeekMs = 7 * 24 * 60 * 60 * 1000;

    return (now - lastAsked) > oneWeekMs;
  }

  /// Record that we showed the permission prompt
  Future<void> recordPermissionPromptShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_permissionPromptKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// Show permission prompt dialog (bilingual)
  Future<void> showPermissionDialog(BuildContext context, String langCode) async {
    final shouldShow = await shouldShowPermissionPrompt();
    if (!shouldShow) return;

    await recordPermissionPromptShown();

    if (!context.mounted) return;

    final isEnglish = langCode == 'en';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.notifications_active, color: Color(0xFF1EB53A), size: 28),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isEnglish ? 'Stay Informed' : 'Restez inform\u00e9',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          isEnglish
              ? 'Enable notifications to receive important updates about events, news, and announcements from the Burundi Chairmanship.'
              : 'Activez les notifications pour recevoir les mises \u00e0 jour importantes sur les \u00e9v\u00e9nements, les actualit\u00e9s et les annonces de la Pr\u00e9sidence de l\'UA.',
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              isEnglish ? 'Not Now' : 'Pas maintenant',
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              // Re-request permission
              await _messaging.requestPermission(
                alert: true,
                badge: true,
                sound: true,
              );
              // Try to get token after permission grant
              final token = await _messaging.getToken();
              if (token != null) {
                _currentToken = token;
                await _sendTokenToBackend(token);
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1EB53A),
            ),
            child: Text(isEnglish ? 'Enable' : 'Activer'),
          ),
        ],
      ),
    );
  }

  /// Schedule a permission prompt for later (non-blocking)
  void _schedulePermissionPrompt() {
    // Will be called from the home screen via showPermissionDialog
    if (kDebugMode) {
      print('Notification permission not granted - will prompt later');
    }
  }

  /// Initialize local notifications for displaying notifications while app is in foreground
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );
  }

  /// Handle foreground messages
  ///
  /// Shows a Firebase-style slide-down in-app banner while the app is
  /// foregrounded. Records ``delivered`` + ``displayed`` engagement events
  /// so the admin dashboard can compute real CTR.
  /// Includes deduplication to prevent showing the same notification multiple times.
  void _handleForegroundMessage(RemoteMessage message) {
    if (kDebugMode) {
      print('Foreground message received: ${message.messageId}');
    }

    // Log delivery ASAP (before dedupe) so the backend sees every unique arrival
    final nid = message.data['notification_id']?.toString();
    if (nid != null && nid.isNotEmpty && nid != '0') {
      _trackEvent(nid, 'delivered');
    }

    // Deduplication: generate a stable ID from messageId or content hash
    final messageId = message.messageId ??
        '${message.notification?.title}:${message.notification?.body}:${message.data}'.hashCode.toString();

    if (_processedMessageIds.contains(messageId)) {
      if (kDebugMode) print('Duplicate message skipped: $messageId');
      return;
    }

    _processedMessageIds.add(messageId);
    // Trim set to prevent unbounded memory growth
    if (_processedMessageIds.length > _maxProcessedIds) {
      _processedMessageIds.remove(_processedMessageIds.first);
    }

    final notification = message.notification;
    if (notification == null) return;

    final title = notification.title ?? '';
    final body = notification.body;
    final imageUrl = notification.android?.imageUrl ??
        notification.apple?.imageUrl ??
        message.data['image'] as String?;

    // Prefer the in-app banner when we have a live context
    final ctx = _navigatorKey?.currentContext;
    if (ctx != null && title.isNotEmpty) {
      InAppBanner.show(
        ctx,
        title: title,
        body: body,
        imageUrl: imageUrl,
        notificationId: nid,
        onTap: () {
          if (nid != null) _trackEvent(nid, 'opened');
          _navigateForMessage(message);
        },
      );
      if (nid != null && nid.isNotEmpty && nid != '0') {
        _trackEvent(nid, 'displayed');
      }
      return;
    }

    // Fallback: native local notification if we somehow have no context
    final notificationId = messageId.hashCode.abs() % 2147483647;
    _localNotifications.show(
      id: notificationId,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'default_channel',
          'Default Notifications',
          channelDescription: 'Default notification channel for general updates',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: _buildPayload(message),
    );
    if (nid != null && nid.isNotEmpty && nid != '0') {
      _trackEvent(nid, 'displayed');
    }
  }

  /// Shared navigation for a RemoteMessage — used by both tap and banner tap.
  void _navigateForMessage(RemoteMessage message) {
    if (_navigatorKey?.currentState == null) return;
    final data = message.data;
    final actionType = data['action_type'];
    final actionValue = data['action_value'];
    if (actionType == 'route' &&
        actionValue != null &&
        actionValue.toString().isNotEmpty) {
      _navigatorKey?.currentState?.pushNamed(actionValue.toString());
      return;
    }
    final type = data['type'];
    final routes = {
      'article': '/news',
      'magazine': '/magazine',
      'event': '/calendar',
      'gallery': '/gallery',
      'video': '/videos',
    };
    _navigatorKey?.currentState?.pushNamed(routes[type] ?? '/notifications');
  }

  /// Build notification payload including notification_id for open tracking
  String _buildPayload(RemoteMessage message) {
    final notificationId = message.data['notification_id'] ?? '0';
    final actionType = message.data['action_type'];
    final actionValue = message.data['action_value'] ?? '';
    final type = message.data['type'] ?? 'general';

    // Encode notification_id in the payload for open tracking
    if (actionType == 'route') {
      return 'route:$actionValue|nid:$notificationId';
    }
    return '$type:0|nid:$notificationId';
  }

  /// Handle notification tap (when app is in background or foreground)
  void _handleNotificationTap(RemoteMessage message) {
    // Security: Only log in debug mode (notification data might contain sensitive info)
    if (kDebugMode) {
      print('Notification tapped: ${message.messageId}');
      print('Data: ${message.data}');
    }

    // Track notification open
    final notificationId = message.data['notification_id'];
    if (notificationId != null) {
      _trackNotificationOpened(notificationId);
    }

    if (_navigatorKey?.currentState == null) return;

    final data = message.data;

    // Prefer action_type/action_value for precise deep linking
    final actionType = data['action_type'];
    final actionValue = data['action_value'];
    if (actionType == 'route' && actionValue != null && actionValue.isNotEmpty) {
      _navigatorKey?.currentState?.pushNamed(actionValue);
      return;
    }

    // Fallback: navigate by notification type
    final type = data['type'];
    final routes = {
      'article': '/news',
      'magazine': '/magazine',
      'event': '/calendar',
      'gallery': '/gallery',
      'video': '/videos',
    };
    _navigatorKey?.currentState?.pushNamed(routes[type] ?? '/notifications');
  }

  /// Handle local notification tap
  void _onLocalNotificationTap(NotificationResponse response) {
    if (kDebugMode) print('Local notification tapped: ${response.payload}');

    if (response.payload != null && _navigatorKey?.currentState != null) {
      try {
        final payload = response.payload!;

        // Extract notification_id from payload for open tracking
        final nidMatch = RegExp(r'\|nid:(\d+)').firstMatch(payload);
        if (nidMatch != null) {
          _trackNotificationOpened(nidMatch.group(1)!);
        }

        // Remove the nid suffix for route parsing
        final cleanPayload = payload.replaceAll(RegExp(r'\|nid:\d+'), '');

        // Support action_type:route:/path format
        if (cleanPayload.startsWith('route:')) {
          final route = cleanPayload.substring(6);
          if (route.startsWith('/')) {
            _navigatorKey?.currentState?.pushNamed(route);
            return;
          }
        }

        // Legacy format: type:id
        final data = cleanPayload.split(':');
        if (data.length >= 2) {
          final routes = {
            'article': '/news',
            'magazine': '/magazine',
            'event': '/calendar',
            'gallery': '/gallery',
            'video': '/videos',
          };
          final route = routes[data[0]];
          if (route != null) {
            _navigatorKey?.currentState?.pushNamed(route);
          }
        }
      } catch (e) {
        if (kDebugMode) print('Error parsing notification payload: $e');
      }
    }
  }

  /// Track a notification engagement event (delivered/displayed/opened/dismissed)
  /// on the backend. Always fire-and-forget — analytics must never break the app.
  Future<void> _trackEvent(String notificationId, String type) async {
    try {
      await ApiService().post(
        'notifications/$notificationId/event/',
        {'type': type},
        extraHeaders: _currentToken != null
            ? {'X-FCM-Token': _currentToken!}
            : null,
      );
      if (kDebugMode) {
        print('Notification event tracked: #$notificationId / $type');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to track notification event ($type): $e');
      }
    }
  }

  /// Back-compat shim: older code paths called ``_trackNotificationOpened``.
  Future<void> _trackNotificationOpened(String notificationId) =>
      _trackEvent(notificationId, 'opened');

  /// Read the user's current in-app language from SharedPreferences so the
  /// messaging service can forward it to the backend without pulling in a
  /// Provider dependency from this non-widget context.
  Future<String> _currentLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(AppConstants.languageKey) ?? 'en';
      return (code == 'fr') ? 'fr' : 'en';
    } catch (_) {
      return 'en';
    }
  }

  /// Register FCM token with Django backend (no auth required).
  /// This works for both authenticated and anonymous users,
  /// ensuring all devices can receive global push notifications.
  Future<void> _sendTokenToBackend(String token) async {
    try {
      final lang = await _currentLanguage();
      await ApiService().registerFCMToken(token, preferredLanguage: lang);
      if (kDebugMode) {
        print('FCM token registered with backend successfully (lang=$lang)');
      }
    } catch (e) {
      // Security: Only log detailed errors in debug mode
      if (kDebugMode) {
        print('Failed to register FCM token with backend: $e');
      }
      // Don't throw - this is not critical for app functionality
    }
  }

  /// Link the current FCM token to an authenticated user.
  /// Call this after login to associate the device token with the user account.
  Future<void> linkTokenToUser() async {
    try {
      if (_currentToken != null) {
        final lang = await _currentLanguage();
        await ApiService().updateFCMToken(
          _currentToken!,
          preferredLanguage: lang,
        );
        if (kDebugMode) {
          print('FCM token linked to user successfully (lang=$lang)');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to link FCM token to user: $e');
      }
    }
  }

  /// Deactivate FCM token on logout (don't delete, just deactivate)
  Future<void> deactivateToken() async {
    try {
      if (_currentToken != null) {
        await ApiService().deactivateFCMToken(_currentToken!);
      }
      if (kDebugMode) {
        print('FCM token deactivated on backend');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to deactivate FCM token: $e');
      }
    }
  }

  /// Report device info to backend for analytics
  Future<void> _reportDeviceInfo() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      String deviceType = '';
      String deviceOs = '';

      if (Platform.isAndroid) {
        final info = await deviceInfo.androidInfo;
        deviceType = '${info.brand} ${info.model}';
        deviceOs = 'Android ${info.version.release}';
      } else if (Platform.isIOS) {
        final info = await deviceInfo.iosInfo;
        deviceType = info.utsname.machine;
        deviceOs = '${info.systemName} ${info.systemVersion}';
      }

      await ApiService().updateDeviceInfo(
        deviceType: deviceType,
        deviceOs: deviceOs,
        appVersion: AppConstants.appVersion,
      );
    } catch (e) {
      if (kDebugMode) print('Failed to report device info: $e');
    }
  }

  /// Sync FCM topic subscriptions to match the user's current language.
  ///
  /// Subscribes to ``notif_<code>`` and unsubscribes from the other. Allows
  /// admins to broadcast via FCM Topics API in addition to DB targeting.
  Future<void> syncLanguageTopics(String code) async {
    try {
      if (code == 'fr') {
        await _messaging.subscribeToTopic('notif_fr');
        await _messaging.unsubscribeFromTopic('notif_en');
      } else {
        await _messaging.subscribeToTopic('notif_en');
        await _messaging.unsubscribeFromTopic('notif_fr');
      }
      // Also push the language onto the DeviceToken row so anonymous-targeted
      // sends bucket this device correctly even before the user logs in.
      if (_currentToken != null) {
        try {
          await ApiService().registerFCMToken(
            _currentToken!,
            preferredLanguage: code,
          );
        } catch (_) {
          // Non-critical — topic subscription is the primary signal.
        }
      }
      if (kDebugMode) {
        print('Language topics synced for: $code');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to sync language topics: $e');
      }
    }
  }

  /// Subscribe to a topic for receiving targeted notifications
  ///
  /// Topics allow sending notifications to groups of users
  /// Example topics: 'breaking_news', 'events', 'government_officials'
  Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
    if (kDebugMode) {
      print('Subscribed to topic: $topic');
    }
  }

  /// Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
    if (kDebugMode) {
      print('Unsubscribed from topic: $topic');
    }
  }

  /// Get the current FCM token
  Future<String?> getToken() async {
    return await _messaging.getToken();
  }

  /// Delete the FCM token (useful when user logs out)
  Future<void> deleteToken() async {
    await _messaging.deleteToken();
    _currentToken = null;
    if (kDebugMode) {
      print('FCM token deleted');
    }
  }
}
