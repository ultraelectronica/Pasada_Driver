import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pasada_driver_side/common/constants/booking_constants.dart';
import 'package:pasada_driver_side/UI/constants.dart';
import 'package:pasada_driver_side/UI/text_styles.dart';
import 'package:pasada_driver_side/data/models/booking_model.dart';

class BookingItem extends StatelessWidget {
  final Booking booking;

  const BookingItem({super.key, required this.booking});

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(booking.rideStatus);
    final statusIcon = _getStatusIcon(booking.rideStatus);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: statusColor, width: 2),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha:0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(statusIcon, color: statusColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Booking #${booking.id}',
                    style: Styles()
                        .textStyle(16, FontWeight.w600, Styles.customBlack)),
                const SizedBox(height: 4),
                _buildStatusChip(booking.rideStatus, statusColor),
                const SizedBox(height: 8),
                _buildLocationInfo('Pickup', booking.pickupLocation),
                const SizedBox(height: 4),
                _buildLocationInfo('Dropoff', booking.dropoffLocation),
                const SizedBox(height: 4),
                Text('Seat: ${booking.seatType}',
                    style: Styles()
                        .textStyle(12, FontWeight.w500, Colors.grey.shade600)),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade400),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(status.toUpperCase(),
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700, color: color)),
      );

  Widget _buildLocationInfo(String label, LatLng loc) => Text(
      '$label: (${loc.latitude.toStringAsFixed(4)}, ${loc.longitude.toStringAsFixed(4)})',
      style: Styles().textStyle(12, FontWeight.w400, Colors.grey.shade600));

  Color _getStatusColor(String status) {
    switch (status) {
      case BookingConstants.statusRequested:
        return Colors.orange;
      case BookingConstants.statusAccepted:
        return Colors.blue;
      case BookingConstants.statusOngoing:
        return Constants.GREEN_COLOR;
      case BookingConstants.statusCompleted:
        return Colors.green;
      case BookingConstants.statusCancelled:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case BookingConstants.statusRequested:
        return Icons.pending_actions;
      case BookingConstants.statusAccepted:
        return Icons.check_circle_outline;
      case BookingConstants.statusOngoing:
        return Icons.directions_car;
      case BookingConstants.statusCompleted:
        return Icons.done_all;
      case BookingConstants.statusCancelled:
        return Icons.cancel_outlined;
      default:
        return Icons.help_outline;
    }
  }
}
