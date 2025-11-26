import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Top-level background handler required by Firebase Messaging.
///
/// Ensure na i-regitser mo muna sa main.dart sa `main()` before `runApp` like:
///
///   WidgetsFlutterBinding.ensureInitialized();
///   await NotificationService.ensureFirebaseInitialized();
///   FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
///   runApp(...);
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase must be initialized in background isolates as well.
  await NotificationService.ensureFirebaseInitialized();
  if (kDebugMode) {
    debugPrint(
        '[FCM][BG] title=${message.notification?.title} data=${message.data}');
  }
}

class NotificationService {
  NotificationService._();

  static final NotificationService _instance = NotificationService._();
  static NotificationService get instance => _instance;

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _defaultAndroidChannel =
      AndroidNotificationChannel(
    'default_high_importance',
    'High Importance Notifications',
    description: 'Default channel for important notifications.',
    importance: Importance.high,
  );

  static bool _initialized = false;

  // active notification IDs by booking ID
  final Map<String, int> _activeNotifications = {};

  /// Convert booking ID string to a unique integer ID for notifications
  static int _generateNotificationId(String bookingId) {
    return bookingId.hashCode.abs();
  }

  /// Ensures Firebase is initialized
  static Future<void> ensureFirebaseInitialized() async {
    try {
      // If already initialized, this will throw on some platforms; guard via try.
      await Firebase.initializeApp();
    } catch (_) {
      // Ignore when already initialized or when default options are auto-initialized.
    }
  }

  /// Initialize notifications: permissions, token, listeners, and local-notifs.
  Future<void> initialize() async {
    if (_initialized) return;

    await ensureFirebaseInitialized();

    // Local notifications setup
    await _configureLocalNotifications();

    // Permissions (iOS/macOS/web)
    await _requestPermissionsIfNeeded();

    // Get and log token for debugging (consider sending to backend)
    // Handle SERVICE_NOT_AVAILABLE error gracefully (common in emulators)
    try {
      final token = await _messaging.getToken();
      if (kDebugMode) debugPrint('[FCM] token=$token');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FCM] Failed to get token: $e');
        if (e.toString().contains('SERVICE_NOT_AVAILABLE')) {
          debugPrint('[FCM] This typically means:');
          debugPrint(
              '[FCM] 1. Running on emulator without Google Play Services');
          debugPrint('[FCM] 2. Device lacks Google Play Services');
          debugPrint('[FCM] 3. Network connectivity issue');
          debugPrint('[FCM] The app will continue without push notifications.');
        }
      }
      // Continue initialization even if token retrieval fails
    }

    // Foreground presentation options (Apple)
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Listen to foreground messages and show local notifications on Android
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    // When app opened via notification while in background
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);

    // Handle the case where the app was launched by tapping a notification
    try {
      final initial = await _messaging.getInitialMessage();
      if (initial != null) {
        _handleNotificationNavigation(initial);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[FCM] Failed to get initial message: $e');
    }

    _initialized = true;
  }

  Future<void> _configureLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _local.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        // When a local notification is tapped while app is in foreground/background
        // you can route based on payload if needed.
      },
    );

    if (Platform.isAndroid) {
      final androidPlugin = _local.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(_defaultAndroidChannel);
    }
  }

  Future<void> _requestPermissionsIfNeeded() async {
    // On iOS/macOS/web we should explicitly request user permission.
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      sound: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
    );

    if (kDebugMode) {
      debugPrint('[FCM] Authorization status: ${settings.authorizationStatus}');
    }
  }

  void _onForegroundMessage(RemoteMessage message) {
    if (kDebugMode) {
      debugPrint(
          '[FCM][FG] title=${message.notification?.title} data=${message.data}');
    }

    // On Android, show a local notification to emulate system notification while in foreground
    if (Platform.isAndroid) {
      final notification = message.notification;
      if (notification != null) {
        final android = notification.android;
        _local.show(
          message.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              _defaultAndroidChannel.id,
              _defaultAndroidChannel.name,
              channelDescription: _defaultAndroidChannel.description,
              icon: android?.smallIcon ?? '@mipmap/ic_launcher',
              priority: Priority.high,
              importance: Importance.high,
              autoCancel: true, // Automatically dismiss when tapped
            ),
            iOS: const DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          payload: _buildPayloadFromData(message.data),
        );
      }
    }
  }

  void _onMessageOpenedApp(RemoteMessage message) {
    if (kDebugMode) {
      debugPrint('[FCM][OPENED] data=${message.data}');
    }
    _handleNotificationNavigation(message);
  }

  void _handleNotificationNavigation(RemoteMessage message) {
  }

  String? _buildPayloadFromData(Map<String, dynamic> data) {
    if (data.isEmpty) return null;
    try {
      return data.entries.map((e) => '${e.key}=${e.value}').join('&');
    } catch (_) {
      return null;
    }
  }

  /// Public helper to get the current FCM token
  Future<String?> getToken() async {
    try {
      return await _messaging.getToken();
    } catch (e) {
      if (kDebugMode) debugPrint('[FCM] Failed to get token: $e');
      return null;
    }
  }

  /// Subscribe to a topic
  Future<void> subscribeToTopic(String topic) =>
      _messaging.subscribeToTopic(topic);

  /// Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) =>
      _messaging.unsubscribeFromTopic(topic);

  /// Cancel a specific notification by ID
  Future<void> cancelNotification(int id) async {
    try {
      await _local.cancel(id);
      if (kDebugMode) debugPrint('[FCM] Notification $id cancelled');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FCM] Failed to cancel notification $id: $e');
      }
    }
  }

  /// Cancel notification by booking ID
  Future<void> cancelNotificationByBookingId(String bookingId) async {
    try {
      final notificationId =
          _activeNotifications[bookingId] ?? _generateNotificationId(bookingId);

      // On Android, we need to cancel using the tag as well since we set it during creation
      if (Platform.isAndroid) {
        final androidPlugin = _local.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        await androidPlugin?.cancel(notificationId, tag: bookingId);

        // If not tracked, try with generated ID as fallback
        if (_activeNotifications[bookingId] == null) {
          debugPrint(
              '[Notification] Booking not tracked, trying generated ID...');
          final generatedId = _generateNotificationId(bookingId);
          await androidPlugin?.cancel(generatedId, tag: bookingId);
        }
      } else {
        // iOS doesn't use tags
        await _local.cancel(notificationId);

        if (_activeNotifications[bookingId] == null) {
          debugPrint(
              '[Notification] Booking not tracked, trying generated ID...');
          final generatedId = _generateNotificationId(bookingId);
          await _local.cancel(generatedId);
        }
      }

      _activeNotifications.remove(bookingId);

      if (kDebugMode) {
        debugPrint(
            '[Notification] Cancelled for booking: $bookingId (ID: $notificationId)');
        debugPrint(
            '[Notification] Remaining active: ${_activeNotifications.length}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Notification] ❌ Failed to cancel for $bookingId: $e');
      }
    }
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    try {
      await _local.cancelAll();
      if (kDebugMode) debugPrint('[FCM] All notifications cancelled');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FCM] Failed to cancel all notifications: $e');
      }
    }
  }

  /// Shows notification without Firebase
  Future<int> showBasicNotification(String title, String body,
      {String? bookingId, String? payload}) async {
    final int notificationId = bookingId != null
        ? _generateNotificationId(bookingId)
        : DateTime.now().millisecondsSinceEpoch ~/ 1000;

    debugPrint('[Notification] Creating notification...');
    debugPrint('[Notification] Booking ID: $bookingId');
    debugPrint('[Notification] Generated ID: $notificationId');

    try {
      await _local.show(
        notificationId,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'default_high_importance',
            'High Importance Notifications',
            channelDescription: 'Default channel for important notifications.',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            autoCancel: true, // Automatically dismiss when tapped
            tag: bookingId,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: payload ?? bookingId,
      );
      if (bookingId != null) {
        _activeNotifications[bookingId] = notificationId;
      }
      if (kDebugMode) {
        debugPrint('[Notification][INFO] Displayed (ID: $notificationId)');
        if (bookingId != null) {
          debugPrint('[Notification][INFO] Booking ID: $bookingId');
          debugPrint(
              '[Notification][INFO] Active count: ${_activeNotifications.length}');
        }
      }
      return notificationId;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Notification][ERROR] Failed to show notification: $e');
      }
      return notificationId;
    }
  }

  /// Specialized helper: show a "booking cancelled" notification
  /// Uses a prefixed booking ID key so generic auto-cancel logic tied to the
  /// base booking ID will not immediately dismiss this notification.
  Future<int> showCancelledNotification(String bookingId) {
    final String prefixedId = 'Cancelled: $bookingId';
    return showBasicNotification(
      'Booking Cancelled',
      'The passenger cancelled the booking.',
      bookingId: prefixedId,
      payload: bookingId,
    );
  }

  /// Get all active notification booking IDs
  List<String> getActiveNotificationBookingIds() {
    return _activeNotifications.keys.toList();
  }

  /// Clear all tracked notifications (call when driver logs out)
  void clearTracking() {
    _activeNotifications.clear();
    if (kDebugMode) debugPrint('[Notification] Tracking cleared');
  }

  Future<void> debugNotificationStatus() async {
    debugPrint('[Notification Debug]');
    debugPrint('Initialized: $_initialized');
    debugPrint('Active tracked notifications: ${_activeNotifications.length}');

    if (_activeNotifications.isNotEmpty) {
      debugPrint('Booking IDs with notifications:');
      for (var entry in _activeNotifications.entries) {
        debugPrint('  - ${entry.key} (ID: ${entry.value})');
      }
    }

    if (Platform.isAndroid) {
      final androidPlugin = _local.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      final enabled = await androidPlugin?.areNotificationsEnabled();
      debugPrint('Android notifications enabled: $enabled');
    }
  }
}
