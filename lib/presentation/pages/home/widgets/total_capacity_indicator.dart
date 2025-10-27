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
  String selectedSeatType = 'Sitting'; // Default to Sitting

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
                      setState(() => regularCount++);
                    }, () {
                      if (regularCount > 0) setState(() => regularCount--);
                    }),

                    const SizedBox(height: 12),

                    // Student
                    _buildDiscountTypeRow('Student', studentCount, true, () {
                      setState(() => studentCount++);
                    }, () {
                      if (studentCount > 0) setState(() => studentCount--);
                    }),

                    const SizedBox(height: 12),

                    // Senior
                    _buildDiscountTypeRow('Senior', seniorCount, true, () {
                      setState(() => seniorCount++);
                    }, () {
                      if (seniorCount > 0) setState(() => seniorCount--);
                    }),

                    const SizedBox(height: 12),

                    // PWD
                    _buildDiscountTypeRow('PWD', pwdCount, true, () {
                      setState(() => pwdCount++);
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
                        onPressed: _handleAddPassenger,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Constants.GRADIENT_COLOR_2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
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

    // Create the manual booking data object
    final bookingData = ManualBookingData(
      regularCount: regularCount,
      studentCount: studentCount,
      seniorCount: seniorCount,
      pwdCount: pwdCount,
      pickupStop: selectedPickup!,
      destinationStop: selectedDestination!,
      seatType: selectedSeatType,
      totalFare: totalFare,
    );

    // Log all the collected information (for debugging)
    debugPrint('=== Manual Booking Data ===');
    debugPrint('Total Passengers: ${bookingData.totalPassengers}');
    debugPrint('Regular: ${bookingData.regularCount}');
    debugPrint('Student: ${bookingData.studentCount}');
    debugPrint('Senior: ${bookingData.seniorCount}');
    debugPrint('PWD: ${bookingData.pwdCount}');
    debugPrint('---');
    debugPrint('Pickup: ${bookingData.pickupStop.stopName}');
    debugPrint('  - ID: ${bookingData.pickupStop.allowedStopId}');
    debugPrint('  - Address: ${bookingData.pickupStop.stopAddress}');
    debugPrint(
        '  - Location: ${bookingData.pickupStop.stopLat}, ${bookingData.pickupStop.stopLng}');
    debugPrint('  - Order: ${bookingData.pickupStop.stopOrder}');
    debugPrint('---');
    debugPrint('Destination: ${bookingData.destinationStop.stopName}');
    debugPrint('  - ID: ${bookingData.destinationStop.allowedStopId}');
    debugPrint('  - Address: ${bookingData.destinationStop.stopAddress}');
    debugPrint(
        '  - Location: ${bookingData.destinationStop.stopLat}, ${bookingData.destinationStop.stopLng}');
    debugPrint('  - Order: ${bookingData.destinationStop.stopOrder}');
    debugPrint('---');
    debugPrint('Total Fare: ₱${bookingData.totalFare.toStringAsFixed(2)}');
    debugPrint('Created At: ${bookingData.createdAt}');
    debugPrint('---');
    debugPrint('JSON Data:');
    debugPrint(bookingData.toJson().toString());
    debugPrint('===========================');

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

    // Show loading indicator (will be dismissed when operation completes)
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 16),
              Text('Creating bookings...'),
            ],
          ),
          duration: Duration(seconds: 10),
        ),
      );
    }

    // Save bookings to database
    try {
      final createdCount = await _manualBookingRepository.createManualBookings(
        bookingData: bookingData,
        driverId: driverId,
        routeId: routeId,
      );

      if (!mounted) return;

      // Dismiss loading indicator immediately
      ScaffoldMessenger.of(context).clearSnackBars();

      Navigator.pop(context); // Close the bottom sheet

      if (createdCount == bookingData.totalPassengers) {
        // Success - all bookings created

        // Update passenger capacity in one atomic operation (prevents race conditions)
        final capacityResult = await PassengerCapacity().incrementCapacityBulk(
          context,
          bookingData.seatType,
          bookingData.totalPassengers,
        );

        if (!capacityResult.success) {
          debugPrint(
              'Warning: Failed to update capacity: ${capacityResult.errorMessage}');
        }

        SnackBarUtils.showSuccess(
          context,
          'Bookings created successfully',
          '${bookingData.totalPassengers} ${bookingData.seatType} passenger(s): ${bookingData.pickupStop.stopName} → ${bookingData.destinationStop.stopName}',
          position: Position.top,
          animationType: AnimationType.fromTop,
          duration: const Duration(seconds: 3),
        );
      } else if (createdCount > 0) {
        // Partial success
        SnackBarUtils.show(
          context,
          'Partial success',
          '$createdCount of ${bookingData.totalPassengers} bookings created',
          backgroundColor: Colors.orange,
          position: Position.top,
          animationType: AnimationType.fromTop,
          duration: const Duration(seconds: 3),
        );
      } else {
        // Failed
        SnackBarUtils.showError(
          context,
          'Failed to create bookings',
          'Please try again',
          position: Position.top,
          animationType: AnimationType.fromTop,
          duration: const Duration(seconds: 3),
        );
      }
    } catch (e) {
      debugPrint('Error in _handleAddPassenger: $e');

      if (!mounted) return;

      // Dismiss loading indicator immediately
      ScaffoldMessenger.of(context).clearSnackBars();

      Navigator.pop(context); // Close the bottom sheet

      SnackBarUtils.showError(
        context,
        'Error creating bookings',
        e.toString(),
        position: Position.top,
        animationType: AnimationType.fromTop,
        duration: const Duration(seconds: 4),
      );
    }
  }
}
