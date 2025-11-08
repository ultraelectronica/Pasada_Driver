import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Foreground service that keeps the app running with high priority in the background.
/// This service maintains a persistent notification but does NOT track location.
/// Location tracking is handled by the DriverProvider in the main isolate.
@pragma('vm:entry-point')
class BackgroundLocationService {
  BackgroundLocationService._();
  static final BackgroundLocationService instance =
      BackgroundLocationService._();

  final _service = FlutterBackgroundService();
  bool _isRunning = false;

  bool get isRunning => _isRunning;

  /// Initialize the background service. Must be called before starting.
  Future<void> initialize() async {
    // Create notification channel for Android 8.0+
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'pasada_foreground_service', // id
      'App Background Service', // name
      description: 'Keeps Pasada Driver app running in the background',
      importance: Importance.low, // Low importance to avoid annoying users
      playSound: false,
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'pasada_foreground_service',
        initialNotificationTitle: 'Pasada Driver',
        initialNotificationContent: 'App is running in the background',
        foregroundServiceNotificationId: 888,
        foregroundServiceTypes: [AndroidForegroundType.location],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  /// Start the foreground service to keep app running in background
  Future<void> start() async {
    if (_isRunning) {
      if (kDebugMode) {
        debugPrint('BackgroundLocationService: Already running');
      }
      return;
    }

    try {
      await _service.startService();
      _isRunning = true;
      if (kDebugMode) {
        debugPrint('BackgroundLocationService: Started successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('BackgroundLocationService: Failed to start - $e');
      }
    }
  }

  /// Stop the foreground service
  Future<void> stop() async {
    if (!_isRunning) return;

    try {
      final running = await _service.isRunning();
      if (running) {
        _service.invoke('stop');
      }
      _isRunning = false;
      if (kDebugMode) {
        debugPrint('BackgroundLocationService: Stopped');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('BackgroundLocationService: Failed to stop - $e');
      }
    }
  }

  /// Entry point for the foreground service
  /// This service simply keeps the app running with a persistent notification
  /// Location tracking is handled by the DriverProvider in the main isolate
  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();

    if (kDebugMode) {
      debugPrint('BackgroundLocationService: Service started');
    }

    // Set up foreground/background listeners for Android
    // These listeners are only applicable on Android but won't cause issues on iOS
    // We use dynamic casting because these methods are Android-specific
    service.on('setAsForeground').listen((event) {
      try {
        (service as dynamic).setAsForegroundService();
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
              'BackgroundLocationService: setAsForeground error (likely iOS) - $e');
        }
      }
    });

    service.on('setAsBackground').listen((event) {
      try {
        (service as dynamic).setAsBackgroundService();
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
              'BackgroundLocationService: setAsBackground error (likely iOS) - $e');
        }
      }
    });

    Timer? keepAliveTimer;

    // Set up stop listener
    service.on('stop').listen((event) async {
      // Clean up resources before stopping
      keepAliveTimer?.cancel();

      if (kDebugMode) {
        debugPrint('BackgroundLocationService: Received stop command');
      }

      // Stop the service (this will remove the notification)
      service.stopSelf();
    });

    // Get shared preferences instance
    final prefs = await SharedPreferences.getInstance();

    // Keep the service running with a simple timer
    // This just maintains the foreground service status
    keepAliveTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      // Update notification to show service is active (Android only)
      try {
        final dynamicService = service as dynamic;
        if (await dynamicService.isForegroundService()) {
          dynamicService.setForegroundNotificationInfo(
            title: 'Pasada Driver',
            content: 'App is running in the background',
          );
        }
      } catch (e) {
        // iOS doesn't support these methods, silently ignore
      }

      // Check if service should stop via SharedPreferences
      final shouldStop = prefs.getBool('stop_background_location') ?? false;
      if (shouldStop) {
        await prefs.setBool('stop_background_location', false);
        timer.cancel();

        if (kDebugMode) {
          debugPrint('BackgroundLocationService: Stop requested via prefs');
        }

        service.stopSelf();
      }
    });
  }

  /// iOS background handler
  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    return true;
  }
}
