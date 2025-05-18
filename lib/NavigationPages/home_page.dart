// ignore_for_file: non_constant_identifier_names, constant_identifier_names

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pasada_driver_side/Database/passenger_capacity.dart';
import 'package:pasada_driver_side/Database/passenger_provider.dart';
import 'package:pasada_driver_side/Map/google_map.dart';
import 'package:pasada_driver_side/Database/driver_provider.dart';
import 'package:pasada_driver_side/Database/map_provider.dart';
import 'package:pasada_driver_side/UI/constants.dart';
import 'package:pasada_driver_side/UI/text_styles.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'package:flutter/scheduler.dart';

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

  // Flag to track if driver is near pickup location
  bool _isNearPickupLocation = false;
  String? _nearestBookingId;

  // Flag to track if driver is near dropoff location
  bool _isNearDropoffLocation = false;
  String? _ongoingBookingId;

  // Track when notifications were last shown
  DateTime? _lastProximityNotificationTime;

  // Timer for proximity checks
  Timer? _proximityCheckTimer;

  Future<void> getPassengerCapacity() async {
    // get the passenger capacity from the DB
    // await context.read<DriverProvider>().getPassengerCapacity();
    await PassengerCapacity().getPassengerCapacityToDB(context);
    // _showToast('Vehicle capacity: $Capacity');
  }

  // Method to check if driver is near pickup location
  void _checkPickupProximity(BuildContext context) {
    if (!mounted) return;

    final mapProvider = context.read<MapProvider>();
    final passengerProvider = context.read<PassengerProvider>();

    // Get current location and pickup location
    final currentLocation = mapProvider.currentLocation;
    final pickupLocation = mapProvider.pickupLocation;

    // Get active bookings
    final activeBookings = passengerProvider.bookings
        .where(
            (booking) => booking.rideStatus == BookingRepository.statusAccepted)
        .toList();

    // Get ongoing bookings for dropoff detection
    final ongoingBookings = passengerProvider.bookings
        .where(
            (booking) => booking.rideStatus == BookingRepository.statusOngoing)
        .toList();

    // PICKUP PROXIMITY CHECK
    if (currentLocation != null &&
        pickupLocation != null &&
        activeBookings.isNotEmpty) {
      // Calculate distance between driver and pickup location
      final distance = Geolocator.distanceBetween(
          currentLocation.latitude,
          currentLocation.longitude,
          pickupLocation.latitude,
          pickupLocation.longitude);

      // Find the nearest booking with the pickup location
      final nearestBooking = activeBookings.firstWhere(
        (booking) =>
            booking.pickupLocation.latitude == pickupLocation.latitude &&
            booking.pickupLocation.longitude == pickupLocation.longitude,
        orElse: () => activeBookings.first,
      );

      // Determine if it's time to show another notification (not more often than every 15 seconds)
      final now = DateTime.now();
      final canShowNotification = _lastProximityNotificationTime == null ||
          now.difference(_lastProximityNotificationTime!).inSeconds > 15;

      // If distance is less than 50 meters (or 500 for testing), show the pickup button
      if (distance < 500) {
        // TODO: CHANGE THIS TO 50(500 VALUS IS FOR TESTING ONLY)
        final wasNearPickup = _isNearPickupLocation;
        setState(() {
          _isNearPickupLocation = true;
          _nearestBookingId = nearestBooking.id;
        });

        // Show arrival notification only once when first arriving
        if (!wasNearPickup && canShowNotification) {
          _lastProximityNotificationTime = now;

          // Use SchedulerBinding to show SnackBar after the current frame
          SchedulerBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content:
                      const Text('You have arrived at the pickup location!'),
                  backgroundColor: Constants.GREEN_COLOR,
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          });
        }
      }
      // If distance is between 50-200 meters (or 500-1000 for testing), show approaching notification
      else if (distance >= 500 && distance < 1000 && canShowNotification) {
        // TODO: CHANGE TO 50-200 RANGE FOR PRODUCTION
        setState(() {
          _isNearPickupLocation = false;
          _nearestBookingId = nearestBooking.id;
        });

        // Show a proximity indicator (not too frequently)
        _lastProximityNotificationTime = now;

        // Use SchedulerBinding to show SnackBar after the current frame
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'Approaching pickup location: ${distance.toInt()} meters away'),
                backgroundColor: Colors.blue,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        });
      } else {
        setState(() {
          _isNearPickupLocation = false;
          _nearestBookingId = null;
        });
      }
    } else {
      setState(() {
        _isNearPickupLocation = false;
        _nearestBookingId = null;
      });
    }

    // DROPOFF PROXIMITY CHECK
    if (currentLocation != null && ongoingBookings.isNotEmpty) {
      // Reset dropoff proximity state if no ongoing bookings
      if (ongoingBookings.isEmpty) {
        setState(() {
          _isNearDropoffLocation = false;
          _ongoingBookingId = null;
        });
        return;
      }

      // Get the current ongoing booking
      final ongoingBooking = ongoingBookings.first;

      // Calculate distance to dropoff location
      final dropoffDistance = Geolocator.distanceBetween(
          currentLocation.latitude,
          currentLocation.longitude,
          ongoingBooking.dropoffLocation.latitude,
          ongoingBooking.dropoffLocation.longitude);

      // Determine if it's time to show a notification
      final now = DateTime.now();
      final canShowNotification = _lastProximityNotificationTime == null ||
          now.difference(_lastProximityNotificationTime!).inSeconds > 15;

      // If close to dropoff (less than 50m for production, 500m for testing)
      if (dropoffDistance < 5000) {
        // TODO: Change to 50 for production
        final wasNearDropoff = _isNearDropoffLocation;
        setState(() {
          _isNearDropoffLocation = true;
          _ongoingBookingId = ongoingBooking.id;
        });

        // Show arrival notification once when first arriving at dropoff
        if (!wasNearDropoff && canShowNotification) {
          _lastProximityNotificationTime = now;

          SchedulerBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content:
                      const Text('You have arrived at the dropoff location!'),
                  backgroundColor: Constants.GREEN_COLOR,
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          });
        }
      }
      // If approaching dropoff (between 500-1000m for testing, 50-200m for production)
      else if (dropoffDistance >= 5000 &&
          dropoffDistance < 10000 &&
          canShowNotification) {
        setState(() {
          _isNearDropoffLocation = false;
          _ongoingBookingId = ongoingBooking.id;
        });

        // Show approaching notification
        _lastProximityNotificationTime = now;

        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'Approaching dropoff location: ${dropoffDistance.toInt()} meters away'),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        });
      } else {
        setState(() {
          _isNearDropoffLocation = false;
          _ongoingBookingId = null;
        });
      }
    } else {
      setState(() {
        _isNearDropoffLocation = false;
        _ongoingBookingId = null;
      });
    }
  }

  @override
  void initState() {
    super.initState();

    // Delay timer start to ensure context is fully ready
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Start periodic proximity check (every 5 seconds)
        _proximityCheckTimer =
            Timer.periodic(const Duration(seconds: 5), (timer) {
          if (mounted) {
            _checkPickupProximity(context);
          }
        });

        // Run initial check
        _checkPickupProximity(context);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // We'll run the initial check in initState instead
  }

  @override
  void dispose() {
    // Cancel timer when widget is disposed
    _proximityCheckTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final driverProvider = context.watch<DriverProvider>();
    final passengerProvider = context.watch<PassengerProvider>();

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
            FloatingMessageButton(
                screenHeight: screenHeight, screenWidth: screenWidth),

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

            // CONFIRM PICKUP BUTTON - only shown when near pickup location
            if (_isNearPickupLocation && _nearestBookingId != null)
              Positioned(
                bottom: screenHeight * 0.15,
                left: screenWidth * 0.2,
                right: screenWidth * 0.2,
                child: Material(
                  elevation: 6,
                  borderRadius: BorderRadius.circular(15),
                  child: InkWell(
                    onTap: () async {
                      // Mark booking as ongoing when driver confirms pickup
                      final success = await passengerProvider
                          .markBookingAsOngoing(_nearestBookingId!);
                      if (success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Passenger pickup confirmed!'),
                            backgroundColor: Constants.GREEN_COLOR,
                          ),
                        );
                        setState(() {
                          _isNearPickupLocation = false;
                          _nearestBookingId = null;
                        });
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                                Text('Failed to confirm pickup. Try again.'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(15),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Constants.GREEN_COLOR,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.check_circle_outline,
                            color: Colors.white,
                            size: 28,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Confirm Pickup',
                            style: Styles()
                                .textStyle(18, Styles.w600Weight, Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // COMPLETE RIDE BUTTON - only shown when near dropoff location
            if (_isNearDropoffLocation && _ongoingBookingId != null)
              Positioned(
                bottom: screenHeight * 0.15,
                left: screenWidth * 0.2,
                right: screenWidth * 0.2,
                child: Material(
                  elevation: 6,
                  borderRadius: BorderRadius.circular(15),
                  child: InkWell(
                    onTap: () async {
                      // Mark booking as completed when passenger reaches destination
                      final success = await passengerProvider
                          .markBookingAsCompleted(_ongoingBookingId!);
                      if (success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Ride completed successfully!'),
                            backgroundColor: Constants.GREEN_COLOR,
                          ),
                        );
                        setState(() {
                          _isNearDropoffLocation = false;
                          _ongoingBookingId = null;
                        });
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                                Text('Failed to complete ride. Try again.'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(15),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.done_all,
                            color: Colors.white,
                            size: 28,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Complete Ride',
                            style: Styles()
                                .textStyle(18, Styles.w600Weight, Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
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
      bottom: screenHeight * 0.04,
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
                  style: Styles()
                      .textStyle(22, Styles.w600Weight, Styles.customBlack),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
