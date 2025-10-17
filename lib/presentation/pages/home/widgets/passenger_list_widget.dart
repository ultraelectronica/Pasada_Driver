import 'package:flutter/material.dart';
import 'package:pasada_driver_side/presentation/pages/home/controllers/id_acceptance_controller.dart';
import 'package:pasada_driver_side/presentation/pages/home/models/passenger_status.dart';
import 'package:pasada_driver_side/common/constants/booking_constants.dart';
import 'package:pasada_driver_side/common/constants/constants.dart';
import 'package:pasada_driver_side/common/constants/text_styles.dart';
import 'package:pasada_driver_side/common/constants/message.dart';
import 'package:pasada_driver_side/Services/id_image_fetch_service.dart';
import 'dart:typed_data';
import 'package:provider/provider.dart';
import 'package:pasada_driver_side/presentation/providers/map_provider.dart';

/// Widget to display the list of nearby passengers (top 3, sorted by distance).
class PassengerListWidget extends StatelessWidget {
  final List<PassengerStatus> passengers;
  final String? selectedPassengerId;
  final Function(String) onSelected;

  const PassengerListWidget({
    super.key,
    required this.passengers,
    this.selectedPassengerId,
    required this.onSelected,
  });

  // Helper to determine priority level (1-4)
  int _getPriorityLevel(PassengerStatus passenger) {
    if (passenger.isNearPickup || passenger.isNearDropoff) return 1; // Ready
    if (passenger.isApproachingPickup || passenger.isApproachingDropoff) {
      return 2; // Approaching
    }
    if (passenger.booking.rideStatus == BookingConstants.statusOngoing) {
      return 3; // Ongoing rides
    }
    return 4; // Accepted rides
  }

  @override
  Widget build(BuildContext context) {
    final routeName = context.select<MapProvider, String?>(
      (provider) => provider.routeName,
    );

    // Create a new list and sort by distance (ascending)
    final List<PassengerStatus> sortedPassengers = List.from(passengers)
      ..sort((a, b) => a.distance.compareTo(b.distance));

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 5,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          _buildHeader(context, routeName),
          const Divider(height: 1, thickness: 1, color: Colors.grey),

          // Total number of pickups and dropoffs
          _buildListSummary(context, sortedPassengers),
          if (sortedPassengers.isNotEmpty)
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: sortedPassengers.length,
              itemBuilder: (ctx, idx) =>
                  // Passenger item
                  _buildCompactPassengerItem(ctx, sortedPassengers[idx]),

              // Divider between items
              separatorBuilder: (ctx, idx) => Divider(
                height: 1,
                thickness: 1.5,
                color: Colors.grey.withValues(alpha: 1),
                indent: 10,
                endIndent: 10,
              ),
            ),
          if (passengers.isEmpty) _buildEmptyState(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String? routeName) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: [
          Text(
            'Active Bookings',
            style:
                Styles().textStyle(15, Styles.semiBold, Styles.customBlackFont),
          ),
          const Spacer(),
          Text(
            routeName == null || routeName.isEmpty
                ? 'No route selected'
                : routeName,
            style:
                Styles().textStyle(15, Styles.semiBold, Styles.customBlackFont),
          ),
          Icon(Icons.swipe_down_alt, size: 16, color: Colors.grey[600]),
        ],
      ),
    );
  }

  /// Summary pill showing pickup / drop-off counts.
  Widget _buildListSummary(
      BuildContext context, List<PassengerStatus> passengers) {
    final pickupCount = passengers
        .where((p) => p.booking.rideStatus == BookingConstants.statusAccepted)
        .length;
    final dropoffCount = passengers
        .where((p) => p.booking.rideStatus == BookingConstants.statusOngoing)
        .length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Row(
        children: [
          _buildCountChip(
            icon: Icons.person_pin_circle,
            color: Colors.green,
            label: 'PICKUPS: ',
            count: pickupCount.toString(),
            countColor: Colors.white,
          ),
          const SizedBox(width: 10),
          _buildCountChip(
            icon: Icons.location_on,
            color: Colors.orange,
            label: 'DROPOFFS: ',
            count: dropoffCount.toString(),
            countColor: Colors.white,
          ),
        ],
      ),
    );
  }

  Widget _buildCountChip({
    required IconData icon,
    required Color color,
    required String label,
    required String count,
    required Color countColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 5),
          Text(
            label,
            style: Styles().textStyle(11, Styles.bold, color),
          ),
          const SizedBox(width: 5),
          Text(
            count,
            style: Styles().textStyle(11, Styles.bold, countColor),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(15.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.not_listed_location,
              size: 20, color: Constants.BLACK_COLOR),
          const SizedBox(width: 6),
          Text(
            'No active bookings',
            style: Styles().textStyle(14, Styles.bold, Constants.BLACK_COLOR),
          ),
        ],
      ),
    );
  }

  // Individual passenger compact row
  Widget _buildCompactPassengerItem(
      BuildContext context, PassengerStatus passenger) {
    final bool isSelected = passenger.booking.id == selectedPassengerId;
    final bool isPickup =
        passenger.booking.rideStatus == BookingConstants.statusAccepted;

    // Determine status icon & color
    final (IconData statusIcon, Color statusColor) = () {
      if (isPickup) {
        if (passenger.isNearPickup) {
          return (Icons.place, Constants.GREEN_COLOR);
        }
        return (Icons.directions_car, Colors.blue);
      } else {
        if (passenger.isNearDropoff) {
          return (Icons.place, Colors.orange);
        }
        return (Icons.directions_car, Colors.orange);
      }
    }();

    final bool isUrgent = _getPriorityLevel(passenger) == 1;
    final String formattedDistance = _formatDistance(passenger.distance);

    return InkWell(
      onTap: () => onSelected(passenger.booking.id),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? (isPickup
                  ? Colors.blue.withValues(alpha: 0.2)
                  : Colors.orange.withValues(alpha: 0.2))
              : Colors.transparent,
          // border: Border(
          // left: BorderSide(
          //   color: isSelected
          //       ? statusColor
          //       : (isPickup ? Colors.blue : Colors.orange),
          //   width: isSelected ? 3 : 2,
          // ),
          // bottom: BorderSide(color: Colors.grey.withValues(alpha: 1), width: 1),
          // ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(
          children: [
            // Status icon
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.75),
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(4),
              child: Icon(statusIcon, color: statusColor, size: 14),
            ),
            const SizedBox(width: 8),
            // Booking id & urgent badge
            Expanded(
              child: Row(
                children: [
                  Text(
                    '# ${passenger.booking.id}',
                    style: Styles()
                        .textStyle(13, Styles.semiBold, Styles.customBlackFont),
                  ),
                  if (isUrgent) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'URGENT',
                        style: Styles().textStyle(9, Styles.bold, Colors.red),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // view ID button - only show if passenger has ID image
            if (passenger.booking.passengerIdImagePath != null &&
                passenger.booking.passengerIdImagePath!.isNotEmpty)
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  ShowMessage().showToast(
                      'View ID for passenger: ${passenger.booking.id}');
                  showIDDialog(context, passenger.booking.passengerIdImagePath!,
                      passenger.booking.id);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: .5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text(
                      'View ID',
                      style:
                          Styles().textStyle(14, Styles.semiBold, Colors.white),
                    ),
                  ),
                ),
              ),

            const SizedBox(width: 15),

            // Distance chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                formattedDistance,
                style: Styles()
                    .textStyle(14, Styles.semiBold, Constants.BLACK_COLOR),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void showIDDialog(
      BuildContext context, String passengerIdImagePath, String bookingId) {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        alignment: Alignment.center,
        title: Text(
          'Accept Passenger ID #$bookingId',
          style:
              Styles().textStyle(20, Styles.semiBold, Styles.customBlackFont),
          textAlign: TextAlign.center,
        ),
        content: FutureBuilder<Uint8List?>(
          future: _decryptImage(passengerIdImagePath),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 200,
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (snapshot.hasError) {
              return Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.red[400],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Failed to load ID image',
                        style: Styles().textStyle(
                          14,
                          Styles.medium,
                          Colors.red[600] ?? Colors.red,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Error: ${snapshot.error}',
                        style: Styles().textStyle(
                          12,
                          Styles.normal,
                          Colors.grey[600] ?? Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }

            if (snapshot.hasData && snapshot.data != null) {
              return Container(
                height: 300,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    snapshot.data!,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[200],
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.broken_image,
                                size: 48,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Invalid image format',
                                style: Styles().textStyle(
                                  14,
                                  Styles.medium,
                                  Colors.grey[600] ?? Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            }

            return Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  'No image data available',
                  style: Styles().textStyle(
                    14,
                    Styles.medium,
                    Colors.grey[600] ?? Colors.grey,
                  ),
                ),
              ),
            );
          },
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Decline ID button
              _buildDeclineIDButton(context, bookingId),
              // Accept ID button
              _buildAcceptIDButton(context, bookingId),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeclineIDButton(BuildContext context, String bookingId) {
    return GestureDetector(
      onTap: () async {
        try {
          await IdAcceptanceController().declineID(bookingId);
          Navigator.of(context).pop();
          ShowMessage().showToast('ID declined for booking #$bookingId');
        } catch (e) {
          Navigator.of(context).pop();
          ShowMessage().showToast('Failed to decline ID: $e');
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 5,
              offset: const Offset(1, 2),
            ),
          ],
        ),
        child: Text(
          'Decline',
          style: Styles().textStyle(16, Styles.bold, Constants.WHITE_COLOR),
        ),
      ),
    );
  }

  Widget _buildAcceptIDButton(BuildContext context, String bookingId) {
    return GestureDetector(
      onTap: () async {
        try {
          await IdAcceptanceController().acceptID(bookingId);
          Navigator.of(context).pop();
          ShowMessage().showToast('ID accepted for booking #$bookingId');
        } catch (e) {
          Navigator.of(context).pop();
          ShowMessage().showToast('Failed to accept ID: $e');
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
        decoration: BoxDecoration(
          color: Constants.GREEN_COLOR,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 5,
              offset: const Offset(1, 2),
            ),
          ],
        ),
        child: Text(
          'Accept',
          style: Styles().textStyle(16, Styles.bold, Constants.WHITE_COLOR),
        ),
      ),
    );
  }

  Future<Uint8List?> _decryptImage(String imageData) async {
    try {
      return await IdImageFetchService.fetchImageBytes(imageData);
    } catch (e) {
      debugPrint('Error processing image data: $e');
      rethrow;
    }
  }

  /// format distance from m to km
  String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.toInt()} m';
    final km = meters / 1000;
    return '${km.toStringAsFixed(1)} km';
  }
}
