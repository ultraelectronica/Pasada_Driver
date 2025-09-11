// ignore_for_file: non_constant_identifier_names, constant_identifier_names

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pasada_driver_side/domain/services/passenger_capacity.dart';
import 'package:pasada_driver_side/presentation/providers/passenger/passenger_provider.dart';
// booking constants used in controller/widgets
import 'package:pasada_driver_side/presentation/pages/map/map_page.dart';
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
import 'package:pasada_driver_side/presentation/pages/home/widgets/floating_refresh_booking_button.dart';
import 'package:pasada_driver_side/presentation/pages/home/widgets/floating_status_switch.dart';
import 'package:pasada_driver_side/presentation/pages/home/widgets/floating_route_button.dart';
import 'package:pasada_driver_side/presentation/pages/route_setup/route_selection_sheet.dart';
import 'package:pasada_driver_side/presentation/pages/home/widgets/seat_capacity_control.dart';
import 'package:pasada_driver_side/presentation/pages/home/widgets/total_capacity_indicator.dart';
import 'package:pasada_driver_side/presentation/pages/home/widgets/reset_capacity_button.dart';
import 'package:pasada_driver_side/presentation/pages/home/widgets/confirm_pickup_control.dart';
import 'package:pasada_driver_side/presentation/pages/home/widgets/complete_ride_control.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const HomePage(title: 'Pasada');
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.title});
  final String title;

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  //used to access MapPage
  final GlobalKey<MapPageState> mapScreenKey = GlobalKey<MapPageState>();

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

  // Whether we already showed the route selection prompt on first load
  bool _routePromptShown = false;

  // New: centralised controller holding timers & logic
  late HomeController _controller;

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

    // Delay timer start to ensure context is fully ready
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        // Initialize passenger capacity system only – controller handles the rest
        PassengerCapacity().initializeCapacity(context);
        // Show route selection prompt on first open
        if (!_routePromptShown) {
          _routePromptShown = true;
          final driverProv = context.read<DriverProvider>();
          final mapProv = context.read<MapProvider>();
          // Only prompt if no route is set. If loading, allow it to finish; if error, allow user to select.
          if (driverProv.routeID <= 0 || mapProv.routeState == RouteState.error) {
            // ignore: use_build_context_synchronously
            await RouteSelectionSheet.show(context);
          }
        }
        // Controller already starts its own timers and fetches; skip legacy setup
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
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

    final passengerCapacity =
        context.select<DriverProvider, int>((p) => p.passengerCapacity);
    final driverStatus =
        context.select<DriverProvider, String>((p) => p.driverStatus);

    return Scaffold(
      body: SizedBox(
        child: Stack(
          children: [
            MapPage(
              key: mapScreenKey,
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
                    _controller.handlePassengerSelected(passengerId);
                  },
                ),
              ),

            // FLOATING MESSAGE BUTTON
            FloatingRefreshBookingButton(
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

            // Floating Route Button (right side)
            FloatingRouteButton(
              screenHeight: screenHeight,
              screenWidth: screenWidth,
            ),

            // PASSENGER CAPACITY (TOTAL) - Just refreshes data
            TotalCapacityIndicator(
              screenHeight: screenHeight,
              screenWidth: screenWidth,
              bottomFraction: HomeConstants.capacityTotalBottomFraction,
              rightFraction: HomeConstants.sideButtonRightFraction,
            ),

            // PASSENGER STANDING CAPACITY - Can be incremented manually
            if (driverStatus == 'Driving')
              SeatCapacityControl(
                screenHeight: screenHeight,
                screenWidth: screenWidth,
                bottomFraction: HomeConstants.capacityStandingBottomFraction,
                rightFraction: HomeConstants.sideButtonRightFraction,
                seatType: 'Standing',
              ),

            // PASSENGER SITTING CAPACITY - Can be incremented manually
            if (driverStatus == 'Driving' ) 
              SeatCapacityControl(
              screenHeight: screenHeight,
              screenWidth: screenWidth,
              bottomFraction: HomeConstants.capacitySittingBottomFraction,
              rightFraction: HomeConstants.sideButtonRightFraction,
              seatType: 'Sitting',
            ),

            ConfirmPickupControl(
              isVisible: _isNearPickupLocation && _nearestBookingId != null,
              nearestBookingId: _nearestBookingId,
            ),

            CompleteRideControl(
              isVisible: _isNearDropoffLocation && _ongoingBookingId != null,
              ongoingBookingId: _ongoingBookingId,
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
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('Reset Capacity'),
                    content: Text(
                      'Current capacity: $passengerCapacity passengers\n\nThis will reset all passenger counts to zero. Only use this if you have no passengers on board and the system is out of sync.',
                    ),
                    actions: [
                      TextButton(
                        child: const Text('Cancel'),
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Reset'),
                        onPressed: () => Navigator.of(dialogContext).pop(true),
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
}
