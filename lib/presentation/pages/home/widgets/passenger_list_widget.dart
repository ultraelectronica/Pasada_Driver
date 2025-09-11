import 'package:flutter/material.dart';
import 'package:pasada_driver_side/presentation/pages/home/models/passenger_status.dart';
import 'package:pasada_driver_side/common/constants/booking_constants.dart';
import 'package:pasada_driver_side/UI/constants.dart';
import 'package:pasada_driver_side/UI/text_styles.dart';

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
          _buildHeader(context),
          const Divider(height: 1, thickness: 1, color: Colors.grey),
          _buildListSummary(context, sortedPassengers),
          if (sortedPassengers.isNotEmpty)
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: sortedPassengers.length,
              itemBuilder: (ctx, idx) =>
                  _buildCompactPassengerItem(ctx, sortedPassengers[idx]),
            ),
          if (passengers.isEmpty) _buildEmptyState(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: [
          Text(
            'Active Bookings',
            style:
                Styles().textStyle(15, Styles.w600Weight, Styles.customBlack),
          ),
          const Spacer(),
          Icon(Icons.swipe_down_alt, size: 16, color: Colors.grey[500]),
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
            style: Styles().textStyle(11, Styles.w700Weight, color),
          ),
          const SizedBox(width: 5),
          Text(
            count,
            style: Styles().textStyle(11, Styles.w700Weight, countColor),
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
          const Icon(Icons.not_listed_location, size: 16, color: Colors.grey),
          const SizedBox(width: 6),
          Text(
            'No active bookings',
            style: Styles().textStyle(12, Styles.w500Weight, Colors.grey),
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
                  ? Colors.blue.withValues(alpha: 0.05)
                  : Colors.orange.withValues(alpha: 0.05))
              : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: isSelected
                  ? statusColor
                  : (isPickup ? Colors.blue : Colors.orange),
              width: isSelected ? 3 : 2,
            ),
            bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.1), width: 1),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            // Status icon
            Container(
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
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
                    '#${passenger.booking.id}',
                    style: Styles()
                        .textStyle(13, Styles.w600Weight, Styles.customBlack),
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
                        style: Styles()
                            .textStyle(9, Styles.w700Weight, Colors.red),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Distance chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                formattedDistance,
                style: Styles().textStyle(14, Styles.w600Weight, statusColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.toInt()} m';
    final km = meters / 1000;
    return '${km.toStringAsFixed(1)} km';
  }
}
