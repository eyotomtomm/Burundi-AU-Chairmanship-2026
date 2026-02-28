import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
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
      settings,
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
        message.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
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
        payload: message.data.toString(),
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

    // Navigate based on notification data
    if (_navigatorKey?.currentState == null) return;

    final data = message.data;
    final type = data['type'];

    if (type == 'article') {
      // Navigate to news screen (article list)
      _navigatorKey?.currentState?.pushNamed('/news');
    } else if (type == 'magazine') {
      // Navigate to magazine screen
      _navigatorKey?.currentState?.pushNamed('/magazine');
    } else if (type == 'event') {
      // Navigate to calendar screen
      _navigatorKey?.currentState?.pushNamed('/calendar');
    } else if (type == 'gallery') {
      // Navigate to gallery screen
      _navigatorKey?.currentState?.pushNamed('/gallery');
    } else if (type == 'video') {
      // Navigate to videos screen
      _navigatorKey?.currentState?.pushNamed('/videos');
    } else {
      // Default: Navigate to home screen
      _navigatorKey?.currentState?.pushNamed('/home');
    }
  }

  /// Handle local notification tap
  void _onLocalNotificationTap(NotificationResponse response) {
    // Security: Only log in debug mode (payload might contain sensitive data)
    if (kDebugMode) {
      print('Local notification tapped: ${response.payload}');
    }

    // Navigate based on payload (if present)
    if (response.payload != null && _navigatorKey?.currentState != null) {
      try {
        final data = response.payload!.split(':');
        if (data.length >= 2) {
          final type = data[0];
          // final id = data[1]; // Can be used for detail navigation if needed

          if (type == 'article') {
            _navigatorKey?.currentState?.pushNamed('/news');
          } else if (type == 'magazine') {
            _navigatorKey?.currentState?.pushNamed('/magazine');
          } else if (type == 'event') {
            _navigatorKey?.currentState?.pushNamed('/calendar');
          } else if (type == 'gallery') {
            _navigatorKey?.currentState?.pushNamed('/gallery');
          } else if (type == 'video') {
            _navigatorKey?.currentState?.pushNamed('/videos');
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error parsing notification payload: $e');
        }
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
