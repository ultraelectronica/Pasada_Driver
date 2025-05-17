import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:pasada_driver_side/Database/auth_service.dart';
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
    _precacheAssets();
  }

  void _precacheAssets() {
    // Pre-cache common assets at app startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      precacheImage(const AssetImage('assets/png/PasadaLogo.png'), context);
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
