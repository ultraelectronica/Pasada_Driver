import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pasada_driver_side/Database/driver_provider.dart';
import 'package:pasada_driver_side/login.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im90YndoaXR3cm1uZnFncG1uanZmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzMzOTk5MzQsImV4cCI6MjA0ODk3NTkzNH0.f8JOv0YvKPQy8GWYGIdXfkIrKcqw0733QY36wJjG1Fw',
      url: 'https://otbwhitwrmnfqgpmnjvf.supabase.co');

  await dotenv.load(fileName: ".env");

  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => DriverProvider()),
    ],
    child: const MyApp(),
  )
      // ChangeNotifierProvider(
      //   create: (context) => DriverProvider(),
      //   child: const MyApp(),
      // ),
      );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
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
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const LogIn()),
          );
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
        child: const Text(
          'Log in',
          style: TextStyle(
            color: Color(0xFFF2F2F2),
            fontWeight: FontWeight.w600,
            fontSize: 20,
            fontFamily: 'Inter',
          ),
        ),
      ),
    );
  }
}
