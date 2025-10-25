import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:pasada_driver_side/presentation/pages/home/widgets/floating_capacity.dart';
import 'package:provider/provider.dart';
import 'package:pasada_driver_side/presentation/providers/driver/driver_provider.dart';
import 'package:pasada_driver_side/domain/services/passenger_capacity.dart';
import 'package:pasada_driver_side/common/constants/text_styles.dart';
import 'package:pasada_driver_side/common/constants/constants.dart';
import 'package:pasada_driver_side/data/models/allowed_stop_model.dart';
import 'package:pasada_driver_side/data/models/manual_booking_data.dart';
import 'package:pasada_driver_side/data/repositories/supabase_manual_booking_repository.dart';

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

  double get totalFare {
    // Calculate based on your fare logic
    return (regularCount * 15.0) +
        (studentCount * 12.0) +
        (seniorCount * 12.0) +
        (pwdCount * 12.0);
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
                      child: Text(
                        'Select Discount Type:',
                        style: Styles()
                            .textStyle(16, FontWeight.w500, Colors.black),
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

                    // Pickup Selection
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        'Select Pickup:',
                        style: Styles()
                            .textStyle(16, FontWeight.w500, Colors.black),
                      ),
                    ),
                    const SizedBox(height: 8),
                    isLoadingStops
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        : _buildStopDropdown(
                            label: 'Pickup',
                            value: selectedPickup,
                            items: allowedStops,
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
                          ),

                    const SizedBox(height: 16),

                    // Destination Selection
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        'Select Destination:',
                        style: Styles()
                            .textStyle(16, FontWeight.w500, Colors.black),
                      ),
                    ),

                    const SizedBox(height: 8),

                    isLoadingStops
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        : _buildStopDropdown(
                            label: 'Destination',
                            value: selectedDestination,
                            items: _getAvailableDestinations(allowedStops),
                            onChanged: (value) =>
                                setState(() => selectedDestination = value),
                          ),

                    const SizedBox(height: 24),

                    // Total Fare
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            'Total Fare:',
                            style: Styles()
                                .textStyle(16, FontWeight.w500, Colors.black),
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
                            18,
                            isHighlighted ? Styles.semiBold : Styles.normal,
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

  Widget _buildStopDropdown({
    required String label,
    required AllowedStop? value,
    required List<AllowedStop> items,
    required Function(AllowedStop?) onChanged,
  }) {
    final double height = MediaQuery.of(context).size.height * 0.048;

    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Constants.GRADIENT_COLOR_2,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButton<AllowedStop>(
        value: value,
        isExpanded: true,
        underline: const SizedBox(),
        dropdownColor: Constants.GRADIENT_COLOR_2,
        style: Styles().textStyle(16, FontWeight.w500, Styles.customWhiteFont),
        icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
        hint: Text(
          items.isEmpty ? 'No stops available' : 'Select $label...',
          style:
              Styles().textStyle(16, FontWeight.w500, Styles.customWhiteFont),
        ),
        items: items.map((AllowedStop stop) {
          return DropdownMenuItem<AllowedStop>(
            value: stop,
            child: Text(
              stop.stopName,
              overflow: TextOverflow.ellipsis,
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select pickup and destination'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate at least one passenger is selected
    if (regularCount == 0 &&
        studentCount == 0 &&
        seniorCount == 0 &&
        pwdCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one passenger'),
          backgroundColor: Colors.orange,
        ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Driver ID not found. Please log in again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (routeId <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Route not assigned. Please contact support.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Show loading indicator
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

        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '✓ Successfully added ${bookingData.totalPassengers} ${bookingData.seatType} passenger(s)\n${bookingData.pickupStop.stopName} → ${bookingData.destinationStop.stopName}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      } else if (createdCount > 0) {
        // Partial success
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Partially added: $createdCount of ${bookingData.totalPassengers} bookings created'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        // Failed
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to create bookings. Please try again.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error in _handleAddPassenger: $e');

      if (!mounted) return;

      Navigator.pop(context); // Close the bottom sheet

      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating bookings: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }
}
