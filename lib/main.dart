import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
            .loadFromSecureStorage(); //load data from secure storage
        await context.read<PassengerProvider>().getBookingRequestsID(
            context); //check booking assigned to the driver

        await context.read<MapProvider>().getRouteCoordinates(
            context.read<DriverProvider>().routeID); //get route coordinates

        // await mapProvider.getPassenger(int.parse(driverProvider.driverID)); bug here, commented for now
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
        '/home': (context) => const MyHomePage(),
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
      return const MyHomePage();
    }
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            //LOGO
            Logo(),
            //WELCOME MESSAGE
            WelcomeMessage(),
            SizedBox(height: 8.0),
            WelcomeAppMessage(),

            //LOG IN BUTTON
            _LogInButton(),
          ],
        ),
      ),
    );
  }
}

class Logo extends StatelessWidget {
  const Logo({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 130.0),
      width: 130.0,
      height: 130.0,
      child: SvgPicture.asset('assets/svg/Ellipse.svg'),
    );
  }
}

class WelcomeAppMessage extends StatelessWidget {
  const WelcomeAppMessage({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 30.0),
      child: Text(
        'Welcome to Pasada Driver',
        style: Styles().textStyle(14, FontWeight.w400, Styles.customBlack),
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
      margin: const EdgeInsets.only(top: 70.0),
      child: Text(
        'Hi there!',
        style: Styles().textStyle(40.0, FontWeight.w700, Colors.black),
      ),
    );
  }
}

class _LogInButton extends StatelessWidget {
  const _LogInButton();
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 250.0),
      child: ElevatedButton(
        onPressed: () {
          Navigator.pushReplacementNamed(context, '/login');
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color.fromARGB(255, 0, 0, 0),
          minimumSize: const Size(240.0, 45.0),
          shadowColor: Colors.black,
          elevation: 5.0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
        ),
        child: Text(
          'Log in',
          style: Styles().textStyle(20.0, FontWeight.w600, Styles.customWhite),
        ),
      ),
    );
  }
}
