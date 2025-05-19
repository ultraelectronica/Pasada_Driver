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
import 'dart:math';
import 'package:pasada_driver_side/Config/app_config.dart';

// Model to track passenger proximity status
class PassengerStatus {
  final Booking booking;
  final double distance;
  final bool isNearPickup;
  final bool isNearDropoff;
  final bool isApproachingPickup;
  final bool isApproachingDropoff;

  const PassengerStatus({
    required this.booking,
    required this.distance,
    this.isNearPickup = false,
    this.isNearDropoff = false,
    this.isApproachingPickup = false,
    this.isApproachingDropoff = false,
  });

  PassengerStatus copyWith({
    Booking? booking,
    double? distance,
    bool? isNearPickup,
    bool? isNearDropoff,
    bool? isApproachingPickup,
    bool? isApproachingDropoff,
  }) {
    return PassengerStatus(
      booking: booking ?? this.booking,
      distance: distance ?? this.distance,
      isNearPickup: isNearPickup ?? this.isNearPickup,
      isNearDropoff: isNearDropoff ?? this.isNearDropoff,
      isApproachingPickup: isApproachingPickup ?? this.isApproachingPickup,
      isApproachingDropoff: isApproachingDropoff ?? this.isApproachingDropoff,
    );
  }
}

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

  // List of nearby passengers with their status
  List<PassengerStatus> _nearbyPassengers = [];

  // Currently selected passenger for interaction
  String? _selectedPassengerId;

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

  // Timer for booking fetches (separate from proximity checks)
  Timer? _bookingFetchTimer;

  // Loading state for bookings fetch
  bool _isLoadingBookings = false;

  Future<void> getPassengerCapacity() async {
    // get the passenger capacity from the DB
    await PassengerCapacity().getPassengerCapacityToDB(context);
  }

  // Method to check proximity for all passengers
  void _checkProximity(BuildContext context) {
    if (!mounted) return;

    final driverProvider = context.read<DriverProvider>();
    final mapProvider = context.read<MapProvider>();
    final passengerProvider = context.read<PassengerProvider>();

    // Only perform proximity checks if driver is in Driving mode
    if (driverProvider.driverStatus != 'Driving') {
      // Clear passenger data if not driving
      setState(() {
        _nearbyPassengers = [];
        _selectedPassengerId = null;
        _isNearPickupLocation = false;
        _nearestBookingId = null;
        _isNearDropoffLocation = false;
        _ongoingBookingId = null;
      });
      return;
    }

    // Remove periodic booking refresh from here since we have a dedicated timer now

    // Get current location
    final currentLocation = mapProvider.currentLocation;

    // Get all relevant bookings
    final acceptedBookings = passengerProvider.bookings
        .where(
            (booking) => booking.rideStatus == BookingRepository.statusAccepted)
        .toList();

    final ongoingBookings = passengerProvider.bookings
        .where(
            (booking) => booking.rideStatus == BookingRepository.statusOngoing)
        .toList();

    // Combined list of all active bookings
    final allActiveBookings = [...acceptedBookings, ...ongoingBookings];

    // Skip if no location or no bookings
    if (currentLocation == null || allActiveBookings.isEmpty) {
      setState(() {
        _nearbyPassengers = [];
        _selectedPassengerId = null;
        _isNearPickupLocation = false;
        _nearestBookingId = null;
        _isNearDropoffLocation = false;
        _ongoingBookingId = null;
      });
      return;
    }

    // Calculate distances and statuses for all active bookings
    List<PassengerStatus> passengerStatuses = [];

    // Process all bookings
    for (final booking in allActiveBookings) {
      // Calculate appropriate distance based on booking status
      double distance;
      bool isNearPickup = false;
      bool isApproachingPickup = false;
      bool isNearDropoff = false;
      bool isApproachingDropoff = false;

      if (booking.rideStatus == BookingRepository.statusAccepted) {
        // For accepted bookings, measure distance to pickup
        distance = Geolocator.distanceBetween(
            currentLocation.latitude,
            currentLocation.longitude,
            booking.pickupLocation.latitude,
            booking.pickupLocation.longitude);

        // Use AppConfig threshold values
        isNearPickup = distance < AppConfig.activePickupProximityThreshold;
        isApproachingPickup =
            distance >= AppConfig.activePickupProximityThreshold &&
                distance < AppConfig.activePickupApproachThreshold;
      } else {
        // For ongoing bookings, measure distance to dropoff
        distance = Geolocator.distanceBetween(
            currentLocation.latitude,
            currentLocation.longitude,
            booking.dropoffLocation.latitude,
            booking.dropoffLocation.longitude);

        // Use AppConfig threshold values
        isNearDropoff = distance < AppConfig.activeDropoffProximityThreshold;
        isApproachingDropoff =
            distance >= AppConfig.activeDropoffProximityThreshold &&
                distance < AppConfig.activeDropoffApproachThreshold;
      }

      // Create passenger status for this booking
      passengerStatuses.add(PassengerStatus(
        booking: booking,
        distance: distance,
        isNearPickup: isNearPickup,
        isApproachingPickup: isApproachingPickup,
        isNearDropoff: isNearDropoff,
        isApproachingDropoff: isApproachingDropoff,
      ));
    }

    // Smart sorting: prioritize by status categories and then by distance
    passengerStatuses.sort((a, b) {
      // Priority 1: Passengers ready for pickup/dropoff (those who are waiting and driver is there)
      if (a.isNearPickup && !b.isNearPickup) return -1;
      if (b.isNearPickup && !a.isNearPickup) return 1;
      if (a.isNearDropoff && !b.isNearDropoff) return -1;
      if (b.isNearDropoff && !a.isNearDropoff) return 1;

      // Priority 2: Passengers who are being approached by driver
      if (a.isApproachingPickup && !b.isApproachingPickup) return -1;
      if (b.isApproachingPickup && !a.isApproachingPickup) return 1;
      if (a.isApproachingDropoff && !b.isApproachingDropoff) return -1;
      if (b.isApproachingDropoff && !a.isApproachingDropoff) return 1;

      // Priority 3: Ongoing rides over pickups
      if (a.booking.rideStatus == BookingRepository.statusOngoing &&
          b.booking.rideStatus == BookingRepository.statusAccepted) return -1;
      if (b.booking.rideStatus == BookingRepository.statusOngoing &&
          a.booking.rideStatus == BookingRepository.statusAccepted) return 1;

      // Priority 4: Sort by absolute distance (closest first)
      return a.distance.compareTo(b.distance);
    });

    // Keep only the 3 nearest passengers
    if (passengerStatuses.length > 3) {
      passengerStatuses = passengerStatuses.sublist(0, 3);
    }

    // Determine if any notifications should be shown (not more often than every 15 seconds)
    final now = DateTime.now();
    final canShowNotification = _lastProximityNotificationTime == null ||
        now.difference(_lastProximityNotificationTime!).inSeconds > 15;

    if (canShowNotification && passengerStatuses.isNotEmpty) {
      // Find the closest passenger with a status change to notify about
      PassengerStatus? passengerToNotify;

      // First check for pickups
      passengerToNotify = passengerStatuses.firstWhere(
          (p) =>
              p.isNearPickup &&
              p.booking.rideStatus == BookingRepository.statusAccepted,
          orElse: () => PassengerStatus(
              booking: Booking(
                  id: '',
                  passengerId: '',
                  rideStatus: '',
                  pickupLocation: LatLng(0, 0),
                  dropoffLocation: LatLng(0, 0)),
              distance: double.infinity));

      // Then check for dropoffs if no pickup notification
      if (passengerToNotify.booking.id.isEmpty) {
        passengerToNotify = passengerStatuses.firstWhere(
            (p) =>
                p.isNearDropoff &&
                p.booking.rideStatus == BookingRepository.statusOngoing,
            orElse: () => PassengerStatus(
                booking: Booking(
                    id: '',
                    passengerId: '',
                    rideStatus: '',
                    pickupLocation: LatLng(0, 0),
                    dropoffLocation: LatLng(0, 0)),
                distance: double.infinity));
      }

      // Then check for approaching pickups
      if (passengerToNotify.booking.id.isEmpty) {
        passengerToNotify = passengerStatuses.firstWhere(
            (p) =>
                p.isApproachingPickup &&
                p.booking.rideStatus == BookingRepository.statusAccepted,
            orElse: () => PassengerStatus(
                booking: Booking(
                    id: '',
                    passengerId: '',
                    rideStatus: '',
                    pickupLocation: LatLng(0, 0),
                    dropoffLocation: LatLng(0, 0)),
                distance: double.infinity));
      }

      // Finally check for approaching dropoffs
      if (passengerToNotify.booking.id.isEmpty) {
        passengerToNotify = passengerStatuses.firstWhere(
            (p) =>
                p.isApproachingDropoff &&
                p.booking.rideStatus == BookingRepository.statusOngoing,
            orElse: () => PassengerStatus(
                booking: Booking(
                    id: '',
                    passengerId: '',
                    rideStatus: '',
                    pickupLocation: LatLng(0, 0),
                    dropoffLocation: LatLng(0, 0)),
                distance: double.infinity));
      }

      // Show notification if applicable
      if (passengerToNotify.booking.id.isNotEmpty) {
        _lastProximityNotificationTime = now;

        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            if (passengerToNotify!.isNearPickup) {
              // Arrived at pickup
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('You have arrived at a pickup location!'),
                  backgroundColor: Constants.GREEN_COLOR,
                  duration: const Duration(seconds: 3),
                ),
              );
            } else if (passengerToNotify.isNearDropoff) {
              // Arrived at dropoff
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content:
                      const Text('You have arrived at a dropoff location!'),
                  backgroundColor: Colors.orange,
                  duration: const Duration(seconds: 3),
                ),
              );
            } else if (passengerToNotify.isApproachingPickup) {
              // Approaching pickup
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      'Approaching pickup: ${passengerToNotify.distance.toInt()} meters away'),
                  backgroundColor: Colors.blue,
                  duration: const Duration(seconds: 2),
                ),
              );
            } else if (passengerToNotify.isApproachingDropoff) {
              // Approaching dropoff
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      'Approaching dropoff: ${passengerToNotify.distance.toInt()} meters away'),
                  backgroundColor: Colors.orange,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          }
        });
      }
    }

    // Update the state with new passenger statuses
    setState(() {
      _nearbyPassengers = passengerStatuses;

      // Set selected passenger if not already set
      if (_selectedPassengerId == null && passengerStatuses.isNotEmpty) {
        _selectedPassengerId = passengerStatuses.first.booking.id;
      } else if (_selectedPassengerId != null) {
        // Make sure selected passenger is still in the list
        final stillExists =
            passengerStatuses.any((p) => p.booking.id == _selectedPassengerId);
        if (!stillExists && passengerStatuses.isNotEmpty) {
          _selectedPassengerId = passengerStatuses.first.booking.id;
        } else if (!stillExists) {
          _selectedPassengerId = null;
        }
      }

      // Set backward compatibility flags for the selected passenger
      if (_selectedPassengerId != null) {
        final selectedPassenger = passengerStatuses.firstWhere(
            (p) => p.booking.id == _selectedPassengerId,
            orElse: () => PassengerStatus(
                booking: Booking(
                    id: '',
                    passengerId: '',
                    rideStatus: '',
                    pickupLocation: LatLng(0, 0),
                    dropoffLocation: LatLng(0, 0)),
                distance: double.infinity));

        if (selectedPassenger.booking.id.isNotEmpty) {
          _isNearPickupLocation = selectedPassenger.isNearPickup;
          _isNearDropoffLocation = selectedPassenger.isNearDropoff;

          if (selectedPassenger.booking.rideStatus ==
              BookingRepository.statusAccepted) {
            _nearestBookingId = selectedPassenger.booking.id;
            _ongoingBookingId = null;
          } else if (selectedPassenger.booking.rideStatus ==
              BookingRepository.statusOngoing) {
            _nearestBookingId = null;
            _ongoingBookingId = selectedPassenger.booking.id;
          }
        }
      } else {
        _isNearPickupLocation = false;
        _isNearDropoffLocation = false;
        _nearestBookingId = null;
        _ongoingBookingId = null;
      }
    });

    // Update map markers to reflect passenger status changes
    _updateMapMarkers();
  }

  // Method to fetch bookings with loading indicator
  Future<void> fetchBookings(BuildContext context) async {
    if (_isLoadingBookings) return; // Prevent multiple simultaneous fetches

    setState(() {
      _isLoadingBookings = true;
    });

    try {
      // Add a small delay to ensure the loading indicator appears
      await Future.delayed(Duration.zero);
      // Get driver provider
      final driverProvider = context.read<DriverProvider>();
      final passengerProvider = context.read<PassengerProvider>();

      // Only fetch if in driving mode
      if (driverProvider.driverStatus == 'Driving') {
        // Use the direct startBookingStream call if possible
        final driverId = driverProvider.driverID;
        if (driverId.isNotEmpty) {
          passengerProvider.startBookingStream(driverId);
        }

        // Use context-less call to avoid disposed widget issues
        await passengerProvider.getBookingRequestsID(null);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingBookings = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();

    // Delay timer start to ensure context is fully ready
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Start proximity check timer using AppConfig interval
        _proximityCheckTimer = Timer.periodic(
            Duration(seconds: AppConfig.proximityCheckInterval), (timer) {
          if (mounted) {
            _checkProximity(context);
            // Update map markers after proximity check
            _updateMapMarkers();
          }
        });

        // Start booking fetch timer using AppConfig interval
        _bookingFetchTimer = Timer.periodic(
            Duration(seconds: AppConfig.periodicFetchInterval), (timer) {
          if (mounted) {
            final driverProvider = context.read<DriverProvider>();
            if (driverProvider.driverStatus == 'Driving' &&
                !_isLoadingBookings) {
              fetchBookings(context);
            }
          }
        });

        // Run initial checks
        _checkProximity(context);
        _updateMapMarkers();

        // Initial booking fetch if in driving mode
        final driverProvider = context.read<DriverProvider>();

        // Start real-time booking stream if in driving mode
        if (driverProvider.driverStatus == 'Driving') {
          fetchBookings(context);
          final passengerProvider = context.read<PassengerProvider>();
          passengerProvider.startBookingStream(driverProvider.driverID);
        }
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // We'll let the timers handle fetches instead of doing it here
  }

  // Only listen for status changes from non-driving to driving
  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);

    // We'll let the timers handle fetches instead of doing it here
  }

  @override
  void dispose() {
    // Cancel timers when widget is disposed
    _proximityCheckTimer?.cancel();
    _bookingFetchTimer?.cancel();
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

            // PASSENGER LIST - shows top 3 nearest passengers
            if (_nearbyPassengers.isNotEmpty)
              Positioned(
                top: MediaQuery.of(context).padding.top +
                    10, // Reset to original position
                left: 10,
                right: 10,
                child: PassengerListWidget(
                  passengers: _nearbyPassengers,
                  selectedPassengerId: _selectedPassengerId,
                  onSelected: (passengerId) {
                    setState(() {
                      _selectedPassengerId = passengerId;

                      // Update other state variables based on the selected passenger
                      final selectedPassenger = _nearbyPassengers.firstWhere(
                          (p) => p.booking.id == passengerId,
                          orElse: () => _nearbyPassengers.first);

                      _isNearPickupLocation = selectedPassenger.isNearPickup;
                      _isNearDropoffLocation = selectedPassenger.isNearDropoff;

                      if (selectedPassenger.booking.rideStatus ==
                          BookingRepository.statusAccepted) {
                        _nearestBookingId = selectedPassenger.booking.id;
                        _ongoingBookingId = null;

                        // Focus map on the pickup location for this passenger
                        _focusMapOnLocation(
                            selectedPassenger.booking.pickupLocation);

                        // Update the selected pickup in MapProvider
                        context.read<MapProvider>().setPickUpLocation(
                            selectedPassenger.booking.pickupLocation);
                      } else if (selectedPassenger.booking.rideStatus ==
                          BookingRepository.statusOngoing) {
                        _nearestBookingId = null;
                        _ongoingBookingId = selectedPassenger.booking.id;

                        // Focus map on the dropoff location for this passenger
                        _focusMapOnLocation(
                            selectedPassenger.booking.dropoffLocation);
                      }
                    });

                    // Update map markers to reflect selection change
                    _updateMapMarkers();
                  },
                ),
              ),

            // FLOATING MESSAGE BUTTON
            FloatingMessageButton(
              screenHeight: screenHeight,
              screenWidth: screenWidth,
              isLoading: _isLoadingBookings,
              onRefresh: () => fetchBookings(context),
            ),

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

            // CONFIRM PICKUP BUTTON - only shown when near pickup location and a passenger is selected
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
                          // Don't reset selection, just update status
                          _isNearPickupLocation = false;

                          // Refresh proximity data
                          _checkProximity(context);
                        });

                        // Update map markers to reflect the status change
                        _updateMapMarkers();
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
                          // Don't reset selection, just update status
                          _isNearDropoffLocation = false;

                          // Refresh proximity data
                          _checkProximity(context);
                        });

                        // Update map markers to reflect the status change
                        _updateMapMarkers();
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

            // Loading indicator overlay when fetching bookings
            if (_isLoadingBookings)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.2),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 40,
                            height: 40,
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Constants.GREEN_COLOR),
                              strokeWidth: 3,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Finding Passengers...',
                            style: Styles().textStyle(
                                16, Styles.w600Weight, Styles.customBlack),
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

  // Method to focus the map on a location
  void _focusMapOnLocation(LatLng location) {
    // Get reference to the MapScreenState
    final mapScreenState = mapScreenKey.currentState;
    if (mapScreenState != null) {
      // Use the animateToLocation method in MapScreenState
      mapScreenState.animateToLocation(location);
    }
  }

  // Method to update map markers based on passenger statuses
  void _updateMapMarkers() {
    final mapScreenState = mapScreenKey.currentState;
    if (mapScreenState == null) return;

    // Clear all passenger-related markers (keep route markers)
    mapScreenState.clearPassengerMarkers();

    for (final passenger in _nearbyPassengers) {
      final isSelected = passenger.booking.id == _selectedPassengerId;

      // Determine marker appearance based on status
      BitmapDescriptor markerIcon;
      double zIndex = isSelected ? 5.0 : 3.0; // Selected markers appear on top

      if (passenger.booking.rideStatus == BookingRepository.statusAccepted) {
        // Pickup markers
        if (passenger.isNearPickup) {
          // Ready for pickup - green pin
          markerIcon =
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
        } else {
          // Regular pickup - blue pin
          markerIcon =
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
        }

        // Add pickup marker
        mapScreenState.addCustomMarker(
          id: 'pickup_${passenger.booking.id}',
          position: passenger.booking.pickupLocation,
          icon: markerIcon,
          title: isSelected ? 'Selected Pickup' : 'Pickup',
          zIndex: zIndex,
        );

        // Always show faded dropoff marker for context
        mapScreenState.addCustomMarker(
          id: 'dropoff_future_${passenger.booking.id}',
          position: passenger.booking.dropoffLocation,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose),
          title: 'Future Dropoff',
          zIndex: 2.0,
          alpha: 0.7, // Semi-transparent
        );
      } else {
        // Dropoff markers for ongoing rides
        if (passenger.isNearDropoff) {
          // Ready for dropoff - orange pin
          markerIcon =
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
        } else {
          // Regular dropoff - red pin
          markerIcon =
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
        }

        // Add dropoff marker
        mapScreenState.addCustomMarker(
          id: 'dropoff_${passenger.booking.id}',
          position: passenger.booking.dropoffLocation,
          icon: markerIcon,
          title: isSelected ? 'Selected Dropoff' : 'Dropoff',
          zIndex: zIndex,
        );
      }
    }
  }
}

class FloatingMessageButton extends StatelessWidget {
  const FloatingMessageButton({
    super.key,
    required this.screenHeight,
    required this.screenWidth,
    required this.isLoading,
    required this.onRefresh,
  });

  final double screenHeight;
  final double screenWidth;
  final bool isLoading;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final driverProvider = context.watch<DriverProvider>();
    final bool isDriving = driverProvider.driverStatus == 'Driving';

    return Positioned(
      bottom: screenHeight * 0.04,
      left: screenWidth * 0.05,
      child: SizedBox(
        width: 50,
        height: 50,
        child: Material(
          color: isDriving ? Colors.white : Colors.grey[300],
          elevation: isDriving ? 4 : 2,
          borderRadius: BorderRadius.circular(15),
          child: InkWell(
            onTap: () {
              if (isDriving) {
                // Manual refresh of bookings
                if (!isLoading) {
                  onRefresh();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Refreshing booking requests...'),
                      backgroundColor: Constants.GREEN_COLOR,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              } else {
                // Prompt to start driving
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content:
                        const Text('To get bookings, set status to "Driving"'),
                    backgroundColor: Colors.orange,
                    duration: const Duration(seconds: 2),
                    action: SnackBarAction(
                      label: 'DRIVE',
                      textColor: Colors.white,
                      onPressed: () {
                        driverProvider.updateStatusToDB('Driving', context);
                        driverProvider.setDriverStatus('Driving');
                        driverProvider.setIsDriving(true);
                      },
                    ),
                  ),
                );
              }
            },
            borderRadius: BorderRadius.circular(15),
            splashColor: isDriving
                ? Colors.blue.withAlpha(77)
                : Colors.grey.withAlpha(77),
            highlightColor: isDriving
                ? Colors.blue.withAlpha(26)
                : Colors.grey.withAlpha(26),
            child: Center(
              child: isLoading
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            isDriving ? Colors.blue : Colors.grey),
                      ),
                    )
                  : Icon(
                      isDriving ? Icons.refresh : Icons.directions_car,
                      color: isDriving ? Colors.blue : Colors.grey,
                      size: 24,
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

// Widget to display the list of nearby passengers
class PassengerListWidget extends StatelessWidget {
  final List<PassengerStatus> passengers;
  final String? selectedPassengerId;
  final Function(String) onSelected;

  const PassengerListWidget({
    Key? key,
    required this.passengers,
    this.selectedPassengerId,
    required this.onSelected,
  }) : super(key: key);

  // Helper to determine priority level (1-4)
  int _getPriorityLevel(PassengerStatus passenger) {
    if (passenger.isNearPickup || passenger.isNearDropoff)
      return 1; // Highest priority - ready for action
    if (passenger.isApproachingPickup || passenger.isApproachingDropoff)
      return 2; // High priority - approaching
    if (passenger.booking.rideStatus == BookingRepository.statusOngoing)
      return 3; // Medium priority - ongoing rides
    return 4; // Normal priority - accepted rides
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Text(
              'Nearby Passengers',
              style:
                  Styles().textStyle(16, Styles.w600Weight, Styles.customBlack),
            ),
          ),
          const Divider(height: 1, thickness: 1),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: passengers.length,
            separatorBuilder: (context, index) =>
                const Divider(height: 1, thickness: 1),
            itemBuilder: (context, index) {
              final passenger = passengers[index];
              final isSelected = passenger.booking.id == selectedPassengerId;

              // Determine status text and icon
              IconData statusIcon;
              Color statusColor;
              String statusText;

              if (passenger.booking.rideStatus ==
                  BookingRepository.statusAccepted) {
                if (passenger.isNearPickup) {
                  statusIcon = Icons.place;
                  statusColor = Constants.GREEN_COLOR;
                  statusText = 'Ready for pickup';
                } else if (passenger.isApproachingPickup) {
                  statusIcon = Icons.directions_car;
                  statusColor = Colors.blue;
                  statusText = 'Approaching pickup';
                } else {
                  statusIcon = Icons.access_time;
                  statusColor = Colors.blue;
                  statusText = 'Pickup pending';
                }
              } else {
                // Ongoing
                if (passenger.isNearDropoff) {
                  statusIcon = Icons.place;
                  statusColor = Colors.orange;
                  statusText = 'Ready for dropoff';
                } else if (passenger.isApproachingDropoff) {
                  statusIcon = Icons.directions_car;
                  statusColor = Colors.orange;
                  statusText = 'Approaching dropoff';
                } else {
                  statusIcon = Icons.access_time;
                  statusColor = Colors.orange;
                  statusText = 'Dropoff pending';
                }
              }

              final priorityLevel = _getPriorityLevel(passenger);
              final priorityColor = priorityLevel == 1
                  ? Colors.red
                  : priorityLevel == 2
                      ? Colors.orange
                      : priorityLevel == 3
                          ? Colors.blue
                          : Colors.grey;

              return InkWell(
                onTap: () => onSelected(passenger.booking.id),
                child: Container(
                  color: isSelected
                      ? Colors.grey.withOpacity(0.2)
                      : Colors.transparent,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      // Priority indicator
                      Container(
                        width: 4,
                        height: 45,
                        color: priorityColor,
                        margin: const EdgeInsets.only(right: 8),
                      ),

                      // Status icon
                      Container(
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(8),
                        child: Icon(statusIcon, color: statusColor, size: 20),
                      ),
                      const SizedBox(width: 12),

                      // Passenger details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                // Passenger ID (truncated for display)
                                Text(
                                  'Passenger: ${passenger.booking.passengerId.substring(0, min(4, passenger.booking.passengerId.length))}...',
                                  style: Styles().textStyle(14,
                                      Styles.w500Weight, Styles.customBlack),
                                ),
                                const Spacer(),
                                // Distance with badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.directions_car,
                                        size: 12,
                                        color: statusColor,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _formatDistance(passenger.distance),
                                        style: Styles().textStyle(
                                            12, Styles.w500Weight, statusColor),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            // Status text
                            Row(
                              children: [
                                Text(
                                  statusText,
                                  style: Styles().textStyle(
                                      12, Styles.w400Weight, statusColor),
                                ),
                                if (priorityLevel == 1)
                                  Container(
                                    margin: const EdgeInsets.only(left: 6),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: priorityColor.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'URGENT',
                                      style: Styles().textStyle(
                                          9, Styles.w700Weight, priorityColor),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Selection indicator
                      if (isSelected)
                        const Icon(Icons.check_circle,
                            color: Colors.blue, size: 24),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // Format distance to be more human-readable
  String _formatDistance(double meters) {
    if (meters >= 1000) {
      final km = (meters / 1000).toStringAsFixed(1);
      return '$km km';
    } else {
      return '${meters.round()} m';
    }
  }
}
