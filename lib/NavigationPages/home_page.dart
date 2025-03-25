// ignore_for_file: non_constant_identifier_names, constant_identifier_names

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pasada_driver_side/Map/google_map.dart';
import 'package:pasada_driver_side/Map/route_location.dart';
import 'package:pasada_driver_side/PassengerCapacity/passenger_capacity.dart';
import 'package:pasada_driver_side/driver_provider.dart';
import 'package:pasada_driver_side/global.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  int Capacity = 0;
  late GoogleMapController mapController;
  // LocationData? _currentLocation;
  // late Location _location;

  //para makuha yung route ng driver
  RouteLocation? InitialLocation; // 14.721061, 121.037486  savemore novaliches
  RouteLocation? FinalLocation; // 14.692621, 120.969886 valenzuela peoples park
  static const LatLng StartingLocation =
      LatLng(14.721957951314671, 121.03660698876655);
  static const LatLng EndingLocation =
      LatLng(14.693043926864853, 120.96837288743365);

  //used to access MapScreenState
  final GlobalKey<MapScreenState> mapScreenKey = GlobalKey<MapScreenState>();

  final GlobalKey containerKey = GlobalKey();
  double containerHeight = 0;

  Future<void> getPassengerCapacity() async {
    await PassengerCapacity().getPassengerCapacityToDB(context);
    setState(() {
      Capacity = context.read<DriverProvider>().passengerCapacity!;
    });

Fluttertoast.showToast(
      msg: 'Vehicle capacity: $Capacity',
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.black,
      textColor: Colors.white,
    );  }

  @override
  void initState() {
    super.initState();
    // _location = Location();
    // _checkPermissionsAndNavigate();

    if (!GlobalVar().isDriving) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showStartDrivingDialog();
      });
    }
    getPassengerCapacity();
  }

//GO ONLINE DIALOG
  void _showStartDrivingDialog() {
    showDialog(
      context: context,
      barrierDismissible: true, // Enables dismissing dialog by tapping outside
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Welcome Manong!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'To start getting passengers, start driving.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 20), // Add some spacing
              Center(
                child: ElevatedButton(
                  onPressed: () {
                    //Updates driving status to 'Driving' in the database
                    final String driverID =
                        context.read<DriverProvider>().driverID!;
                    _setStatusToDriving(driverID);

                    setState(() {
                      if (kDebugMode) {
                        print(GlobalVar().isDriving);
                      }
                      GlobalVar().isDriving = true;
                      if (kDebugMode) {
                        print(GlobalVar().isDriving);
                      }
                    });
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 8,
                    backgroundColor: Colors.black,
                  ),
                  child: const Text(
                    'Start Driving',
                    style: TextStyle(
                        fontSize: 16,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w500,
                        color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _setStatusToDriving(String driverID) async {
    try {
      final response = await Supabase.instance.client
          .from('driverTable')
          .update({'driving_status': 'Driving'})
          .eq('driver_id', driverID)
          .select('driving_status')
          .single();
      if (mounted) {
        GlobalVar()
            .updateStatus(GlobalVar().driverStatus.indexOf('Driving'), context);
      }
      _showToast('status updated to ${response['driving_status'].toString()}');
    } catch (e) {
      _showToast('Error: $e');

      if (kDebugMode) {
        print('Error: $e');
      }
    }
  }

  void _showToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.black,
      textColor: Colors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: SizedBox(
        child: Stack(
          children: [
            // Update the MapScreen widget in the HomePage's build method
            MapScreen(
              key: mapScreenKey,
              initialLocation: StartingLocation,
              finalLocation: EndingLocation,
            ),

            // FLOATING MESSAGE BUTTON
            FloatingMessageButton(
                screenHeight: screenHeight, screenWidth: screenWidth),

            // PASSENGER CAPACITY
            FloatingPassengerCapacity(
                screenHeight: screenHeight,
                screenWidth: screenWidth,
                Capacity: Capacity),
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
          onPressed: () {},
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
  const FloatingPassengerCapacity({
    super.key,
    required this.screenHeight,
    required this.screenWidth,
    required this.Capacity,
  });

  final double screenHeight;
  final double screenWidth;
  final int Capacity;

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
          onPressed: () {},
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          child: TextButton(
              onPressed: () {},
              child: Text(
                Capacity.toString(),
                style: const TextStyle(
                    fontFamily: 'Intern',
                    fontWeight: FontWeight.w500,
                    fontSize: 22,
                    color: Colors.black),
              )),
        ),
      ),
    );
  }
}
