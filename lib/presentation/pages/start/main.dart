import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:pasada_driver_side/Services/auth_service.dart';
import 'package:pasada_driver_side/presentation/providers/driver/driver_provider.dart';
import 'package:pasada_driver_side/presentation/providers/map_provider.dart';
import 'package:pasada_driver_side/presentation/providers/passenger/passenger_provider.dart';
import 'package:pasada_driver_side/presentation/pages/main/main_page.dart';
import 'package:pasada_driver_side/Services/permissions.dart';
import 'package:pasada_driver_side/UI/message.dart';
import 'package:pasada_driver_side/UI/text_styles.dart';
import 'package:pasada_driver_side/presentation/pages/login/login_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:pasada_driver_side/UI/constants.dart';

// Future for assets preloading
late final Future<List<AssetImage>> _preloadedAssets;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set portrait orientation only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize preloaded assets
  _preloadedAssets = _preloadAssets();

  try {
    // Load environment variables
    await dotenv.load(fileName: ".env");

    // Initialize Supabase with timeout handling
    await _initializeSupabase();

    // Initialize providers
    final driverProvider = DriverProvider();
    final mapProvider = MapProvider();
    final passengerProvider = PassengerProvider();

    // Check permissions for location services
    await CheckPermissions().checkPermissions();

    // Run the app with all providers initialized
    runApp(MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => driverProvider),
        ChangeNotifierProvider(create: (_) => mapProvider),
        ChangeNotifierProvider(create: (_) => passengerProvider),
      ],
      child: const MyApp(),
    ));
  } catch (e, stacktrace) {
    if (kDebugMode) {
      print('Error during initialization: $e');
      print(stacktrace);
    }
    // Run error app with useful error information
    runApp(ErrorApp(error: e.toString(), stackTrace: stacktrace.toString()));
  }
}

// Separate function to initialize Supabase with timeout handling
Future<void> _initializeSupabase() async {
  try {
    // Add timeout to prevent hanging if Supabase servers are unresponsive
    await Supabase.initialize(
      anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
      url: dotenv.env['SUPABASE_URL']!,
    ).timeout(
      const Duration(seconds: 10),
      onTimeout: () =>
          throw TimeoutException('Supabase initialization timed out'),
    );
  } catch (e) {
    if (kDebugMode) {
      print('Supabase initialization error: $e');
    }
    rethrow; // Let the main error handler manage this
  }
}

// Function to preload assets for faster app startup
Future<List<AssetImage>> _preloadAssets() async {
  final List<AssetImage> preloadedAssets = [
    const AssetImage('assets/png/PasadaLogo.png'),
    // Add any other commonly used assets here
  ];

  // Just instantiate the images - actual precaching will happen when MyApp builds
  return preloadedAssets;
}

// Error screen for displaying initialization errors
class ErrorApp extends StatelessWidget {
  final String error;
  final String stackTrace;

  const ErrorApp({
    super.key,
    required this.error,
    this.stackTrace = '',
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Pasada Driver - Error',
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        primaryColor: Colors.red,
        useMaterial3: true,
      ),
      home: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.red,
          title: const Text('Initialization Error',
              style: TextStyle(color: Colors.white)),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'The app encountered an error during startup:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(error, style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 24),
              if (kDebugMode) ...[
                const Text(
                  'Stack Trace:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.grey[200],
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Text(stackTrace,
                        style: const TextStyle(fontFamily: 'monospace')),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Center(
                child: ElevatedButton(
                  onPressed: () {
                    // Restart app
                    main();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Retry'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool? _hasSession;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkSession();
    _precacheAssets();
  }

  // Properly precache assets with a valid BuildContext
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

  //check yung data locally
  Future<bool> _hasValidSession() async {
    final sessionData = await AuthService.getSession();
    return sessionData.isNotEmpty;
  }

  Future<void> _checkSession() async {
    final hasSession = await _hasValidSession();
    if (mounted) {
      setState(() {
        _hasSession = hasSession;
        _isLoading = false;
      });
      if (!hasSession && kDebugMode) {
        ShowMessage().showToast('No local session data detected');
        if (kDebugMode) {
          print('No local session data detected');
        }
      }

      // User is still logged in
      if (hasSession) {
        await _loadUserData();
      }
    }
  }

  // Separated user data loading for better error handling
  Future<void> _loadUserData() async {
    try {
      // Load driver data from secure storage
      await context.read<DriverProvider>().loadFromSecureStorage(context);

      // Move processing to post-frame callback
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;

        final driverProvider = context.read<DriverProvider>();
        final mapProvider = context.read<MapProvider>();
        final passengerProvider = context.read<PassengerProvider>();

        // Ensure route data is loaded, first check if route ID is valid
        if (driverProvider.routeID > 0) {
          if (kDebugMode) {
            debugPrint(
                'Fetching route coordinates for route: ${driverProvider.routeID}');
          }

          // Fetch route data from the database and coordinates
          await mapProvider.getRouteCoordinates(driverProvider.routeID);

          // Set route ID in MapProvider to match
          mapProvider.setRouteID(driverProvider.routeID);

          // Now fetch passenger pickup locations AFTER route data is loaded
          // This is important because the passenger validation requires route data
          await passengerProvider.getBookingRequestsID(context);
        } else {
          if (kDebugMode) {
            debugPrint('No valid route ID found: ${driverProvider.routeID}');
          }
        }
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error loading user data: $e');
      }
      // Don't reset session here as it could be a temporary network issue
      // Just show an error message
      ShowMessage().showToast('Error loading data. Please restart the app.');
    }
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
      home: _buildHome(),
      routes: {
        '/login': (context) => const LogIn(),
      },
    );
  }

  Widget _buildHome() {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (_hasSession == true) {
      return const MainPage();
    } else {
      return const AuthPagesView();
    }
  }
}

class AuthPagesView extends StatefulWidget {
  const AuthPagesView({super.key});

  @override
  State<AuthPagesView> createState() => _AuthPagesViewState();
}

class _AuthPagesViewState extends State<AuthPagesView>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  final ValueNotifier<double> _pageNotifier = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: 0,
      viewportFraction: 1.0,
    );
    _pageController.addListener(_onPageChanged);
  }

  void _onPageChanged() {
    if (_pageController.page != null &&
        _pageController.page != _pageNotifier.value) {
      // Only update when necessary to reduce rebuilds
      _pageNotifier.value = _pageController.page!;
    }
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageChanged);
    _pageController.dispose();
    _pageNotifier.dispose();
    super.dispose();
  }

  void goToLoginPage() {
    _pageController.animateToPage(1,
        duration: const Duration(milliseconds: 400), // Reduced animation time
        curve: Curves.easeInOutExpo); // Simpler curve
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // White background - use const when possible
          const ColoredBox(color: Colors.white),

          // Pages with hardware acceleration
          PageView.builder(
            controller: _pageController,
            itemCount: 2,
            physics: const ClampingScrollPhysics(), // Less resource intensive
            itemBuilder: (context, index) {
              return RepaintBoundary(
                child: index == 0
                    ? OptimizedWelcomePage(
                        onLoginPressed: goToLoginPage,
                      )
                    : LogIn(pageController: _pageController),
              );
            },
          ),

          // Page indicators
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.only(
                  bottom: Constants(context).screenHeight * 0.05),
              child: ValueListenableBuilder<double>(
                valueListenable: _pageNotifier,
                builder: (context, pageValue, _) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildPageIndicator(0, pageValue.round()),
                      const SizedBox(width: 10),
                      _buildPageIndicator(1, pageValue.round()),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndicator(int pageIndex, int currentPage) {
    final isActive = currentPage == pageIndex;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200), // Shorter animation
      width: isActive ? 22 : 8,
      height: isActive ? 12 : 8,
      decoration: BoxDecoration(
          shape: BoxShape.rectangle,
          borderRadius: BorderRadius.circular(5),
          color: isActive ? Colors.black : Colors.grey),
    );
  }
}

class OptimizedWelcomePage extends StatelessWidget {
  final VoidCallback onLoginPressed;

  const OptimizedWelcomePage({
    super.key,
    required this.onLoginPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Static positioned logo
        Padding(
          padding: EdgeInsets.only(top: Constants(context).screenHeight * 0.15),
          child: Center(
            child: SizedBox(
              width: Constants(context).screenWidth * 0.4,
              height: Constants(context).screenWidth * 0.4,
              child: Image.asset(
                'assets/png/PasadaLogo.png',
                color: Colors.black,
              ),
            ),
          ),
        ),

        // Welcome message
        const WelcomeMessage(),

        // next button
        Padding(
          padding: EdgeInsets.only(
              bottom: Constants(context).screenHeight * 0.1,
              top: Constants(context).screenHeight * 0.1),
          child: _NextButton(onPressed: onLoginPressed),
        ),
      ],
    );
  }
}

class WelcomeMessage extends StatelessWidget {
  const WelcomeMessage({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min, // Reduces layout calculation
      children: [
        Text(
          'Hi there!',
          style: Styles().textStyle(40.0, FontWeight.w700, Colors.black),
        ),
        Text(
          'Welcome to Pasada Driver',
          style: Styles().textStyle(15, FontWeight.w500, Styles.customBlack),
        ),
      ],
    );
  }
}

class _NextButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const _NextButton({this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed ??
          () {
            Navigator.pushReplacementNamed(context, '/login');
          },
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color.fromARGB(255, 0, 0, 0),
        minimumSize: Size(Constants(context).screenWidth * 0.1,
            Constants(context).screenHeight * 0.05),
        shadowColor: Colors.black,
        elevation: 5.0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.0),
        ),
      ),
      child: const Icon(
        Icons.arrow_forward_ios_rounded,
        color: Colors.white,
        size: 20.0,
      ),
    );
  }
}
