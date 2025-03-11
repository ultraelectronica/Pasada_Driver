import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:location/location.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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
      routes: const <String, WidgetBuilder>{},
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
  String _searchText = "";
  late GoogleMapController mapController;
  LocationData? _currentLocation;
  late Location _location;

  Future<void> getPassengerCapacity() async {
    await PassengerCapacity().getPassengerCapacityToDB(context);
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
    _checkPermissionsAndNavigate();

    if (!GlobalVar().isOnline) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showGoOnlineDialog();
      });
    }
    getPassengerCapacity();
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

    // ensure that the location is fetched before building the map
    if (_currentLocation == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // GOOGLE MAPS
            GoogleMap(
              onMapCreated: _onMapCreated,
              initialCameraPosition: CameraPosition(
                target: LatLng(
                  _currentLocation!.latitude!,
                  _currentLocation!.longitude!,
                ),
                zoom: 15,
              ),
              myLocationEnabled: true,
              myLocationButtonEnabled: false, // there will be a custom button
              mapType: MapType.normal,
              zoomControlsEnabled: false,
              trafficEnabled:
                  true, // i just found this kaya try to uncomment this
            ),

            // CUSTOM MY LOCATION BUTTON
            Positioned(
              bottom: screenHeight * 0.025,
              right: screenWidth * 0.05,
              child: SizedBox(
                width: 50,
                height: 50,
                child: FloatingActionButton(
                  onPressed: () {
                    mapController.animateCamera(
                      CameraUpdate.newCameraPosition(
                        CameraPosition(
                          target: LatLng(
                            _currentLocation!.latitude!,
                            _currentLocation!.longitude!,
                          ),
                          zoom: 15,
                        ),
                      ),
                    );
                  },
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(Icons.my_location,
                      color: Colors.black, size: 26),
                ),
              ),
            ),

            // FLOATING MESSAGE BUTTON
            Positioned(
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
            ),

            // PASSENGER CAPACITY
            Positioned(
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
            ),

            // FLOATING SEARCH BAR
            Positioned(
              top: screenHeight * 0.02,
              left: screenWidth * 0.05,
              right: screenWidth * 0.05,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  height: screenHeight * 0.06,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    color: Colors.white,
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 16),
                      const Icon(Icons.search, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          onChanged: (value) {
                            setState(() {
                              // Handle search input
                            });
                          },
                          decoration: InputDecoration(
                            hintText: 'Search for routes',
                            border: InputBorder.none,
                            hintStyle: TextStyle(color: Colors.grey[500]),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                    ],
                  ),
                ),
              ),
            ),

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

      // // Bottom Navigation Bar
      // bottomNavigationBar: BottomNavigationBar(
      //   currentIndex: _selectedIndex,
      //   onTap: _onItemTapped,
      //   items: const [
      //     BottomNavigationBarItem(
      //       label: 'Home',
      //       icon: Icon(Icons.home),
      //     ),
      //     BottomNavigationBarItem(
      //       label: 'Activity',
      //       icon: Icon(Icons.local_activity),
      //     ),
      //     BottomNavigationBarItem(
      //       label: 'Profile',
      //       icon: Icon(Icons.person),
      //     ),
      //   ],
      // ),
    );
  }
}
