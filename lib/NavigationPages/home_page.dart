// ignore_for_file: non_constant_identifier_names, constant_identifier_names

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_svg/svg.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:location/location.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pasada_driver_side/NavigationPages/Map/google_map.dart';
import 'package:pasada_driver_side/NavigationPages/Map/route_location.dart';
import 'package:pasada_driver_side/NavigationPages/PassengerCapacity/passenger_capacity.dart';
import 'package:pasada_driver_side/driver_provider.dart';
import 'package:pasada_driver_side/global.dart';
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
  int Capacity = 0;
  late GoogleMapController mapController;
  LocationData? _currentLocation;
  late Location _location;

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
    await FloatingPassengerCapacity(
      screenHeight: MediaQuery.of(context).size.height,
      screenWidth: MediaQuery.of(context).size.width,
      Capacity: context.read<DriverProvider>().passengerCapacity!,
    ).getPassengerCapacityToDB(context);
    Capacity = context.read<DriverProvider>().passengerCapacity!;

    if (Capacity != null) {
      Fluttertoast.showToast(msg: 'Vehicle Capacity: ${Capacity.toString()}');
    } else {
      Fluttertoast.showToast(msg: 'Vehicle Capacity is not available.');
    }
  }

  @override
  void initState() {
    super.initState();
    _location = Location();
    // _checkPermissionsAndNavigate();

    if (!GlobalVar().isOnline) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showGoOnlineDialog();
      });
    }
    getPassengerCapacity();
  }

  void measureContainer() {
    final RenderBox? box =
        containerKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null) {
      setState(() {
        containerHeight = box.size.height;
      });
    }
  }

//GO ONLINE DIALOG
  void _showGoOnlineDialog() {
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
                    setState(() {
                      if (kDebugMode) {
                        print(GlobalVar().isOnline);
                      }
                      GlobalVar().isOnline = true;
                      if (kDebugMode) {
                        print(GlobalVar().isOnline);
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

  // helper function for showing alert dialogs to reduce repetition
  void showAlertDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  // specific error dialog using the helper function
  void showLocationErrorDialog() {
    showAlertDialog(
      'Location Error',
      'Unable to fetch the current location. Please try again later.',
    );
  }

  // generic error dialog using the helper function
  void showError(String message) {
    showAlertDialog('Error', message);
  }

  void showDebugToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_LONG,
      backgroundColor: Colors.black87,
      textColor: Colors.white,
    );
  }

  Future<void> _checkPermissionsAndNavigate() async {
    try {
      // check if location service is enabled
      bool serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _location.serviceEnabled();
        if (!serviceEnabled) {
          _showLocationServicesDialog();
          return;
        }
      }
      // check for and request location permissions
      PermissionStatus permissionGranted = await _location.hasPermission();
      if (permissionGranted == PermissionStatus.denied) {
        permissionGranted = await _location.requestPermission();
        if (permissionGranted != PermissionStatus.granted) {
          _showPermissionDialog();
          return;
        }
        //what will happen if rejected?
      }
      // get current location
      _currentLocation = await _location.getLocation();
      if (_currentLocation != null) {
        setState(() {});
      } else {
        _showLocationErrorDialog();
      }
    } catch (e) {
      _showErrorDialog("An error occured while fetching the location.");
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permission Required'),
        content: const Text(
          'This app needs location permission to work. Please allow it in your settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Ok'),
          ),
        ],
      ),
    );
  }

  void _showLocationServicesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enable Location Services'),
        content: const Text(
          'Location services are disabled. Please enable them to use this feature.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showLocationErrorDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Error'),
        content: const Text(
            'Unable to fetch the current location. Please try again later.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String passengerCapacity = '0';
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

            // FLOATING SEARCH BAR

            // Displaying search input for testing purposes
            // Positioned(
            //   top: screenHeight * 0.12,
            //   left: screenWidth * 0.05,
            //   right: screenWidth * 0.05,
            //   child: Text(
            //     _searchText.isNotEmpty ? 'You searched for: $_searchText' : '',
            //     style: const TextStyle(color: Colors.black, fontSize: 16),
            //   ),
            // ),
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
  Future<void> getPassengerCapacityToDB(BuildContext context) async {
    // Add your implementation here
  }
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
