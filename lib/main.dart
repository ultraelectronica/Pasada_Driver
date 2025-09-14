import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pasada_driver_side/bootstrap/initialize_app.dart';
import 'package:pasada_driver_side/presentation/providers/app_providers.dart';
import 'package:pasada_driver_side/presentation/pages/start/auth_gate.dart';
import 'package:pasada_driver_side/bootstrap/app_bootstrap_error_screen.dart';
import 'package:pasada_driver_side/presentation/pages/login/login_page.dart';
import 'package:pasada_driver_side/presentation/pages/start/widgets/optimized_welcome_page.dart';
import 'package:pasada_driver_side/presentation/pages/start/utils/start_constants.dart';
import 'package:pasada_driver_side/common/constants/constants.dart';
import 'package:pasada_driver_side/presentation/routes/app_routes.dart';
import 'package:pasada_driver_side/common/logging.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

// Future for assets preloading
late final Future<List<AssetImage>> _preloadedAssets;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _precacheAssets();
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
                    ? OptimizedWelcomePage(onLoginPressed: goToLoginPage)
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
          color: isActive ? Colors.black : Colors.grey),
    );
  }
}
