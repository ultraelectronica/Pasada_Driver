// ignore_for_file: non_constant_identifier_names, constant_identifier_names

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pasada_driver_side/domain/services/passenger_capacity.dart';
import 'package:pasada_driver_side/presentation/providers/passenger/passenger_provider.dart';
import 'package:pasada_driver_side/data/models/booking_model.dart';
import 'package:pasada_driver_side/common/constants/booking_constants.dart';
import 'package:pasada_driver_side/Map/google_map.dart';
import 'package:pasada_driver_side/presentation/providers/driver/driver_provider.dart';
import 'package:pasada_driver_side/presentation/providers/map_provider.dart';
import 'package:pasada_driver_side/UI/constants.dart';
import 'package:pasada_driver_side/UI/text_styles.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'package:flutter/scheduler.dart';
import 'package:pasada_driver_side/common/config/app_config.dart';
import 'package:pasada_driver_side/presentation/pages/home/models/passenger_status.dart';
import 'package:pasada_driver_side/presentation/pages/home/widgets/passenger_list_widget.dart';
import 'package:pasada_driver_side/presentation/pages/home/widgets/floating_message_button.dart';
import 'package:pasada_driver_side/presentation/pages/home/widgets/floating_status_switch.dart';
import 'package:pasada_driver_side/presentation/pages/home/widgets/floating_capacity.dart';
import 'package:pasada_driver_side/presentation/pages/home/utils/snackbar_utils.dart';
import 'package:flutter/widgets.dart';
import 'package:pasada_driver_side/presentation/pages/home/utils/home_constants.dart';

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

  // Track when notifications were last shown
  DateTime? _lastProximityNotificationTime;

  // Timer for proximity checks
  Timer? _proximityCheckTimer;

  // Timer for booking fetches (separate from proximity checks)
  Timer? _bookingFetchTimer;

  // Loading state for bookings fetch
  bool _isLoadingBookings = false;

  // Flag to track if booking stream has started
  bool _bookingStreamStarted = false;

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

    // Get current location
    final currentLocation = mapProvider.currentLocation;

    // Get all relevant bookings
    final acceptedBookings = passengerProvider.bookings
        .where(
            (booking) => booking.rideStatus == BookingConstants.statusAccepted)
        .toList();

    final ongoingBookings = passengerProvider.bookings
        .where(
            (booking) => booking.rideStatus == BookingConstants.statusOngoing)
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

      if (booking.rideStatus == BookingConstants.statusAccepted) {
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

    // Sort simply by distance - the closest booking is the most important
    passengerStatuses.sort((a, b) => a.distance.compareTo(b.distance));

    // Keep only the nearest passengers (configurable)
    if (passengerStatuses.length > HomeConstants.maxNearbyPassengers) {
      passengerStatuses =
          passengerStatuses.sublist(0, HomeConstants.maxNearbyPassengers);
    }

    // Determine if any notifications should be shown (not more often than every 15 seconds)
    final now = DateTime.now();
    final canShowNotification = _lastProximityNotificationTime == null ||
        now.difference(_lastProximityNotificationTime!).inSeconds >
            HomeConstants.proximityNotificationCooldownSeconds;

    if (canShowNotification && passengerStatuses.isNotEmpty) {
      // Just use the closest booking for notification
      final closestPassenger = passengerStatuses.first;

      // Only show notification if there's a status change
      bool shouldNotify = closestPassenger.isNearPickup ||
          closestPassenger.isNearDropoff ||
          closestPassenger.isApproachingPickup ||
          closestPassenger.isApproachingDropoff;

      if (shouldNotify) {
        _lastProximityNotificationTime = now;

        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            if (closestPassenger.isNearPickup) {
              // Arrived at pickup
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('You have arrived at a pickup location!'),
                  backgroundColor: Constants.GREEN_COLOR,
                  duration: const Duration(seconds: 3),
                ),
              );
            } else if (closestPassenger.isNearDropoff) {
              // Arrived at dropoff
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content:
                      const Text('You have arrived at a dropoff location!'),
                  backgroundColor: Colors.orange,
                  duration: const Duration(seconds: 3),
                ),
              );
            } else if (closestPassenger.isApproachingPickup) {
              // Approaching pickup
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      'Approaching pickup: ${closestPassenger.distance.toInt()} meters away'),
                  backgroundColor: Colors.blue,
                  duration: const Duration(seconds: 2),
                ),
              );
            } else if (closestPassenger.isApproachingDropoff) {
              // Approaching dropoff
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      'Approaching dropoff: ${closestPassenger.distance.toInt()} meters away'),
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

      // We no longer need a separate selection - always use the closest booking
      _selectedPassengerId = passengerStatuses.isNotEmpty
          ? passengerStatuses.first.booking.id
          : null;

      // Set action buttons based on the closest passenger
      if (_selectedPassengerId != null && passengerStatuses.isNotEmpty) {
        final closestPassenger = passengerStatuses.first;

        // Set action button visibility based on the closest booking
        if (closestPassenger.booking.rideStatus ==
            BookingConstants.statusAccepted) {
          _isNearPickupLocation = closestPassenger.isNearPickup;
          _isNearDropoffLocation = false;
          _nearestBookingId = closestPassenger.isNearPickup
              ? closestPassenger.booking.id
              : null;
          _ongoingBookingId = null;
        } else if (closestPassenger.booking.rideStatus ==
            BookingConstants.statusOngoing) {
          _isNearPickupLocation = false;
          _isNearDropoffLocation = closestPassenger.isNearDropoff;
          _nearestBookingId = null;
          _ongoingBookingId = closestPassenger.isNearDropoff
              ? closestPassenger.booking.id
              : null;
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
          if (!_bookingStreamStarted) {
            passengerProvider.startBookingStream(driverId);
            _bookingStreamStarted = true;
          }
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

    // Observe app lifecycle to pause/resume timers
    WidgetsBinding.instance.addObserver(this);

    // Delay timer start to ensure context is fully ready
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Initialize the passenger capacity system
        PassengerCapacity().initializeCapacity(context);

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
          if (!_bookingStreamStarted) {
            passengerProvider.startBookingStream(driverProvider.driverID);
            _bookingStreamStarted = true;
          }
        }
      }
    });
  }

  /// App lifecycle changes
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _proximityCheckTimer?.cancel();
      _bookingFetchTimer?.cancel();
    } else if (state == AppLifecycleState.resumed) {
      _startTimers();
    }
    super.didChangeAppLifecycleState(state);
  }

  void _startTimers() {
    // Restart proximity and fetch timers if not already active
    _proximityCheckTimer ??= Timer.periodic(
      Duration(seconds: AppConfig.proximityCheckInterval),
      (_) {
        if (mounted) {
          _checkProximity(context);
          _updateMapMarkers();
        }
      },
    );

    _bookingFetchTimer ??= Timer.periodic(
      Duration(seconds: AppConfig.periodicFetchInterval),
      (_) {
        if (mounted) {
          final driverProvider = context.read<DriverProvider>();
          if (driverProvider.driverStatus == 'Driving' && !_isLoadingBookings) {
            fetchBookings(context);
          }
        }
      },
    );
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

    WidgetsBinding.instance.removeObserver(this);
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
              bottomPosition: screenHeight * 0.1,
              rightPosition: screenWidth * 0.05,
              icon: 'assets/svg/people.svg',
              text: driverProvider.passengerCapacity.toString(),
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
              bottomPosition: screenHeight * 0.175,
              rightPosition: screenWidth * 0.05,
              icon: 'assets/svg/standing.svg',
              text: driverProvider.passengerStandingCapacity.toString(),
              onTap: () async {
                // Increment standing capacity by 1 when tapped
                final result =
                    await PassengerCapacity().manualIncrementStanding(context);

                if (result.success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Standing passenger added manually'),
                      backgroundColor: Colors.blue,
                      duration: const Duration(seconds: 2),
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
                    SnackBar(
                      content:
                          const Text('Standing passenger removed manually'),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 2),
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
              bottomPosition: screenHeight * 0.25,
              rightPosition: screenWidth * 0.05,
              icon: 'assets/svg/sitting.svg',
              text: driverProvider.passengerSittingCapacity.toString(),
              onTap: () async {
                // Increment sitting capacity by 1 when tapped
                final result =
                    await PassengerCapacity().manualIncrementSitting(context);

                if (result.success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Sitting passenger added manually'),
                      backgroundColor: Colors.blue,
                      duration: const Duration(seconds: 2),
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
                    SnackBar(
                      content: const Text('Sitting passenger removed manually'),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 2),
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

            // CONFIRM PICKUP BUTTON - only shown when near pickup location and a passenger is selected
            if (_isNearPickupLocation && _nearestBookingId != null)
              Positioned(
                bottom: screenHeight * 0.025,
                left: screenWidth * 0.2,
                right: screenWidth * 0.2,
                child: Material(
                  elevation: 6,
                  borderRadius: BorderRadius.circular(15),
                  child: InkWell(
                    onTap: () async {
                      // Get the booking seat type BEFORE marking it as ongoing
                      String seatType =
                          'Sitting'; // Default to 'sitting' if booking not found

                      try {
                        // Attempt to find the booking before any status changes
                        final booking = passengerProvider.bookings.firstWhere(
                          (b) => b.id == _nearestBookingId,
                        );
                        seatType = booking.seatType;
                        debugPrint(
                            'Found booking for pickup with seat type: $seatType');
                      } catch (e) {
                        debugPrint(
                            'Booking not found for pickup, using default seat type: $seatType');
                      }

                      // Mark booking as ongoing when driver confirms pickup
                      final success = await passengerProvider
                          .markBookingAsOngoing(_nearestBookingId!);
                      if (success) {
                        // Increment passenger capacity with the seat type
                        final capacityResult = await PassengerCapacity()
                            .incrementCapacity(context, seatType);

                        if (capacityResult.success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Passenger picked up successfully'),
                              backgroundColor: Colors.green,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        } else {
                          // Capacity update failed, log error but don't show to user
                          // as the booking status was already updated
                          debugPrint(
                              'Warning: Capacity update failed after pickup: ${capacityResult.errorMessage}');
                        }
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Failed to confirm passenger pickup'),
                            backgroundColor: Colors.red,
                            duration: Duration(seconds: 2),
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
                bottom: screenHeight * 0.025,
                left: screenWidth * 0.2,
                right: screenWidth * 0.2,
                child: Material(
                  elevation: 6,
                  borderRadius: BorderRadius.circular(15),
                  child: InkWell(
                    onTap: () async {
                      // Get the booking seat type BEFORE marking it as completed
                      // This prevents the "booking not found" error since bookings are removed after completion
                      String seatType =
                          'Sitting'; // Default to 'sitting' if booking not found

                      try {
                        // Attempt to find the booking before it's removed
                        final booking = passengerProvider.bookings.firstWhere(
                          (b) => b.id == _ongoingBookingId,
                        );
                        seatType = booking.seatType;
                        debugPrint('Found booking with seat type: $seatType');
                      } catch (e) {
                        debugPrint(
                            'Booking not found before completion, using default seat type: $seatType');
                      }

                      // Mark booking as completed when passenger reaches destination
                      final success = await passengerProvider
                          .markBookingAsCompleted(_ongoingBookingId!);
                      if (success) {
                        // Decrement passenger capacity using saved seat type
                        final capacityResult = await PassengerCapacity()
                            .decrementCapacity(context, seatType);

                        if (capacityResult.success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Ride completed successfully'),
                              backgroundColor: Colors.green,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        } else {
                          // Capacity update failed, log error but don't show to user
                          // as the booking status was already updated
                          debugPrint(
                              'Warning: Capacity update failed after dropoff: ${capacityResult.errorMessage}');
                        }
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to complete ride'),
                            backgroundColor: Colors.red,
                            duration: const Duration(seconds: 2),
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

            // RESET CAPACITY BUTTON - only shown when capacity is non-zero but no active bookings exist
            if (driverProvider.passengerCapacity > 0 &&
                _nearbyPassengers.isEmpty &&
                driverProvider.driverStatus == 'Driving')
              Positioned(
                bottom: screenHeight * 0.33,
                right: screenWidth * 0.05,
                child: Material(
                  elevation: 6,
                  borderRadius: BorderRadius.circular(15),
                  child: InkWell(
                    onTap: () async {
                      // Show confirmation dialog before resetting
                      final shouldReset = await showDialog<bool>(
                        context: context,
                        builder: (BuildContext context) => AlertDialog(
                          title: const Text('Reset Capacity'),
                          content: Text(
                            'Current capacity: ${driverProvider.passengerCapacity} passengers\n\n'
                            'This will reset all passenger counts to zero. '
                            'Only use this if you have no passengers on board and the system is out of sync.',
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
                        final result = await PassengerCapacity()
                            .resetCapacityToZero(context);

                        if (result.success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text(
                                  'Capacity reset to zero successfully'),
                              backgroundColor: Colors.green,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Failed to reset capacity: ${result.errorMessage}'),
                              backgroundColor: Colors.red,
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        }
                      }
                    },
                    borderRadius: BorderRadius.circular(15),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(15),
                        border:
                            Border.all(color: Colors.red.shade700, width: 2),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.refresh,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Reset\nCapacity',
                            textAlign: TextAlign.center,
                            style: Styles()
                                .textStyle(10, Styles.w600Weight, Colors.white),
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
