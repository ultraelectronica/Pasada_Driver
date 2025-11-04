import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:location/location.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Background service for continuous location tracking even when app is in background.
/// This service runs as a foreground service on Android with a persistent notification.
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
      'pasada_location_tracking', // id
      'Location Tracking', // name
      description: 'Continuous location tracking for Pasada Driver',
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
        notificationChannelId: 'pasada_location_tracking',
        initialNotificationTitle: 'Pasada Driver',
        initialNotificationContent: 'Location tracking is active',
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

  /// Start the background location tracking service
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

  /// Stop the background location tracking service
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

  /// Entry point for the background service
  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();

    if (service is AndroidServiceInstance) {
      service.on('setAsForeground').listen((event) {
        service.setAsForegroundService();
      });

      service.on('setAsBackground').listen((event) {
        service.setAsBackgroundService();
      });
    }

    // Initialize location tracking
    final location = Location();
    StreamSubscription<LocationData>? locationSubscription;
    Timer? keepAliveTimer;

    service.on('stop').listen((event) async {
      // Clean up resources before stopping
      await locationSubscription?.cancel();
      keepAliveTimer?.cancel();

      // Disable background mode
      try {
        await location.enableBackgroundMode(enable: false);
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
              'BackgroundLocationService: Error disabling background mode - $e');
        }
      }

      // Stop the service (this will remove the notification)
      service.stopSelf();
    });

    // Get driver ID from shared preferences
    final prefs = await SharedPreferences.getInstance();
    final driverId = prefs.getString('driver_id');

    if (driverId == null || driverId.isEmpty) {
      if (kDebugMode) {
        debugPrint('BackgroundLocationService: No driver ID found');
      }
      service.stopSelf();
      return;
    }

    // Initialize Supabase if not already initialized
    try {
      if (!Supabase.instance.isInitialized) {
        // You'll need to store these in shared preferences or secure storage
        final supabaseUrl = prefs.getString('supabase_url');
        final supabaseKey = prefs.getString('supabase_key');

        if (supabaseUrl != null && supabaseKey != null) {
          await Supabase.initialize(
            url: supabaseUrl,
            anonKey: supabaseKey,
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('BackgroundLocationService: Supabase init error - $e');
      }
    }

    final supabase = Supabase.instance.client;

    // Configure location settings for background
    await location.changeSettings(
      accuracy: LocationAccuracy.high,
      interval: 10000, // 10 seconds
      distanceFilter: 10, // 10 meters minimum distance
    );

    // Enable background mode
    await location.enableBackgroundMode(enable: true);

    // Start listening to location updates
    locationSubscription = location.onLocationChanged.listen(
      (LocationData currentLocation) async {
        if (currentLocation.latitude == null ||
            currentLocation.longitude == null) {
          return;
        }

        try {
          // Update notification with current location
          if (service is AndroidServiceInstance) {
            if (await service.isForegroundService()) {
              service.setForegroundNotificationInfo(
                title: 'Pasada Driver - Location Active',
                content:
                    'Lat: ${currentLocation.latitude?.toStringAsFixed(4)}, '
                    'Lng: ${currentLocation.longitude?.toStringAsFixed(4)}',
              );
            }
          }

          // Update location in database
          final wktPoint =
              'POINT(${currentLocation.longitude} ${currentLocation.latitude})';

          await supabase
              .from('driverTable')
              .update({'current_location': wktPoint}).eq('driver_id', driverId);

          if (kDebugMode) {
            debugPrint(
                'BackgroundLocationService: Location updated - ${currentLocation.latitude}, ${currentLocation.longitude}');
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint(
                'BackgroundLocationService: Error updating location - $e');
          }
        }
      },
      onError: (error) {
        if (kDebugMode) {
          debugPrint('BackgroundLocationService: Location error - $error');
        }
      },
    );

    // Keep the service running
    keepAliveTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (service is AndroidServiceInstance) {
        if (await service.isForegroundService()) {
          // Service is still running
        }
      }

      // Check if service should stop
      final shouldStop = prefs.getBool('stop_background_location') ?? false;
      if (shouldStop) {
        await prefs.setBool('stop_background_location', false);
        timer.cancel();
        await locationSubscription?.cancel();

        // Disable background mode
        try {
          await location.enableBackgroundMode(enable: false);
        } catch (e) {
          if (kDebugMode) {
            debugPrint(
                'BackgroundLocationService: Error disabling background mode - $e');
          }
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

  /// Save Supabase credentials for background service
  static Future<void> saveCredentials(
    String driverId,
    String supabaseUrl,
    String supabaseKey,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('driver_id', driverId);
    await prefs.setString('supabase_url', supabaseUrl);
    await prefs.setString('supabase_key', supabaseKey);
  }
}
