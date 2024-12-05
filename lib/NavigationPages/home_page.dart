import 'package:flutter/material.dart';
import 'package:location/location.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

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

      },
    );
  }
}


class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.title});
  final String title;

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  String _searchText = "";
  late GoogleMapController mapController;
  LocationData? _currentLocation;
  late Location _location;

  @override
  void initState() {
    super.initState();
    _location = Location();
    _checkPermissionsAndNavigate();
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
        if(permissionGranted != PermissionStatus.granted) {
          _showPermissionDialog();
          return;
        }
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
        title: Text('Permission Required'),
        content: Text(
          'This app needs location permission to work. Please allow it in your settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Ok'),
          ),
        ],
      ),
    );
  }

  void _showLocationServicesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Enable Location Services'),
        content: Text(
          'Location services are disabled. Please enable them to use this feature.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showLocationErrorDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Location Error'),
        content: Text('Unable to fetch the current location. Please try again later.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // Floating search bar
            Positioned(
              top: screenHeight * 0.02, // 2% from the top of the screen
              left: screenWidth * 0.05, // 5% padding from the left
              right: screenWidth * 0.05, // 5% padding from the right
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  height:
                      screenHeight * 0.06, // Adjust height based on screen size
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    color: Colors.white,
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 16), // Left padding
                      const Icon(Icons.search, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          onChanged: (value) {
                            setState(() {
                              _searchText =
                                  value; // Update state with search input
                            });
                          },
                          decoration: InputDecoration(
                            hintText: 'Search for routes',
                            border: InputBorder.none,
                            hintStyle: TextStyle(color: Colors.grey[500]),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16), // Right padding
                    ],
                  ),
                ),
              ),
            ),

            // Displaying search input for testing purposes
            Positioned(
              top: screenHeight * 0.12,
              left: screenWidth * 0.05,
              right: screenWidth * 0.05,
              child: Text(
                _searchText.isNotEmpty ? 'You searched for: $_searchText' : '',
                style: const TextStyle(color: Colors.black, fontSize: 16),
              ),
            ),
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
