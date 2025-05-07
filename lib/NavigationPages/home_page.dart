// ignore_for_file: non_constant_identifier_names, constant_identifier_names

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pasada_driver_side/Database/passenger_capacity.dart';
import 'package:pasada_driver_side/Database/passenger_provider.dart';
import 'package:pasada_driver_side/Map/google_map.dart';
import 'package:pasada_driver_side/Database/driver_provider.dart';
import 'package:pasada_driver_side/UI/constants.dart';
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
            FloatingCapacity(
              Provider: driverProvider,
              passengerCapacity: PassengerCapacity(),
              screenHeight: screenHeight,
              screenWidth: screenWidth,
              bottomPosition: screenHeight * 0.1,
              rightPosition: screenWidth * 0.05,
              icon: 'assets/svg/people.svg',
              text: driverProvider.passengerCapacity.toString(),
              onTap: () {
                PassengerCapacity().getPassengerCapacityToDB(context);
              },
            ),

            // PASSENGER STANDING CAPACITY
            FloatingCapacity(
              Provider: driverProvider,
              passengerCapacity: PassengerCapacity(),
              screenHeight: screenHeight,
              screenWidth: screenWidth,
              bottomPosition: screenHeight * 0.175,
              rightPosition: screenWidth * 0.05,
              icon: 'assets/svg/standing.svg',
              text: driverProvider.passengerStandingCapacity.toString(),
              onTap: () {
                PassengerCapacity().getPassengerCapacityToDB(context);
              },
            ),

            // PASSENGER SITTING CAPACITY
            FloatingCapacity(
              Provider: driverProvider,
              passengerCapacity: PassengerCapacity(),
              screenHeight: screenHeight,
              screenWidth: screenWidth,
              bottomPosition: screenHeight * 0.25,
              rightPosition: screenWidth * 0.05,
              icon: 'assets/svg/sitting.svg',
              text: driverProvider.passengerSittingCapacity.toString(),
              onTap: () {
                PassengerCapacity().getPassengerCapacityToDB(context);
              },
            ),
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
      bottom: screenHeight * 0.025,
      left: screenWidth * 0.05,
      child: SizedBox(
        width: 50,
        height: 50,
        child: Material(
          color: Colors.white,
          elevation: 4,
          borderRadius: BorderRadius.circular(15),
          child: InkWell(
            onTap: () {
              PassengerProvider().getBookingRequestsID(context);
            },
            borderRadius: BorderRadius.circular(15),
            splashColor: Colors.blue.withAlpha(77), // ~0.3 opacity
            highlightColor: Colors.blue.withAlpha(26), // ~0.1 opacity
            child: Center(
              child: SvgPicture.asset(
                'assets/svg/message.svg',
                height: 20,
                width: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class FloatingCapacity extends StatelessWidget {
  const FloatingCapacity(
      {super.key,
      required this.screenHeight,
      required this.screenWidth,
      required this.bottomPosition,
      required this.rightPosition,
      required this.Provider,
      required this.passengerCapacity,
      required this.icon,
      required this.text,
      required this.onTap});

  final double screenHeight;
  final double screenWidth;
  final double bottomPosition;
  final double rightPosition;
  final DriverProvider Provider;
  final PassengerCapacity passengerCapacity;
  final String icon;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: bottomPosition, //screenHeight * 0.25
      right: rightPosition, //screenWidth * 0.05
      child: Material(
        color: Colors.white,
        elevation: 4,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          splashColor: Constants.GREEN_COLOR.withAlpha(77), // ~0.3 opacity
          highlightColor: Constants.GREEN_COLOR.withAlpha(26), // ~0.1 opacity
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Constants.GREEN_COLOR, width: 2),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset(
                  icon,
                  colorFilter: ColorFilter.mode(
                    Constants.GREEN_COLOR,
                    BlendMode.srcIn,
                  ),
                  height: 30,
                  width: 30,
                ),
                const SizedBox(width: 10),
                Text(
                  text,
                  style: Styles().textStyle(22, Styles.w600Weight, Styles.customBlack),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
