import 'dart:io' show Platform;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_constants.dart';
import '../services/api_service.dart';

/// Top-level function for handling background messages
///
/// This must be a top-level function (not a class method) to work with
/// Firebase background message handlers
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Only log in debug mode to prevent sensitive data leakage
  if (kDebugMode) {
    print('Background message received: ${message.messageId}');
    print('Title: ${message.notification?.title}');
    print('Body: ${message.notification?.body}');
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

  /// The current FCM token (cached for logout deactivation)
  String? _currentToken;

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
              ? 'Enable notifications to receive important updates about events, news, and announcements from the AU Chairmanship.'
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

  /// Handle foreground messages by showing a local notification
  ///
  /// When the app is in the foreground, Firebase doesn't automatically show
  /// notifications, so we use flutter_local_notifications to display them.
  /// Includes deduplication to prevent showing the same notification multiple times.
  void _handleForegroundMessage(RemoteMessage message) {
    if (kDebugMode) {
      print('Foreground message received: ${message.messageId}');
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
    if (notification != null) {
      // Use stable notification ID from messageId to prevent system-level duplicates
      final notificationId = messageId.hashCode.abs() % 2147483647;

      _localNotifications.show(
        id: notificationId,
        title: notification.title,
        body: notification.body,
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
    }
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

  /// Track that a notification was opened by calling the backend API
  Future<void> _trackNotificationOpened(String notificationId) async {
    try {
      await ApiService().post(
        'notifications/$notificationId/opened/',
        {},
        auth: true,
      );
      if (kDebugMode) {
        print('Notification open tracked: #$notificationId');
      }
    } catch (e) {
      // Non-critical - don't let tracking failures affect user experience
      if (kDebugMode) {
        print('Failed to track notification open: $e');
      }
    }
  }

  /// Send FCM token to Django backend
  Future<void> _sendTokenToBackend(String token) async {
    try {
      await ApiService().updateFCMToken(token);
      if (kDebugMode) {
        print('FCM token sent to backend successfully');
      }
    } catch (e) {
      // Security: Only log detailed errors in debug mode
      if (kDebugMode) {
        print('Failed to send FCM token to backend: $e');
      }
      // Don't throw - this is not critical for app functionality
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
