import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:pasada_driver_side/Database/AuthService.dart';
import 'package:pasada_driver_side/Database/driver_provider.dart';
import 'package:pasada_driver_side/Database/map_provider.dart';
import 'package:pasada_driver_side/Database/passenger_provider.dart';
import 'package:pasada_driver_side/NavigationPages/main_page.dart';
import 'package:pasada_driver_side/Services/permissions.dart';
import 'package:pasada_driver_side/UI/message.dart';
import 'package:pasada_driver_side/UI/text_styles.dart';
import 'package:pasada_driver_side/login.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:pasada_driver_side/UI/constants.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");

    await Supabase.initialize(
        anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
        url: dotenv.env['SUPABASE_URL']!);

    final driverProvider = DriverProvider();
    final mapProvider = MapProvider();
    final passengerProvider = PassengerProvider();

    CheckPermissions()
        .checkPermissions(); //check permissions for location services

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
    // runApp(ErrorApp(error: e.toString()));
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
        await context
            .read<DriverProvider>()
            .loadFromSecureStorage(context); //load data from secure storage

        // Move PassengerProvider interaction to post-frame callback
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            context.read<PassengerProvider>().getBookingRequestsID(
                context); //check booking assigned to the driver
          }
        });

        debugPrint('Fetching route coordinates');
        // Move MapProvider interaction outside of build cycle
        WidgetsBinding.instance.addPostFrameCallback((_) {
          context.read<MapProvider>().getRouteCoordinates(
              context.read<DriverProvider>().routeID); //get route coordinates
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Pasada Driver',
      theme: ThemeData(
        scaffoldBackgroundColor: const Color.fromRGBO(250, 250, 250, 20),
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
    _pageController.addListener(() {
      _pageNotifier.value = _pageController.page ?? 0;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Pre-cache image for smoother performance
    precacheImage(const AssetImage('assets/png/PasadaLogo.png'), context);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _pageNotifier.dispose();
    super.dispose();
  }

  void goToLoginPage() {
    _pageController.animateToPage(1,
        duration: const Duration(milliseconds: 400),
        curve: Curves.fastOutSlowIn);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: _pageNotifier,
      builder: (context, pageValue, _) {
        // Calculate transition value (0 to 1)
        final transitionValue = pageValue.clamp(0.0, 1.0);

        return Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [
              // Background - use a simple color instead of animated container for better performance
              Container(
                color: const Color.fromRGBO(250, 250, 250, 1),
              ),

              // Logo with morphing animation - optimized
              AnimatedBuilder(
                animation: _pageNotifier,
                builder: (context, child) {
                  return OptimizedMorphingLogo(
                      transitionValue: transitionValue);
                },
              ),

              // Pages with hardware acceleration
              RepaintBoundary(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: 2,
                  physics: const PageScrollPhysics(),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return OptimizedWelcomePage(
                        onLoginPressed: goToLoginPage,
                        transitionValue: transitionValue,
                      );
                    } else {
                      return LogIn(pageController: _pageController);
                    }
                  },
                ),
              ),

              // Page indicators
              Positioned(
                bottom: 20,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildPageIndicator(0, pageValue.round()),
                    const SizedBox(width: 10),
                    _buildPageIndicator(1, pageValue.round()),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPageIndicator(int pageIndex, int currentPage) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: currentPage == pageIndex ? 12 : 8,
      height: currentPage == pageIndex ? 12 : 8,
      decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: currentPage == pageIndex ? Colors.black : Colors.grey),
    );
  }
}

class OptimizedMorphingLogo extends StatelessWidget {
  final double transitionValue;

  const OptimizedMorphingLogo({super.key, required this.transitionValue});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Welcome page logo position (center top)
    final startPosX = screenWidth * 0.5 - (screenWidth * 0.2);
    final startPosY = screenHeight * 0.2;
    final startSize = screenWidth * 0.4;

    // Login page logo position (top left)
    final endPosX = screenWidth * 0.1;
    final endPosY = screenHeight * 0.05;
    final endSize = screenWidth * 0.15;

    // Calculate current position and size
    final currentPosX = lerpDouble(startPosX, endPosX, transitionValue);
    final currentPosY = lerpDouble(startPosY, endPosY, transitionValue);
    final currentSize = lerpDouble(startSize, endSize, transitionValue);

    return Positioned(
      left: currentPosX,
      top: currentPosY,
      width: currentSize,
      height: currentSize,
      child: RepaintBoundary(
        child: Image.asset(
          'assets/png/PasadaLogo.png',
          color: Colors.black,
        ),
      ),
    );
  }

  double lerpDouble(double a, double b, double t) {
    return a + (b - a) * t;
  }
}

class OptimizedWelcomePage extends StatelessWidget {
  final VoidCallback onLoginPressed;
  final double transitionValue;

  const OptimizedWelcomePage({
    super.key,
    required this.onLoginPressed,
    required this.transitionValue,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate opacity to avoid layered transparency which causes performance issues
    final opacity = (1 - transitionValue).clamp(0.0, 1.0);
    if (opacity < 0.01) return const SizedBox.shrink();

    // Use transforms instead of animations for better performance
    return Transform.translate(
      offset: Offset(0, transitionValue * 20),
      child: Opacity(
        opacity: opacity,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Empty container to take up the logo's space
              SizedBox(height: Constants(context).screenWidth * 0.4),

              // Welcome message
              const WelcomeMessage(),

              // Login button
              Transform.translate(
                offset: Offset(0, transitionValue * 20),
                child: _LogInButton(onPressed: onLoginPressed),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WelcomeMessage extends StatelessWidget {
  const WelcomeMessage({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: Constants(context).screenHeight * 0.15),
      child: Column(
        children: [
          Text(
            'Hi there!',
            style: Styles().textStyle(40.0, FontWeight.w700, Colors.black),
          ),
          SizedBox(height: Constants(context).screenHeight * 0.009),
          Text(
            'Welcome to Pasada Driver',
            style: Styles().textStyle(14, FontWeight.w400, Styles.customBlack),
          ),
        ],
      ),
    );
  }
}

class _LogInButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const _LogInButton({this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: Constants(context).screenHeight * 0.1),
      child: ElevatedButton(
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
      ),
    );
  }
}
