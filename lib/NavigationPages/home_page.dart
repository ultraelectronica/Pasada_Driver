// ignore_for_file: non_constant_identifier_names, constant_identifier_names

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pasada_driver_side/Database/passenger_capacity.dart';
import 'package:pasada_driver_side/Database/passenger_provider.dart';
import 'package:pasada_driver_side/Map/google_map.dart';
import 'package:pasada_driver_side/Database/driver_provider.dart';
import 'package:pasada_driver_side/UI/text_styles.dart';
import 'package:provider/provider.dart';

void main() => runApp(const HomeScreen());

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pasada',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF2F2F2),
        fontFamily: 'Inter',
        useMaterial3: true,
      ),
      home: const HomePage(title: 'Pasada'),
      routes: <String, WidgetBuilder>{
        'map': (BuildContext context) => const MapScreen(),
      },
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.title});
  final String title;

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  late GoogleMapController mapController;
  // LocationData? _currentLocation;
  // late Location _location;

  //used to access MapScreenState
  final GlobalKey<MapScreenState> mapScreenKey = GlobalKey<MapScreenState>();

  final GlobalKey containerKey = GlobalKey();
  double containerHeight = 0;

  Future<void> getPassengerCapacity() async {
    // get the passenger capacity from the DB
    // await context.read<DriverProvider>().getPassengerCapacity();
    await PassengerCapacity().getPassengerCapacityToDB(context);
    // _showToast('Vehicle capacity: $Capacity');
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final driverProvider = context.watch<DriverProvider>();

    return Scaffold(
      body: SizedBox(
        child: Stack(
          children: [
            // Update the MapScreen widget in the HomePage's build method
            MapScreen(
              key: mapScreenKey,
              // initialLocation: StartingLocation,
              // finalLocation: EndingLocation,
            ),

            // FLOATING MESSAGE BUTTON
            FloatingMessageButton(screenHeight: screenHeight, screenWidth: screenWidth),

            // PASSENGER CAPACITY
            FloatingPassengerCapacity(
                screenHeight: screenHeight,
                screenWidth: screenWidth,
                Provider: driverProvider,
                passengerCapacity: PassengerCapacity()),
          ],
        ),
      ),
    );
  }
}

class FloatingMessageButton extends StatelessWidget {
  const FloatingMessageButton({
    super.key,
    required this.screenHeight,
    required this.screenWidth,
  });

  final double screenHeight;
  final double screenWidth;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: screenHeight * 0.1,
      right: screenWidth * 0.05,
      child: SizedBox(
        width: 50,
        height: 50,
        child: FloatingActionButton(
          heroTag: null,
          onPressed: () {
            PassengerProvider().getBookingRequestsID(context);
          },
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          child: SvgPicture.asset(
            'assets/svg/message.svg',
            height: 20,
            width: 20,
          ),
        ),
      ),
    );
  }
}

class FloatingPassengerCapacity extends StatelessWidget {
  const FloatingPassengerCapacity(
      {super.key,
      required this.screenHeight,
      required this.screenWidth,
      required this.Provider,
      required this.passengerCapacity});

  final double screenHeight;
  final double screenWidth;
  final DriverProvider Provider;
  final PassengerCapacity passengerCapacity;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: screenHeight * 0.175,
      right: screenWidth * 0.05,
      child: SizedBox(
        width: 50,
        height: 50,
        child: FloatingActionButton(
          heroTag: null,
          onPressed: () {
            passengerCapacity.getPassengerCapacityToDB(context);
          },
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          child: Text(
            Provider.passengerCapacity.toString(),
            style: Styles().textStyle(22, Styles.w600Weight, Styles.customBlack),
          ),
        ),
      ),
    );
  }
}
