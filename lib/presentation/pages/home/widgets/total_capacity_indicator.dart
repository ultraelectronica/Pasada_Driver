import 'package:flutter/material.dart';
import 'package:pasada_driver_side/presentation/pages/home/widgets/floating_capacity.dart';
import 'package:provider/provider.dart';
import 'package:pasada_driver_side/presentation/providers/driver/driver_provider.dart';
import 'package:pasada_driver_side/domain/services/passenger_capacity.dart';
import 'package:pasada_driver_side/common/constants/text_styles.dart';
import 'package:pasada_driver_side/common/constants/constants.dart';
import 'package:pasada_driver_side/data/models/allowed_stop_model.dart';
import 'package:pasada_driver_side/data/models/manual_booking_data.dart';
import 'package:pasada_driver_side/data/repositories/supabase_manual_booking_repository.dart';
import 'package:pasada_driver_side/domain/services/fare_recalculation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pasada_driver_side/common/geo/location_service.dart';
import 'package:pasada_driver_side/presentation/pages/home/utils/snackbar_utils.dart';
import 'package:cherry_toast/resources/arrays.dart';
import 'package:pasada_driver_side/domain/services/seat_assignment_service.dart';

class TotalCapacityIndicator extends StatelessWidget {
  const TotalCapacityIndicator({
    super.key,
    required this.screenHeight,
    required this.screenWidth,
    required this.bottomFraction,
    required this.rightFraction,
  });

  final double screenHeight;
  final double screenWidth;
  final double bottomFraction;
  final double rightFraction;

  @override
  Widget build(BuildContext context) {
    final driverProvider = Provider.of<DriverProvider>(context, listen: false);
    final total =
        context.select<DriverProvider, int>((p) => p.passengerCapacity);

    return FloatingCapacity(
      driverProvider: driverProvider,
      passengerCapacity: PassengerCapacity(),
      screenHeight: screenHeight,
      screenWidth: screenWidth,
      bottomPosition: screenHeight * bottomFraction,
      rightPosition: screenWidth * rightFraction,
      icon: 'assets/svg/people.svg',
      text: total.toString(),
      canIncrement: false,
      onTap: () {
        _showManualAddPassengerBottomSheet(context);
      },
    );
  }

  // Method to show the bottom sheet
  void _showManualAddPassengerBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return const ManualAddPassengerSheet();
      },
    );
  }
}

// Separate StatefulWidget for the bottom sheet content
class ManualAddPassengerSheet extends StatefulWidget {
  const ManualAddPassengerSheet({super.key});

  @override
  State<ManualAddPassengerSheet> createState() =>
      _ManualAddPassengerSheetState();
}

class _ManualAddPassengerSheetState extends State<ManualAddPassengerSheet> {
  // State variables
  int regularCount = 0;
  int studentCount = 0;
  int seniorCount = 0;
  int pwdCount = 0;
  AllowedStop? selectedPickup;
  AllowedStop? selectedDestination;
  bool _isProcessing = false; // Prevent duplicate submissions

  final _manualBookingRepository = SupabaseManualBookingRepository();

  @override
  void initState() {
    super.initState();
    // Ensure stops are loaded when sheet opens
    _ensureStopsAreLoaded();
  }

  /// Check if stops are loaded, and if not, trigger loading
  Future<void> _ensureStopsAreLoaded() async {
    final driverProvider = Provider.of<DriverProvider>(context, listen: false);

    // If stops are empty and not currently loading, trigger the load
    if (driverProvider.cachedAllowedStops.isEmpty &&
        !driverProvider.isLoadingStops) {
      debugPrint('Manual booking sheet: Stops not loaded, triggering load...');
      await driverProvider.loadAndCacheAllowedStops();

      if (mounted) {
        debugPrint(
            'Manual booking sheet: Loaded ${driverProvider.cachedAllowedStops.length} stops');
      }
    } else {
      debugPrint(
          'Manual booking sheet: ${driverProvider.cachedAllowedStops.length} stops already cached');
    }
  }

  /// Calculate distance between pickup and destination in kilometers
  double? get tripDistanceInKm {
    if (selectedPickup == null || selectedDestination == null) {
      return null;
    }

    try {
      final pickupLatLng = LatLng(
        selectedPickup!.stopLat,
        selectedPickup!.stopLng,
      );
      final destinationLatLng = LatLng(
        selectedDestination!.stopLat,
        selectedDestination!.stopLng,
      );

      final distanceInMeters =
          LocationService.calculateDistance(pickupLatLng, destinationLatLng);

      if (!distanceInMeters.isFinite) {
        return null;
      }

      return distanceInMeters / 1000.0; // Convert to kilometers
    } catch (e) {
      debugPrint('Error calculating trip distance: $e');
      return null;
    }
  }

  /// Calculate base fare for the trip (without discounts)
  double get baseTripFare {
    final distance = tripDistanceInKm;

    if (distance == null || distance <= 0) {
      return FareService.baseFare; // Return minimum base fare
    }

    return FareService.calculateFare(distance).round().toDouble();
  }

  /// Calculate discounted fare (20% off for students, seniors, PWD)
  double get discountedTripFare {
    return FareService.applyDiscount(baseTripFare).round().toDouble();
  }

  /// Calculate total fare for all passengers
  double get totalFare {
    // Calculate fare based on distance and passenger types
    final regularFare = regularCount * baseTripFare;
    final discountedFare =
        (studentCount + seniorCount + pwdCount) * discountedTripFare;

    return regularFare + discountedFare;
  }

  /// Get seat assignment result based on current capacity and passenger counts
  SeatAssignmentResult? get seatAssignment {
    // Only calculate if we have passengers
    if (regularCount == 0 &&
        studentCount == 0 &&
        seniorCount == 0 &&
        pwdCount == 0) {
      return null;
    }

    final driverProvider = Provider.of<DriverProvider>(context, listen: false);

    return SeatAssignmentService.assignSeats(
      currentSitting: driverProvider.passengerSittingCapacity,
      currentStanding: driverProvider.passengerStandingCapacity,
      pwdCount: pwdCount,
      seniorCount: seniorCount,
      studentCount: studentCount,
      regularCount: regularCount,
    );
  }

  @override
  Widget build(BuildContext context) {
    final double height = MediaQuery.of(context).size.height * 0.048;

    // Get cached allowed stops from DriverProvider
    final driverProvider = Provider.of<DriverProvider>(context);
    final allowedStops = driverProvider.cachedAllowedStops;
    final isLoadingStops = driverProvider.isLoadingStops;

    return Container(
      constraints: BoxConstraints(
        maxHeight:
            MediaQuery.of(context).size.height * 0.85, // Max 85% of screen
      ),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 60,
                height: 7,
                decoration: BoxDecoration(
                  color: Colors.grey[500],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),

              // Title
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Manually Add Passenger',
                  style: Styles().textStyle(18, FontWeight.bold, Colors.black),
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Discount Type Section
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        children: [
                          Icon(Icons.discount,
                              color: Constants.GRADIENT_COLOR_1, size: 18),
                          const SizedBox(width: 5),
                          Text(
                            'Select Passenger Type(s):',
                            style: Styles().textStyle(
                                16, Styles.semiBold, Styles.customBlackFont),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Regular
                    _buildDiscountTypeRow('Regular', regularCount, false, () {
                      if (PassengerCapacity.MAX_TOTAL_CAPACITY >
                          regularCount +
                              studentCount +
                              seniorCount +
                              pwdCount) {
                        setState(() => regularCount++);
                      } else {
                        SnackBarUtils.showError(
                          context,
                          'Maximum capacity reached',
                          'You have reached the maximum capacity.',
                          position: Position.top,
                          animationType: AnimationType.fromTop,
                          duration: const Duration(seconds: 2),
                        );
                        return;
                      }
                    }, () {
                      if (regularCount > 0) setState(() => regularCount--);
                    }),

                    const SizedBox(height: 12),

                    // Student
                    _buildDiscountTypeRow('Student', studentCount, true, () {
                      if (PassengerCapacity.MAX_TOTAL_CAPACITY >
                          regularCount +
                              studentCount +
                              seniorCount +
                              pwdCount) {
                        setState(() => studentCount++);
                      } else {
                        SnackBarUtils.showError(
                          context,
                          'Maximum capacity reached',
                          'You have reached the maximum capacity.',
                          position: Position.top,
                          animationType: AnimationType.fromTop,
                          duration: const Duration(seconds: 2),
                        );
                        return;
                      }
                    }, () {
                      if (studentCount > 0) setState(() => studentCount--);
                    }),

                    const SizedBox(height: 12),

                    // Senior
                    _buildDiscountTypeRow('Senior', seniorCount, true, () {
                      if (PassengerCapacity.MAX_TOTAL_CAPACITY >
                          regularCount +
                              studentCount +
                              seniorCount +
                              pwdCount) {
                        setState(() => seniorCount++);
                      } else {
                        SnackBarUtils.showError(
                          context,
                          'Maximum capacity reached',
                          'You have reached the maximum capacity.',
                          position: Position.top,
                          animationType: AnimationType.fromTop,
                          duration: const Duration(seconds: 2),
                        );
                        return;
                      }
                    }, () {
                      if (seniorCount > 0) setState(() => seniorCount--);
                    }),

                    const SizedBox(height: 12),

                    // PWD
                    _buildDiscountTypeRow('PWD', pwdCount, true, () {
                      if (PassengerCapacity.MAX_TOTAL_CAPACITY >
                          regularCount +
                              studentCount +
                              seniorCount +
                              pwdCount) {
                        setState(() => pwdCount++);
                      } else {
                        SnackBarUtils.showError(
                          context,
                          'Maximum capacity reached',
                          'You have reached the maximum capacity.',
                          position: Position.top,
                          animationType: AnimationType.fromTop,
                          duration: const Duration(seconds: 2),
                        );
                        return;
                      }
                    }, () {
                      if (pwdCount > 0) setState(() => pwdCount--);
                    }),

                    const SizedBox(height: 24),

                    // // Seat Type Selection
                    // Padding(
                    //   padding: const EdgeInsets.symmetric(horizontal: 10),
                    //   child: Text(
                    //     'Select Seat Type:',
                    //     style: Styles()
                    //         .textStyle(16, FontWeight.w500, Colors.black),
                    //   ),
                    // ),
                    // const SizedBox(height: 12),

                    // Padding(
                    //   padding: const EdgeInsets.symmetric(horizontal: 10),
                    //   child: Row(
                    //     children: [
                    //       Expanded(
                    //         child: GestureDetector(
                    //           onTap: () {
                    //             setState(() => selectedSeatType = 'Sitting');
                    //           },
                    //           child: Container(
                    //             padding: const EdgeInsets.symmetric(
                    //                 vertical: 16, horizontal: 20),
                    //             decoration: BoxDecoration(
                    //               color: selectedSeatType == 'Sitting'
                    //                   ? Constants.GRADIENT_COLOR_1
                    //                   : Colors.white,
                    //               borderRadius: BorderRadius.circular(12),
                    //               border: Border.all(
                    //                 color: selectedSeatType == 'Sitting'
                    //                     ? Constants.GRADIENT_COLOR_1
                    //                     : Colors.grey[300]!,
                    //                 width: 2,
                    //               ),
                    //             ),
                    //             child: Row(
                    //               mainAxisAlignment: MainAxisAlignment.center,
                    //               children: [
                    //                 Icon(
                    //                   Icons.event_seat,
                    //                   color: selectedSeatType == 'Sitting'
                    //                       ? Colors.white
                    //                       : Colors.grey[700],
                    //                 ),
                    //                 const SizedBox(width: 8),
                    //                 Text(
                    //                   'Sitting',
                    //                   style: Styles().textStyle(
                    //                     16,
                    //                     FontWeight.w600,
                    //                     selectedSeatType == 'Sitting'
                    //                         ? Colors.white
                    //                         : Colors.grey[700]!,
                    //                   ),
                    //                 ),
                    //               ],
                    //             ),
                    //           ),
                    //         ),
                    //       ),
                    //       const SizedBox(width: 12),
                    //       Expanded(
                    //         child: GestureDetector(
                    //           onTap: () {
                    //             setState(() => selectedSeatType = 'Standing');
                    //           },
                    //           child: Container(
                    //             padding: const EdgeInsets.symmetric(
                    //                 vertical: 16, horizontal: 20),
                    //             decoration: BoxDecoration(
                    //               color: selectedSeatType == 'Standing'
                    //                   ? Constants.GRADIENT_COLOR_1
                    //                   : Colors.white,
                    //               borderRadius: BorderRadius.circular(12),
                    //               border: Border.all(
                    //                 color: selectedSeatType == 'Standing'
                    //                     ? Constants.GRADIENT_COLOR_1
                    //                     : Colors.grey[300]!,
                    //                 width: 2,
                    //               ),
                    //             ),
                    //             child: Row(
                    //               mainAxisAlignment: MainAxisAlignment.center,
                    //               children: [
                    //                 Icon(
                    //                   Icons.accessibility_new,
                    //                   color: selectedSeatType == 'Standing'
                    //                       ? Colors.white
                    //                       : Colors.grey[700],
                    //                 ),
                    //                 const SizedBox(width: 8),
                    //                 Text(
                    //                   'Standing',
                    //                   style: Styles().textStyle(
                    //                     16,
                    //                     FontWeight.w600,
                    //                     selectedSeatType == 'Standing'
                    //                         ? Colors.white
                    //                         : Colors.grey[700]!,
                    //                   ),
                    //                 ),
                    //               ],
                    //             ),
                    //           ),
                    //         ),
                    //       ),
                    //     ],
                    //   ),
                    // ),
                    // const SizedBox(height: 24),

                    // // Pickup Selection
                    // Padding(
                    //   padding: const EdgeInsets.symmetric(horizontal: 10),
                    //   child: Row(
                    //     children: [
                    //       Icon(Icons.place,
                    //           color: Constants.GRADIENT_COLOR_1, size: 18),
                    //       const SizedBox(width: 5),
                    //       Text(
                    //         'Select Pickup:',
                    //         style: Styles().textStyle(
                    //             16, Styles.semiBold, Styles.customBlackFont),
                    //       ),
                    //     ],
                    //   ),
                    // ),
                    // const SizedBox(height: 8),
                    // isLoadingStops
                    //     ? const Center(
                    //         child: Padding(
                    //           padding: EdgeInsets.all(16.0),
                    //           child: CircularProgressIndicator(),
                    //         ),
                    //       )
                    //     :
                    _buildStopDropdown(
                      label: 'Pick-up location',
                      value: selectedPickup,
                      items: _getAvailablePickups(allowedStops),
                      onChanged: (value) {
                        setState(() {
                          selectedPickup = value;
                          // Reset destination if it's before or same as pickup
                          if (selectedDestination != null &&
                              value != null &&
                              (selectedDestination!.stopOrder ?? 0) <=
                                  (value.stopOrder ?? 0)) {
                            selectedDestination = null;
                          }
                        });
                      },
                      isPickup: true,
                    ),

                    // const SizedBox(height: 16),

                    // // Destination Selection
                    // Padding(
                    //   padding: const EdgeInsets.symmetric(horizontal: 10),
                    //   child: Row(
                    //     children: [
                    //       const Icon(Icons.location_on,
                    //           color: Colors.red, size: 18),
                    //       const SizedBox(width: 5),
                    //       Text(
                    //         'Select Destination:',
                    //         style: Styles().textStyle(
                    //             16, Styles.semiBold, Styles.customBlackFont),
                    //       ),
                    //     ],
                    //   ),
                    // ),

                    SizedBox(
                      height: 1,
                      width: double.infinity,
                      child: Divider(
                        color: Constants.BLACK_COLOR.withAlpha(125),
                        thickness: 1,
                        indent: 15,
                        endIndent: 15,
                      ),
                    ),

                    isLoadingStops
                        ? Container(
                            height: MediaQuery.of(context).size.height * 0.045,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: Constants.WHITE_COLOR,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          )
                        : _buildStopDropdown(
                            label: 'Drop-off location',
                            value: selectedDestination,
                            items: _getAvailableDestinations(allowedStops),
                            onChanged: (value) =>
                                setState(() => selectedDestination = value),
                            isPickup: false,
                          ),

                    // Show info message if no stops are available after loading
                    if (!isLoadingStops && allowedStops.isEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: Colors.orange[200]!, width: 1),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline,
                                color: Colors.orange[700], size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'No stops configured',
                                    style: Styles().textStyle(14,
                                        FontWeight.bold, Colors.orange[900]!),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Route ${driverProvider.routeID} has no stops configured. Please contact admin.',
                                    style: Styles().textStyle(12,
                                        FontWeight.normal, Colors.orange[800]!),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 24),

                    // Trip Distance Display
                    // if (tripDistanceInKm != null)
                    //   Container(
                    //     padding: const EdgeInsets.all(12),
                    //     decoration: BoxDecoration(
                    //       color: Colors.blue[50],
                    //       borderRadius: BorderRadius.circular(8),
                    //       border:
                    //           Border.all(color: Colors.blue[200]!, width: 1),
                    //     ),
                    //     child: Row(
                    //       children: [
                    //         Icon(Icons.route,
                    //             color: Colors.blue[700], size: 20),
                    //         const SizedBox(width: 8),
                    //         Text(
                    //           'Distance: ${tripDistanceInKm!.toStringAsFixed(2)} km',
                    //           style: Styles().textStyle(
                    //               14, FontWeight.w500, Colors.blue[900]!),
                    //         ),
                    //       ],
                    //     ),
                    //   ),

                    // if (tripDistanceInKm != null) const SizedBox(height: 12),

                    // Fare Breakdown
                    if (selectedPickup != null && selectedDestination != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Constants.WHITE_COLOR,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Constants.BLACK_COLOR.withAlpha(125),
                              width: 1),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Fare Breakdown:',
                                  style: Styles().textStyle(
                                      14, Styles.bold, Styles.customBlackFont),
                                ),
                                Row(
                                  children: [
                                    Icon(Icons.route,
                                        color: Constants.BLACK_COLOR, size: 18),
                                    const SizedBox(width: 5),
                                    Text(
                                      'Distance:   ${tripDistanceInKm!.toStringAsFixed(2)} km',
                                      style: Styles().textStyle(14, Styles.bold,
                                          Styles.customBlackFont),
                                    ),
                                  ],
                                )
                              ],
                            ),
                            const SizedBox(height: 2),
                            SizedBox(
                              height: 8,
                              width: double.infinity,
                              child: Divider(
                                color: Constants.BLACK_COLOR.withAlpha(125),
                                thickness: 1,
                                indent: 5,
                                endIndent: 5,
                              ),
                            ),
                            if (regularCount > 0)
                              _buildFareBreakdownRow(
                                '$regularCount Regular',
                                baseTripFare * regularCount,
                              ),
                            if (studentCount > 0)
                              _buildFareBreakdownRow(
                                '$studentCount Student',
                                discountedTripFare * studentCount,
                                isDiscount: true,
                              ),
                            if (seniorCount > 0)
                              _buildFareBreakdownRow(
                                '$seniorCount Senior',
                                discountedTripFare * seniorCount,
                                isDiscount: true,
                              ),
                            if (pwdCount > 0)
                              _buildFareBreakdownRow(
                                '$pwdCount PWD',
                                discountedTripFare * pwdCount,
                                isDiscount: true,
                              ),
                          ],
                        ),
                      ),

                    if (selectedPickup != null && selectedDestination != null)
                      const SizedBox(height: 18),

                    // Seat Assignment Preview
                    if (seatAssignment != null && seatAssignment!.success)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: Colors.blue[200]!, width: 1),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.airline_seat_recline_normal,
                                    color: Colors.blue[700], size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'Seat Assignment:',
                                  style: Styles().textStyle(
                                      14, Styles.bold, Colors.blue[900]!),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (seatAssignment!.totalSitting > 0)
                              _buildSeatAssignmentRow(
                                'Sitting',
                                seatAssignment!.sittingAssignments!,
                                Icons.event_seat,
                                Constants.GRADIENT_COLOR_1,
                              ),
                            if (seatAssignment!.totalSitting > 0 &&
                                seatAssignment!.totalStanding > 0)
                              const SizedBox(height: 4),
                            if (seatAssignment!.totalStanding > 0)
                              _buildSeatAssignmentRow(
                                'Standing',
                                seatAssignment!.standingAssignments!,
                                Icons.accessibility_new,
                                Colors.orange[700]!,
                              ),
                            // Warning for priority passengers standing
                            if (seatAssignment!.hasPriorityInStanding)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.warning_amber,
                                        color: Colors.orange[700], size: 16),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        seatAssignment!.priorityWarningMessage!,
                                        style: Styles().textStyle(
                                            11,
                                            FontWeight.w500,
                                            Colors.orange[800]!),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),

                    if (seatAssignment != null && seatAssignment!.success)
                      const SizedBox(height: 18),

                    // Capacity Error Display
                    if (seatAssignment != null && !seatAssignment!.success)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 18),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red[300]!, width: 1),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline,
                                color: Colors.red[700], size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    seatAssignment!.errorMessage ??
                                        'Capacity Error',
                                    style: Styles().textStyle(
                                        14, FontWeight.bold, Colors.red[900]!),
                                  ),
                                  if (seatAssignment!.errorDetails != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        seatAssignment!.errorDetails!,
                                        style: Styles().textStyle(
                                            12,
                                            FontWeight.normal,
                                            Colors.red[800]!),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Total Fare
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            'Total Fare:',
                            style: Styles()
                                .textStyle(16, Styles.semiBold, Colors.black),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            '₱${totalFare.toStringAsFixed(2)}',
                            style: Styles()
                                .textStyle(18, FontWeight.bold, Colors.green),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Add Passenger Button
                    SizedBox(
                      width: double.infinity,
                      height: height,
                      child: ElevatedButton(
                        onPressed: _isProcessing ? null : _handleAddPassenger,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isProcessing
                              ? Colors.grey[400]
                              : Constants.GRADIENT_COLOR_2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          disabledBackgroundColor: Colors.grey[400],
                        ),
                        child: _isProcessing
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    'Processing...',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              )
                            : const Text(
                                'Add Passenger',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDiscountTypeRow(
    String label,
    int count,
    bool isHighlighted,
    VoidCallback onIncrement,
    VoidCallback onDecrement,
  ) {
    final double height = MediaQuery.of(context).size.height * 0.048;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Main container with label and count
        Expanded(
          child: SizedBox(
            height: height,
            child: Material(
              color: isHighlighted ? Constants.GRADIENT_COLOR_2 : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: isHighlighted
                    ? BorderSide.none
                    : BorderSide(color: Constants.GREY_COLOR, width: 2),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onIncrement,
                splashColor: Constants.GREEN_COLOR.withAlpha(77),
                highlightColor: Constants.GREEN_COLOR.withAlpha(26),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        label,
                        style: Styles().textStyle(
                            16,
                            Styles.semiBold,
                            isHighlighted
                                ? Styles.customWhiteFont
                                : Styles.customBlackFont),
                      ),
                      Text(
                        count.toString(),
                        style: Styles().textStyle(
                            18,
                            Styles.bold,
                            isHighlighted
                                ? Styles.customWhiteFont
                                : Styles.customBlackFont),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // remove passenger button
        SizedBox(
          width: height,
          height: height,
          child: Material(
            color: isHighlighted ? Constants.GRADIENT_COLOR_2 : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: isHighlighted
                  ? BorderSide.none
                  : BorderSide(color: Constants.GREY_COLOR, width: 2),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onDecrement,
              splashColor: Colors.red.withAlpha(77),
              highlightColor: Colors.red.withAlpha(26),
              child: Center(
                child: Icon(
                  Icons.person_remove,
                  color: isHighlighted ? Colors.white : Colors.grey[600],
                  size: 24,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Get available pickup stops (excludes the last stop which is the endpoint)
  List<AllowedStop> _getAvailablePickups(List<AllowedStop> allowedStops) {
    if (allowedStops.isEmpty) return allowedStops;

    // Find the maximum stop order
    final maxOrder = allowedStops
        .map((stop) => stop.stopOrder ?? 0)
        .reduce((a, b) => a > b ? a : b);

    // Return all stops except the one with the maximum order (endpoint)
    return allowedStops
        .where((stop) => (stop.stopOrder ?? 0) < maxOrder)
        .toList();
  }

  /// Get available destination stops (after the selected pickup)
  List<AllowedStop> _getAvailableDestinations(List<AllowedStop> allowedStops) {
    if (selectedPickup == null) {
      return allowedStops;
    }

    final pickupOrder = selectedPickup!.stopOrder ?? 0;
    return allowedStops
        .where((stop) => (stop.stopOrder ?? 0) > pickupOrder)
        .toList();
  }

  /// Build a single row in the fare breakdown display
  Widget _buildFareBreakdownRow(String label, double fare,
      {bool isDiscount = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                label,
                style:
                    Styles().textStyle(14, FontWeight.normal, Colors.black87),
              ),
              if (isDiscount)
                Container(
                  margin: const EdgeInsets.only(left: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '20% off',
                    style: Styles()
                        .textStyle(11, FontWeight.bold, Constants.GREEN_COLOR),
                  ),
                ),
            ],
          ),
          Text(
            '₱${fare.toStringAsFixed(2)}',
            style: Styles().textStyle(14, FontWeight.w600, Colors.black87),
          ),
        ],
      ),
    );
  }

  /// Build seat assignment row showing passenger type breakdown
  Widget _buildSeatAssignmentRow(
    String seatTypeLabel,
    PassengerTypeCount assignments,
    IconData icon,
    Color color,
  ) {
    final parts = <String>[];
    if (assignments.pwd > 0) parts.add('${assignments.pwd} PWD');
    if (assignments.senior > 0) parts.add('${assignments.senior} Senior');
    if (assignments.student > 0) parts.add('${assignments.student} Student');
    if (assignments.regular > 0) parts.add('${assignments.regular} Regular');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '$seatTypeLabel (${assignments.total}): ${parts.join(", ")}',
              style: Styles().textStyle(12, FontWeight.w500, Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStopDropdown({
    required String label,
    required AllowedStop? value,
    required List<AllowedStop> items,
    required Function(AllowedStop?) onChanged,
    required bool isPickup,
  }) {
    final double height = MediaQuery.of(context).size.height * 0.045;

    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Constants.WHITE_COLOR,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButton<AllowedStop>(
        value: value,
        isExpanded: true,
        underline: const SizedBox(),
        dropdownColor: Constants.GREY_COLOR,
        style: Styles().textStyle(16, Styles.semiBold, Styles.customBlackFont),
        icon: Icon(Icons.keyboard_arrow_down, color: Constants.BLACK_COLOR),
        // padding: const EdgeInsets.symmetric(horizontal: 0),
        menuWidth: MediaQuery.of(context).size.width * 0.75,
        borderRadius: BorderRadius.circular(12),
        alignment: Alignment.center,
        hint: Row(
          children: [
            Icon(isPickup ? Icons.location_on : Icons.location_on,
                color: isPickup ? Constants.GRADIENT_COLOR_1 : Colors.red,
                size: 25),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                items.isEmpty ? 'No stops available for this route' : label,
                style: Styles().textStyle(17, Styles.semiBold,
                    items.isEmpty ? Colors.grey[600]! : Styles.customBlackFont),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        items: items.map((AllowedStop stop) {
          return DropdownMenuItem<AllowedStop>(
            value: stop,
            child: Row(
              children: [
                Icon(Icons.location_on,
                    color: isPickup ? Constants.GRADIENT_COLOR_1 : Colors.red,
                    size: 25),
                const SizedBox(width: 8),
                Container(
                  width: 50,
                  height: height / 1.5,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Constants.WHITE_COLOR,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: Constants.BLACK_COLOR.withAlpha(125), width: 1),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    stop.stopOrder.toString(),
                    style: Styles()
                        .textStyle(17, Styles.semiBold, Styles.customBlackFont),
                  ),
                ),
                const SizedBox(
                  width: 15,
                ),
                Text(
                  stop.stopName,
                  overflow: TextOverflow.ellipsis,
                  style: Styles()
                      .textStyle(17, Styles.semiBold, Styles.customBlackFont),
                ),
              ],
            ),
          );
        }).toList(),
        onChanged: items.isEmpty ? null : onChanged,
      ),
    );
  }

  Future<void> _handleAddPassenger() async {
    // Prevent duplicate submissions
    if (_isProcessing) return;

    // Validate selections
    if (selectedPickup == null || selectedDestination == null) {
      SnackBarUtils.showError(
        context,
        'Please select pickup and destination',
        'Select locations before adding passengers',
        position: Position.top,
        animationType: AnimationType.fromTop,
        duration: const Duration(seconds: 2),
      );
      return;
    }

    // Validate at least one passenger is selected
    if (regularCount == 0 &&
        studentCount == 0 &&
        seniorCount == 0 &&
        pwdCount == 0) {
      SnackBarUtils.showError(
        context,
        'Please add at least one passenger',
        'Select passengers before adding them',
        position: Position.top,
        animationType: AnimationType.fromTop,
        duration: const Duration(seconds: 2),
      );
      return;
    }

    // Get driver information from provider
    final driverProvider = Provider.of<DriverProvider>(context, listen: false);
    final driverId = driverProvider.driverID;
    final routeId = driverProvider.routeID;

    if (driverId.isEmpty) {
      if (mounted) {
        SnackBarUtils.showError(
          context,
          'Driver ID not found.',
          'Please log in again',
          position: Position.top,
          animationType: AnimationType.fromTop,
          duration: const Duration(seconds: 2),
        );
        return;
      }
    }

    if (routeId <= 0) {
      if (mounted) {
        SnackBarUtils.showError(
          context,
          'Route not assigned.',
          'Select a route before adding passengers',
          position: Position.top,
          animationType: AnimationType.fromTop,
          duration: const Duration(seconds: 2),
        );
      }
      return;
    }

    // Refresh current capacity from the database so that seat assignment
    // always uses the latest sitting/standing counts (including online bookings)
    await PassengerCapacity().getPassengerCapacityToDB(context);

    // Calculate seat assignments based on priority and refreshed capacity
    final assignmentResult = SeatAssignmentService.assignSeats(
      currentSitting: driverProvider.passengerSittingCapacity,
      currentStanding: driverProvider.passengerStandingCapacity,
      pwdCount: pwdCount,
      seniorCount: seniorCount,
      studentCount: studentCount,
      regularCount: regularCount,
    );

    // Check for capacity errors
    if (!assignmentResult.success) {
      SnackBarUtils.showError(
        context,
        assignmentResult.errorMessage ?? 'Capacity Error',
        assignmentResult.errorDetails ?? 'Cannot add passengers',
        position: Position.top,
        animationType: AnimationType.fromTop,
        duration: const Duration(seconds: 3),
      );
      return;
    }

    debugPrint('=== Manual Booking - Seat Assignment ===');
    debugPrint('Sitting: ${assignmentResult.sittingAssignments}');
    debugPrint('Standing: ${assignmentResult.standingAssignments}');
    debugPrint('=========================================');

    // Set processing state to disable button and show loading
    setState(() {
      _isProcessing = true;
    });

    // Create bookings and track results
    int totalCreated = 0;
    int totalExpected = assignmentResult.totalPassengers;

    try {
      // Create sitting passenger bookings
      if (assignmentResult.totalSitting > 0) {
        final sittingBooking = ManualBookingData(
          regularCount: assignmentResult.sittingAssignments!.regular,
          studentCount: assignmentResult.sittingAssignments!.student,
          seniorCount: assignmentResult.sittingAssignments!.senior,
          pwdCount: assignmentResult.sittingAssignments!.pwd,
          pickupStop: selectedPickup!,
          destinationStop: selectedDestination!,
          seatType: 'Sitting',
          totalFare:
              _calculateFareForAssignment(assignmentResult.sittingAssignments!),
        );

        debugPrint(
            'Creating ${assignmentResult.totalSitting} sitting bookings...');
        final sittingCount =
            await _manualBookingRepository.createManualBookings(
          bookingData: sittingBooking,
          driverId: driverId,
          routeId: routeId,
        );
        totalCreated += sittingCount;
        debugPrint('Created $sittingCount sitting bookings');
      }

      // Create standing passenger bookings
      if (assignmentResult.totalStanding > 0) {
        final standingBooking = ManualBookingData(
          regularCount: assignmentResult.standingAssignments!.regular,
          studentCount: assignmentResult.standingAssignments!.student,
          seniorCount: assignmentResult.standingAssignments!.senior,
          pwdCount: assignmentResult.standingAssignments!.pwd,
          pickupStop: selectedPickup!,
          destinationStop: selectedDestination!,
          seatType: 'Standing',
          totalFare: _calculateFareForAssignment(
              assignmentResult.standingAssignments!),
        );

        debugPrint(
            'Creating ${assignmentResult.totalStanding} standing bookings...');
        final standingCount =
            await _manualBookingRepository.createManualBookings(
          bookingData: standingBooking,
          driverId: driverId,
          routeId: routeId,
        );
        totalCreated += standingCount;
        debugPrint('Created $standingCount standing bookings');
      }

      if (!mounted) return;

      // Handle results
      if (totalCreated == totalExpected) {
        // Success - update capacity BEFORE closing bottom sheet
        debugPrint(
            'Updating capacity: ${assignmentResult.totalSitting} sitting, ${assignmentResult.totalStanding} standing');

        if (assignmentResult.totalSitting > 0) {
          final sittingResult = await PassengerCapacity().incrementCapacityBulk(
            context,
            'Sitting',
            assignmentResult.totalSitting,
          );
          if (!sittingResult.success) {
            debugPrint(
                'Warning: Failed to update sitting capacity: ${sittingResult.errorMessage}');
          } else {
            debugPrint(
                'Successfully updated sitting capacity: +${assignmentResult.totalSitting}');
          }
        }

        if (assignmentResult.totalStanding > 0) {
          final standingResult =
              await PassengerCapacity().incrementCapacityBulk(
            context,
            'Standing',
            assignmentResult.totalStanding,
          );
          if (!standingResult.success) {
            debugPrint(
                'Warning: Failed to update standing capacity: ${standingResult.errorMessage}');
          } else {
            debugPrint(
                'Successfully updated standing capacity: +${assignmentResult.totalStanding}');
          }
        }

        // Close the bottom sheet AFTER capacity updates
        if (mounted) {
          Navigator.pop(context);
        }

        // Build success message with seat breakdown
        final seatSummary = SeatAssignmentService.generateAssignmentSummary(
          sitting: assignmentResult.sittingAssignments!,
          standing: assignmentResult.standingAssignments!,
        );

        if (mounted) {
          SnackBarUtils.showSuccess(
            context,
            'Bookings created successfully',
            '$totalCreated passenger(s) added\n$seatSummary\n${selectedPickup!.stopName} → ${selectedDestination!.stopName}',
            position: Position.top,
            animationType: AnimationType.fromTop,
            duration: const Duration(seconds: 4),
          );
        }
      } else if (totalCreated > 0) {
        // Partial success
        if (mounted) {
          Navigator.pop(context);
          SnackBarUtils.show(
            context,
            'Partial success',
            '$totalCreated of $totalExpected bookings created',
            backgroundColor: Colors.orange,
            position: Position.top,
            animationType: AnimationType.fromTop,
            duration: const Duration(seconds: 3),
          );
        }
      } else {
        // Failed
        if (mounted) {
          Navigator.pop(context);
          SnackBarUtils.showError(
            context,
            'Failed to create bookings',
            'Please try again',
            position: Position.top,
            animationType: AnimationType.fromTop,
            duration: const Duration(seconds: 3),
          );
        }
      }
    } catch (e) {
      debugPrint('Error in _handleAddPassenger: $e');

      if (!mounted) return;

      // Close the bottom sheet on error
      Navigator.pop(context);

      SnackBarUtils.showError(
        context,
        'Error creating bookings',
        e.toString(),
        position: Position.top,
        animationType: AnimationType.fromTop,
        duration: const Duration(seconds: 4),
      );
    } finally {
      // Always reset processing state
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  /// Calculate fare for a specific seat assignment
  double _calculateFareForAssignment(PassengerTypeCount assignment) {
    final regularFare = assignment.regular * baseTripFare;
    final discountedFare =
        (assignment.student + assignment.senior + assignment.pwd) *
            discountedTripFare;
    return regularFare + discountedFare;
  }
}
