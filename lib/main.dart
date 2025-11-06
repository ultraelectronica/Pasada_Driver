import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:pasada_driver_side/bootstrap/initialize_app.dart';
import 'package:pasada_driver_side/presentation/providers/app_providers.dart';
import 'package:pasada_driver_side/presentation/providers/driver/driver_provider.dart';
import 'package:pasada_driver_side/presentation/pages/start/auth_gate.dart';
import 'package:pasada_driver_side/bootstrap/app_bootstrap_error_screen.dart';
import 'package:pasada_driver_side/presentation/pages/login/login_page.dart';
import 'package:pasada_driver_side/presentation/pages/start/widgets/welcome_page.dart';
import 'package:pasada_driver_side/presentation/pages/start/utils/start_constants.dart';
import 'package:pasada_driver_side/common/constants/constants.dart';
import 'package:pasada_driver_side/presentation/routes/app_routes.dart';
import 'package:pasada_driver_side/common/logging.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:pasada_driver_side/Services/notification_service.dart';
import 'package:pasada_driver_side/domain/services/background_location_service.dart';

// Future for assets preloading
late final Future<List<AssetImage>> _preloadedAssets;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase and register FCM background handler before runApp
  await NotificationService.ensureFirebaseInitialized();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Enable always-on display
  WakelockPlus.enable();

  // Set portrait orientation only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  try {
    // Run global initialization (env, Supabase, permissions) and capture assets
    _preloadedAssets = initializeApp();

    // Wait for critical initialization to finish before proceeding
    await _preloadedAssets;

    // Initialize notifications (permissions, token, listeners)
    await NotificationService.instance.initialize();

    //TODO: check this part later.
    //Show test notification on app start (development only)
    // if (kDebugMode) {
    //   await NotificationService.instance.showTestNotification();
    // }

    // Boot the widget tree with providers wired up
    runApp(const AppProviders(child: MyApp()));
  } catch (e, stacktrace) {
    if (kDebugMode) {
      logDebug('Error during initialization: $e\n$stacktrace');
    }
    // Show a dedicated bootstrap error screen and offer retry
    runApp(AppBootstrapErrorScreen(
      error: e.toString(),
      stackTrace: stacktrace.toString(),
      onRetry: () {
        main();
      },
    ));
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  Timer? _backgroundTimer;
  Timer? _periodicTimer;
  DateTime? _backgroundStartTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _precacheAssets();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _backgroundTimer?.cancel();
    _periodicTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (kDebugMode) {
      logDebug('[Lifecycle] App state changed to: $state');
    }

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        // App went to background or recent apps
        _startBackgroundTimer();
        break;
      case AppLifecycleState.resumed:
        // App came back to foreground
        _cancelBackgroundTimer();
        break;
      case AppLifecycleState.detached:
      case AppLifecycleState.inactive:
        // No action needed for these states
        break;
    }
  }

  void _startBackgroundTimer() async {
    // Cancel any existing timers
    _backgroundTimer?.cancel();
    _periodicTimer?.cancel();

    if (kDebugMode) {
      logDebug('[Lifecycle][Timer] Starting background timers');
    }

    // Ensure the background service is running when going to background
    final isRunning = BackgroundLocationService.instance.isRunning;
    if (!isRunning) {
      if (kDebugMode) {
        logDebug(
            '[Lifecycle][Timer] Background service not running - starting it');
      }
      try {
        await BackgroundLocationService.instance.start();
        if (kDebugMode) {
          logDebug(
              '[Lifecycle][Timer] Background service started successfully');
        }
      } catch (e) {
        if (kDebugMode) {
          logDebug('[Lifecycle][Timer] Failed to start background service: $e');
        }
      }
    }

    final driverProvider = context.read<DriverProvider>();

    _backgroundStartTime = DateTime.now();

    // Periodic timer to check elapsed time every minute
    _periodicTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (_backgroundStartTime != null) {
        final elapsed = DateTime.now().difference(_backgroundStartTime!);
        if (kDebugMode) {
          logDebug('[Lifecycle][Timer] Background time elapsed: $elapsed');
        }

        // You can add specific checks here
        if (elapsed >= const Duration(minutes: 1) &&
            elapsed < const Duration(minutes: 2)) {
          logDebug('[Lifecycle][Timer] Just passed 1 minute mark');
        }
        if (elapsed >= const Duration(minutes: 5) &&
            elapsed < const Duration(minutes: 6)) {
          logDebug('[Lifecycle][Timer] Just passed 5 minute mark');
        }
      }
    });

    // Timer to stop service after 10 minutes
    _backgroundTimer = Timer(const Duration(minutes: 10), () async {
      // Set driver status to offline after 10 minutes of inactivity
      driverProvider.setLastDriverStatus(driverProvider.driverStatus);
      driverProvider.updateStatusToDB('Offline');
      driverProvider.setDriverStatus('Offline');

      _periodicTimer?.cancel();

      if (kDebugMode) {
        logDebug(
            '[Lifecycle][Timer] 10 minutes in background - stopping foreground service');
      }

      // Stop the background service after 10 minutes of inactivity
      await BackgroundLocationService.instance.stop();

      if (kDebugMode) {
        logDebug(
            '[Lifecycle][Timer] Foreground service stopped due to inactivity');
      }

      _backgroundStartTime = null;
    });
  }

  void _cancelBackgroundTimer() {
    if (_backgroundTimer != null && _backgroundTimer!.isActive) {
      if (kDebugMode) {
        final elapsed = _backgroundStartTime != null
            ? DateTime.now().difference(_backgroundStartTime!)
            : Duration.zero;
        logDebug(
            '[Lifecycle] Cancelling background timer - app returned to foreground after $elapsed');
      }
      _backgroundTimer?.cancel();
      _periodicTimer?.cancel();
      _backgroundTimer = null;
      _periodicTimer = null;
      _backgroundStartTime = null;
    } else if (_backgroundTimer != null && !_backgroundTimer!.isActive) {
      // Timer already fired, meaning service was stopped
      // Restart the service if it's not running
      _restartServiceIfNeeded();
    }
  }

  Future<void> _restartServiceIfNeeded() async {
    final isRunning = BackgroundLocationService.instance.isRunning;

    if (!isRunning) {
      if (kDebugMode) {
        logDebug(
            '[Lifecycle] Service was stopped due to inactivity - restarting');
      }

      try {
        await BackgroundLocationService.instance.start();
        if (kDebugMode) {
          logDebug('[Lifecycle] Foreground service restarted');
        }
      } catch (e) {
        if (kDebugMode) {
          logDebug('[Lifecycle] Failed to restart service: $e');
        }
      }
    }

    // Reset the timer
    _backgroundTimer = null;
  }

  void _precacheAssets() {
    // Wait until the first frame is built so we have a valid context
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        // Await the Future to get the actual List<AssetImage>
        final assets = await _preloadedAssets;
        for (final asset in assets) {
          precacheImage(asset, context);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Pasada Driver',
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.white),
        useMaterial3: true,
      ),
      home: const AuthGate(),
      routes: {
        AppRoute.login.path: (context) => const LogIn(),
      },
    );
  }
}

class AuthPagesView extends StatefulWidget {
  const AuthPagesView({super.key});

  @override
  State<AuthPagesView> createState() => _AuthPagesViewState();
}

class _AuthPagesViewState extends State<AuthPagesView> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void goToLoginPage() {
    _pageController.animateToPage(1,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutExpo);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Colors.white),

          PageView.builder(
            controller: _pageController,
            itemCount: 2,
            physics: const ClampingScrollPhysics(),
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) {
              return RepaintBoundary(
                child: index == 0
                    ? WelcomePage(onLoginPressed: goToLoginPage)
                    : LogIn(pageController: _pageController),
              );
            },
          ),

          // Page indicators
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.only(
                  bottom: Constants(context).screenHeight *
                      StartConstants.pageIndicatorBottomFraction),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildPageIndicator(0),
                  const SizedBox(width: 10),
                  _buildPageIndicator(1),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndicator(int pageIndex) {
    final isActive = _currentPage == pageIndex;
    return AnimatedContainer(
      duration: StartConstants.indicatorAnimDuration,
      width: isActive
          ? StartConstants.indicatorActiveWidth
          : StartConstants.indicatorInactiveSize,
      height: isActive
          ? StartConstants.indicatorActiveHeight
          : StartConstants.indicatorInactiveSize,
      decoration: BoxDecoration(
          shape: BoxShape.rectangle,
          borderRadius: BorderRadius.circular(5),
          color: isActive ? Colors.white : Colors.grey.shade300),
    );
  }
}
