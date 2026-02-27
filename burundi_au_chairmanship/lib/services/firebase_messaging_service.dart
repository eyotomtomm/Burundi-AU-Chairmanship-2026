import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io' show Platform;
import '../services/api_service.dart';

/// Top-level function for handling background messages
///
/// This must be a top-level function (not a class method) to work with
/// Firebase background message handlers
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Background message received: ${message.messageId}');
  print('Title: ${message.notification?.title}');
  print('Body: ${message.notification?.body}');
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

  /// Initialize Firebase Messaging and request permissions
  ///
  /// Should be called during app startup
  Future<void> initialize() async {
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

    print('Notification permission status: ${settings.authorizationStatus}');

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      // Get FCM token and send to backend
      String? token = await _messaging.getToken();
      if (token != null) {
        print('FCM Token: $token');
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
    print('Foreground message received: ${message.messageId}');

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
    print('Notification tapped: ${message.messageId}');
    print('Data: ${message.data}');

    // TODO: Navigate based on notification data
    // Example navigation logic:
    // final type = message.data['type'];
    // if (type == 'article') {
    //   final articleId = message.data['article_id'];
    //   // Navigate to article detail screen
    // } else if (type == 'event') {
    //   // Navigate to events screen
    // }
  }

  /// Handle local notification tap
  void _onLocalNotificationTap(NotificationResponse response) {
    print('Local notification tapped: ${response.payload}');
    // TODO: Navigate based on payload
  }

  /// Send FCM token to Django backend
  Future<void> _sendTokenToBackend(String token) async {
    try {
      await ApiService().updateFCMToken(token);
      print('FCM token sent to backend successfully');
    } catch (e) {
      print('Failed to send FCM token to backend: $e');
      // Don't throw - this is not critical for app functionality
    }
  }

  /// Subscribe to a topic for receiving targeted notifications
  ///
  /// Topics allow sending notifications to groups of users
  /// Example topics: 'breaking_news', 'events', 'government_officials'
  Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
    print('Subscribed to topic: $topic');
  }

  /// Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
    print('Unsubscribed from topic: $topic');
  }

  /// Get the current FCM token
  Future<String?> getToken() async {
    return await _messaging.getToken();
  }

  /// Delete the FCM token (useful when user logs out)
  Future<void> deleteToken() async {
    await _messaging.deleteToken();
    print('FCM token deleted');
  }
}
