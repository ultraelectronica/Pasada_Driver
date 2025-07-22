// ignore_for_file: non_constant_identifier_names, constant_identifier_names

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pasada_driver_side/domain/services/passenger_capacity.dart';
import 'package:pasada_driver_side/presentation/providers/passenger/passenger_provider.dart';
import 'package:pasada_driver_side/common/constants/booking_constants.dart';
import 'package:pasada_driver_side/Map/google_map.dart';
import 'package:pasada_driver_side/presentation/providers/driver/driver_provider.dart';
import 'package:pasada_driver_side/presentation/providers/map_provider.dart';
import 'package:pasada_driver_side/UI/constants.dart';
import 'package:pasada_driver_side/UI/text_styles.dart';
import 'package:provider/provider.dart';
import 'package:flutter/scheduler.dart';
import 'package:pasada_driver_side/presentation/pages/home/utils/home_constants.dart';
import 'package:pasada_driver_side/presentation/pages/home/controllers/home_controller.dart';
import 'package:pasada_driver_side/presentation/pages/home/models/passenger_status.dart';
import 'package:pasada_driver_side/presentation/pages/home/widgets/passenger_list_widget.dart';
import 'package:pasada_driver_side/presentation/pages/home/widgets/floating_message_button.dart';
import 'package:pasada_driver_side/presentation/pages/home/widgets/floating_status_switch.dart';
import 'package:pasada_driver_side/presentation/pages/home/widgets/floating_capacity.dart';
import 'package:pasada_driver_side/presentation/pages/home/widgets/confirm_pickup_button.dart';
import 'package:pasada_driver_side/presentation/pages/home/widgets/complete_ride_button.dart';
import 'package:pasada_driver_side/presentation/pages/home/widgets/reset_capacity_button.dart';

// Model to track passenger proximity status

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

class HomePageState extends State<HomePage> with WidgetsBindingObserver {
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

  // Loading state for bookings fetch
  bool _isLoadingBookings = false;

  // New: centralised controller holding timers & logic
  late HomeController _controller;

  Future<void> getPassengerCapacity() async {
    // get the passenger capacity from the DB
    await PassengerCapacity().getPassengerCapacityToDB(context);
  }

  // _checkProximity removed – logic lives in HomeController

  // Method to fetch bookings with loading indicator
  Future<void> fetchBookings(BuildContext context) async {
    // Delegate to controller
    await _controller.fetchBookings();
  }

  @override
  void initState() {
    super.initState();

    // Instantiate controller
    _controller = HomeController(
      driverProvider: context.read<DriverProvider>(),
      mapProvider: context.read<MapProvider>(),
      passengerProvider: context.read<PassengerProvider>(),
      mapScreenKey: mapScreenKey,
    )..addListener(_onControllerUpdate);

    // Observe app lifecycle to pause/resume timers
    WidgetsBinding.instance.addObserver(this);

    // Delay timer start to ensure context is fully ready
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Initialize passenger capacity system only – controller handles the rest
        PassengerCapacity().initializeCapacity(context);
        // Controller already starts its own timers and fetches; skip legacy setup
      }
    });
  }

  // App lifecycle timer handling removed – HomeController manages timers

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
    _controller.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Syncs controller changes to legacy state vars so existing UI keeps working.
  void _onControllerUpdate() {
    if (!mounted) return;
    setState(() {
      _nearbyPassengers = _controller.nearbyPassengers;
      _selectedPassengerId = _controller.selectedPassengerId;
      _isNearPickupLocation = _controller.isNearPickupLocation;
      _isNearDropoffLocation = _controller.isNearDropoffLocation;
      _nearestBookingId = _controller.nearestBookingId;
      _ongoingBookingId = _controller.ongoingBookingId;
      _isLoadingBookings = _controller.isLoadingBookings;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final driverProvider = context.read<DriverProvider>();
    final passengerProvider = context.read<PassengerProvider>();

    // Reactive values (small granular rebuilds)
    final passengerCapacity =
        context.select<DriverProvider, int>((p) => p.passengerCapacity);
    final passengerStanding =
        context.select<DriverProvider, int>((p) => p.passengerStandingCapacity);
    final passengerSitting =
        context.select<DriverProvider, int>((p) => p.passengerSittingCapacity);
    final driverStatus =
        context.select<DriverProvider, String>((p) => p.driverStatus);

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
                          BookingConstants.statusAccepted) {
                        _nearestBookingId = selectedPassenger.booking.id;
                        _ongoingBookingId = null;

                        // Focus map on the pickup location for this passenger
                        _focusMapOnLocation(
                            selectedPassenger.booking.pickupLocation);

                        // Update the selected pickup in MapProvider
                        context.read<MapProvider>().setPickUpLocation(
                            selectedPassenger.booking.pickupLocation);
                      } else if (selectedPassenger.booking.rideStatus ==
                          BookingConstants.statusOngoing) {
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

            // Floating Status Switch
            FloatingStatusSwitch(
              screenHeight: screenHeight,
              screenWidth: screenWidth,
            ),

            // PASSENGER CAPACITY (TOTAL) - Just refreshes data
            FloatingCapacity(
              driverProvider: driverProvider,
              passengerCapacity: PassengerCapacity(),
              screenHeight: screenHeight,
              screenWidth: screenWidth,
              bottomPosition:
                  screenHeight * HomeConstants.capacityTotalBottomFraction,
              rightPosition:
                  screenWidth * HomeConstants.sideButtonRightFraction,
              icon: 'assets/svg/people.svg',
              text: passengerCapacity.toString(),
              onTap: () {
                PassengerCapacity().getPassengerCapacityToDB(context);
              },
              canIncrement:
                  false, // Total capacity can't be incremented directly
            ),

            // PASSENGER STANDING CAPACITY - Can be incremented manually
            FloatingCapacity(
              driverProvider: driverProvider,
              passengerCapacity: PassengerCapacity(),
              screenHeight: screenHeight,
              screenWidth: screenWidth,
              bottomPosition:
                  screenHeight * HomeConstants.capacityStandingBottomFraction,
              rightPosition:
                  screenWidth * HomeConstants.sideButtonRightFraction,
              icon: 'assets/svg/standing.svg',
              text: passengerStanding.toString(),
              onTap: () async {
                // Increment standing capacity by 1 when tapped
                final result =
                    await PassengerCapacity().manualIncrementStanding(context);

                if (result.success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Standing passenger added manually'),
                      backgroundColor: Colors.blue,
                      duration: Duration(seconds: 2),
                    ),
                  );
                } else {
                  // Show specific error message based on error type
                  String errorMessage = 'Failed to add passenger';
                  Color errorColor = Colors.red;

                  switch (result.errorType) {
                    case PassengerCapacity.ERROR_DRIVER_NOT_DRIVING:
                      errorMessage =
                          'Cannot add passenger: Driver is not in Driving status';
                      break;
                    case PassengerCapacity.ERROR_CAPACITY_EXCEEDED:
                      errorMessage =
                          'Cannot add passenger: Maximum capacity reached';
                      errorColor = Colors.orange;
                      break;
                    case PassengerCapacity.ERROR_NEGATIVE_VALUES:
                      errorMessage = 'Cannot add passenger: Invalid operation';
                      break;
                    default:
                      errorMessage =
                          result.errorMessage ?? 'Unknown error occurred';
                  }

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(errorMessage),
                      backgroundColor: errorColor,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              },
              canIncrement: true, // Standing capacity can be incremented
              onDecrementTap: () async {
                // Decrement standing capacity by 1 when decrement button is tapped
                final result =
                    await PassengerCapacity().manualDecrementStanding(context);

                if (result.success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Standing passenger removed manually'),
                      backgroundColor: Colors.red,
                      duration: Duration(seconds: 2),
                    ),
                  );
                } else {
                  // Show specific error message based on error type
                  String errorMessage = 'Failed to remove passenger';
                  Color errorColor = Colors.red;

                  switch (result.errorType) {
                    case PassengerCapacity.ERROR_DRIVER_NOT_DRIVING:
                      errorMessage =
                          'Cannot remove passenger: Driver is not in Driving status';
                      break;
                    case PassengerCapacity.ERROR_NEGATIVE_VALUES:
                      errorMessage = 'Cannot remove: No standing passengers';
                      errorColor = Colors.grey;
                      break;
                    default:
                      errorMessage =
                          result.errorMessage ?? 'Unknown error occurred';
                  }

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(errorMessage),
                      backgroundColor: errorColor,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              },
            ),

            // PASSENGER SITTING CAPACITY - Can be incremented manually
            FloatingCapacity(
              driverProvider: driverProvider,
              passengerCapacity: PassengerCapacity(),
              screenHeight: screenHeight,
              screenWidth: screenWidth,
              bottomPosition:
                  screenHeight * HomeConstants.capacitySittingBottomFraction,
              rightPosition:
                  screenWidth * HomeConstants.sideButtonRightFraction,
              icon: 'assets/svg/sitting.svg',
              text: passengerSitting.toString(),
              onTap: () async {
                // Increment sitting capacity by 1 when tapped
                final result =
                    await PassengerCapacity().manualIncrementSitting(context);

                if (result.success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Sitting passenger added manually'),
                      backgroundColor: Colors.blue,
                      duration: Duration(seconds: 2),
                    ),
                  );
                } else {
                  // Show specific error message based on error type
                  String errorMessage = 'Failed to add passenger';
                  Color errorColor = Colors.red;

                  switch (result.errorType) {
                    case PassengerCapacity.ERROR_DRIVER_NOT_DRIVING:
                      errorMessage =
                          'Cannot add passenger: Driver is not in Driving status';
                      break;
                    case PassengerCapacity.ERROR_CAPACITY_EXCEEDED:
                      errorMessage =
                          'Cannot add passenger: Maximum capacity reached';
                      errorColor = Colors.orange;
                      break;
                    case PassengerCapacity.ERROR_NEGATIVE_VALUES:
                      errorMessage = 'Cannot add passenger: Invalid operation';
                      break;
                    default:
                      errorMessage =
                          result.errorMessage ?? 'Unknown error occurred';
                  }

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(errorMessage),
                      backgroundColor: errorColor,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              },
              canIncrement: true, // Sitting capacity can be incremented
              onDecrementTap: () async {
                // Decrement sitting capacity by 1 when decrement button is tapped
                final result =
                    await PassengerCapacity().manualDecrementSitting(context);

                if (result.success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Sitting passenger removed manually'),
                      backgroundColor: Colors.red,
                      duration: Duration(seconds: 2),
                    ),
                  );
                } else {
                  // Show specific error message based on error type
                  String errorMessage = 'Failed to remove passenger';
                  Color errorColor = Colors.red;

                  switch (result.errorType) {
                    case PassengerCapacity.ERROR_DRIVER_NOT_DRIVING:
                      errorMessage =
                          'Cannot remove passenger: Driver is not in Driving status';
                      break;
                    case PassengerCapacity.ERROR_NEGATIVE_VALUES:
                      errorMessage = 'Cannot remove: No sitting passengers';
                      errorColor = Colors.grey;
                      break;
                    default:
                      errorMessage =
                          result.errorMessage ?? 'Unknown error occurred';
                  }

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(errorMessage),
                      backgroundColor: errorColor,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              },
            ),

            ConfirmPickupButton(
              isVisible: _isNearPickupLocation && _nearestBookingId != null,
              onTap: () async {
                // Extracted original logic
                String seatType = 'Sitting';
                try {
                  final booking = passengerProvider.bookings.firstWhere(
                    (b) => b.id == _nearestBookingId,
                  );
                  seatType = booking.seatType;
                } catch (_) {}

                final success = await passengerProvider
                    .markBookingAsOngoing(_nearestBookingId!);
                if (success) {
                  final capacityResult = await PassengerCapacity()
                      .incrementCapacity(context, seatType);
                  if (capacityResult.success) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Passenger picked up successfully'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 2),
                    ));
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Failed to confirm passenger pickup'),
                    backgroundColor: Colors.red,
                    duration: Duration(seconds: 2),
                  ));
                }
              },
            ),

            CompleteRideButton(
              isVisible: _isNearDropoffLocation && _ongoingBookingId != null,
              onTap: () async {
                String seatType = 'Sitting';
                try {
                  final booking = passengerProvider.bookings.firstWhere(
                    (b) => b.id == _ongoingBookingId,
                  );
                  seatType = booking.seatType;
                } catch (_) {}

                final success = await passengerProvider
                    .markBookingAsCompleted(_ongoingBookingId!);
                if (success) {
                  final capacityResult = await PassengerCapacity()
                      .decrementCapacity(context, seatType);
                  if (capacityResult.success) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Ride completed successfully'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 2),
                    ));
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Failed to complete ride'),
                    backgroundColor: Colors.red,
                    duration: Duration(seconds: 2),
                  ));
                }
              },
            ),

            // Loading indicator overlay when fetching bookings
            if (_isLoadingBookings)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.2),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
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

            ResetCapacityButton(
              isVisible: passengerCapacity > 0 &&
                  _nearbyPassengers.isEmpty &&
                  driverStatus == 'Driving',
              onTap: () async {
                final shouldReset = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Reset Capacity'),
                    content: Text(
                      'Current capacity: $passengerCapacity passengers\n\nThis will reset all passenger counts to zero. Only use this if you have no passengers on board and the system is out of sync.',
                    ),
                    actions: [
                      TextButton(
                        child: const Text('Cancel'),
                        onPressed: () => Navigator.of(context).pop(false),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Reset'),
                        onPressed: () => Navigator.of(context).pop(true),
                      ),
                    ],
                  ),
                );

                if (shouldReset == true) {
                  final result =
                      await PassengerCapacity().resetCapacityToZero(context);
                  if (result.success) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Capacity reset to zero successfully'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 2),
                    ));
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(
                          'Failed to reset capacity: ${result.errorMessage}'),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 3),
                    ));
                  }
                }
              },
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

      if (passenger.booking.rideStatus == BookingConstants.statusAccepted) {
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
