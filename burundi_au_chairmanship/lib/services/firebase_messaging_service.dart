import 'dart:io' show Platform;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
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
/// - FCM token management
/// - Foreground notifications (via local notifications)
/// - Background notifications
/// - Notification tap handling
class FirebaseMessagingService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  GlobalKey<NavigatorState>? _navigatorKey;

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
        // Security: NEVER log FCM tokens in production (accessible in system logs)
        if (kDebugMode) {
          print('FCM Token obtained (length: ${token.length})');
        }
        await _sendTokenToBackend(token);
      }

      // Listen for token refresh
      _messaging.onTokenRefresh.listen(_sendTokenToBackend);
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
  /// notifications, so we use flutter_local_notifications to display them
  void _handleForegroundMessage(RemoteMessage message) {
    if (kDebugMode) {
      print('Foreground message received: ${message.messageId}');
    }

    final notification = message.notification;
    if (notification != null) {
      _localNotifications.show(
        id: message.hashCode,
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
        payload: message.data['action_type'] == 'route'
            ? 'route:${message.data['action_value'] ?? ''}'
            : '${message.data['type'] ?? 'general'}:${message.data['id'] ?? '0'}',
      );
    }
  }

  /// Handle notification tap (when app is in background or foreground)
  void _handleNotificationTap(RemoteMessage message) {
    // Security: Only log in debug mode (notification data might contain sensitive info)
    if (kDebugMode) {
      print('Notification tapped: ${message.messageId}');
      print('Data: ${message.data}');
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

        // Support action_type:route:/path format
        if (payload.startsWith('route:')) {
          final route = payload.substring(6);
          if (route.startsWith('/')) {
            _navigatorKey?.currentState?.pushNamed(route);
            return;
          }
        }

        // Legacy format: type:id
        final data = payload.split(':');
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
    if (kDebugMode) {
      print('FCM token deleted');
    }
  }
}
