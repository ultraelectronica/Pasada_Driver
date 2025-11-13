// ignore_for_file: non_constant_identifier_names, constant_identifier_names

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pasada_driver_side/domain/services/passenger_capacity.dart';
import 'package:pasada_driver_side/presentation/providers/passenger/passenger_provider.dart';
// booking constants used in controller/widgets
import 'package:pasada_driver_side/presentation/pages/map/map_page.dart';
import 'package:pasada_driver_side/presentation/providers/driver/driver_provider.dart';
import 'package:pasada_driver_side/presentation/providers/map_provider.dart';
import 'package:pasada_driver_side/common/constants/constants.dart';
import 'package:pasada_driver_side/common/constants/text_styles.dart';
import 'package:provider/provider.dart';
import 'package:flutter/scheduler.dart';
import 'package:pasada_driver_side/presentation/pages/home/utils/home_constants.dart';
import 'package:pasada_driver_side/presentation/pages/home/controllers/home_controller.dart';
import 'package:pasada_driver_side/presentation/pages/home/models/passenger_status.dart';
import 'package:pasada_driver_side/presentation/pages/home/widgets/passenger_list_widget.dart';
// import 'package:pasada_driver_side/presentation/pages/home/widgets/floating_refresh_booking_button.dart';
import 'package:pasada_driver_side/presentation/pages/home/widgets/floating_start_driving_button.dart';
import 'package:pasada_driver_side/presentation/pages/home/widgets/floating_route_button.dart';
import 'package:pasada_driver_side/presentation/pages/route_setup/route_selection_sheet.dart';
import 'package:pasada_driver_side/presentation/pages/home/widgets/seat_capacity_control.dart';
import 'package:pasada_driver_side/presentation/pages/home/widgets/total_capacity_indicator.dart';
import 'package:pasada_driver_side/presentation/pages/home/widgets/reset_capacity_button.dart';
import 'package:pasada_driver_side/presentation/pages/home/widgets/confirm_pickup_control.dart';
import 'package:pasada_driver_side/presentation/pages/home/widgets/complete_ride_control.dart';
import 'package:pasada_driver_side/presentation/pages/home/utils/snackbar_utils.dart';
import 'package:cherry_toast/resources/arrays.dart';

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

  Future<void> _checkAndMaybeShowRoutePrompt() async {
    if (!mounted || _routePromptShown) return;
    final driverProv = context.read<DriverProvider>();
    final mapProv = context.read<MapProvider>();
    final state = mapProv.routeState;
    // Only prompt after route fetch completes, or if it errors.
    if (state == RouteState.loaded) {
      final bool noRouteLoaded =
          (mapProv.routeID <= 0) && (driverProv.routeID <= 0);
      if (noRouteLoaded) {
        _routePromptShown = true;
        await RouteSelectionSheet.show(context, isMandatory: true);
      }
    } else if (state == RouteState.error) {
      _routePromptShown = true;
      await RouteSelectionSheet.show(context, isMandatory: true);
    }
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

    // Delay to ensure context is ready, then initialize and perform an initial check
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      PassengerCapacity().initializeCapacity(context);
      await _checkAndMaybeShowRoutePrompt();
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
    // Watch route state so this widget rebuilds when it changes
    final _ = context.select<MapProvider, RouteState>((p) => p.routeState);
    // After each build, check if we should show the route prompt (guarded)
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _checkAndMaybeShowRoutePrompt();
    });

    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    final passengerCapacity = context
        .select<DriverProvider, int>((provider) => provider.passengerCapacity);
    final driverStatus = context
        .select<DriverProvider, String>((provider) => provider.driverStatus);

    return Scaffold(
      body: SizedBox(
        child: Stack(
          children: [
            MapPage(
              key: mapScreenKey,
            ),

            // PASSENGER LIST - shows top 3 nearest passengers
            if (driverStatus == 'Driving')
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

            // FLOATING REFRESH BOOKING BUTTON
            // FloatingRefreshBookingButton(
            //   screenHeight: screenHeight,
            //   screenWidth: screenWidth,
            //   isLoading: _isLoadingBookings,
            //   onRefresh: () => fetchBookings(context),
            // ),

            // Floating Start Driving Button
            if (driverStatus != 'Driving')
              FloatingStartDrivingButton(
                screenHeight: screenHeight,
                screenWidth: screenWidth,
              ),

            // Floating Route Button
            FloatingRouteButton(
              screenHeight: screenHeight,
              screenWidth: screenWidth,
            ),

            // PASSENGER CAPACITY (TOTAL) - Just refreshes data
            if (driverStatus == 'Driving')
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
            if (driverStatus == 'Driving')
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
                                16, Styles.semiBold, Styles.customBlackFont),
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
                    SnackBarUtils.showSuccess(
                      context,
                      'Capacity reset to zero successfully',
                      'All passenger counts have been reset to zero',
                      position: Position.top,
                      animationType: AnimationType.fromTop,
                    );
                  } else {
                    SnackBarUtils.showError(
                      context,
                      'Failed to reset capacity: ${result.errorMessage}',
                      'Please try again',
                    );
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
