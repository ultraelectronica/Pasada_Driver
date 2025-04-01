import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pasada_driver_side/Database/AuthService.dart';
import 'package:pasada_driver_side/Database/driver_provider.dart';
import 'package:pasada_driver_side/Database/map_provider.dart';
import 'package:pasada_driver_side/NavigationPages/home_page.dart';
import 'package:pasada_driver_side/UI/text_styles.dart';
import 'package:pasada_driver_side/login.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
      anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
      url: dotenv.env['SUPABASE_URL']!);

  final session = await Authservice.getSession();
  final bool isLoggedIn = session['session_token'] != null;

  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => DriverProvider()),
      ChangeNotifierProvider(create: (_) => MapProvider()),
    ],
    child: MyApp(isLoggedIn: isLoggedIn),
  ));
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;

  const MyApp({super.key, required this.isLoggedIn});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Pasada Driver',
      theme: ThemeData(
        scaffoldBackgroundColor: const Color.fromRGBO(250, 250, 250, 20),
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: isLoggedIn
          ? const HomeScreen()
          : const MyHomePage(title: 'Pasada Driver'),
      routes: {
        '/login': (context) => const LogIn(),
        '/home': (context) => const HomeScreen(),
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

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
            SizedBox(height: 8),
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
      margin: const EdgeInsets.only(top: 130),
      width: 130,
      height: 130,
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
    return const Padding(
      padding: EdgeInsets.only(bottom: 30),
      child: Text(
        'Welcome to Pasada Driver',
        style: TextStyle(
          fontFamily: 'Inter',
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
      margin: const EdgeInsets.only(top: 70),
      child: const Text(
        'Hi there!',
        style: TextStyle(
          fontSize: 40,
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _LogInButton extends StatelessWidget {
  const _LogInButton();
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 250),
      child: ElevatedButton(
        onPressed: () {
          Navigator.pushReplacementNamed(context, '/login');
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color.fromARGB(255, 0, 0, 0),
          minimumSize: const Size(240, 45),
          shadowColor: Colors.black,
          elevation: 5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: Text(
          'Log in',
          style: Styles().textStyle(20, FontWeight.w600, Styles.customWhite),
        ),
      ),
    );
  }
}