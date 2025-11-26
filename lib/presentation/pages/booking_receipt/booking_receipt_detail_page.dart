import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pasada_driver_side/common/constants/constants.dart';
import 'package:pasada_driver_side/common/constants/text_styles.dart';
import 'package:pasada_driver_side/data/models/booking_receipt_model.dart';

class BookingReceiptDetailPage extends StatelessWidget {
  final BookingReceipt booking;

  const BookingReceiptDetailPage({
    super.key,
    required this.booking,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Constants.BLACK_COLOR),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Booking Receipt',
          style:
              Styles().textStyle(18, Styles.semiBold, Styles.customBlackFont),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Card with Status
            _buildHeaderCard(),
            const SizedBox(height: 16),

            // Booking Information
            _buildSectionCard(
              title: 'Booking Information',
              children: [
                _buildInfoRow('Booking ID', booking.bookingId),
                const Divider(height: 24),
                _buildInfoRow(
                  'Date & Time',
                  _formatDateTime(booking.createdAt ?? booking.assignedAt),
                ),
                if (booking.completedAt != null) ...[
                  const Divider(height: 24),
                  _buildInfoRow(
                    'Completed At',
                    _formatDateTime(booking.completedAt),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // Payment Details
            _buildSectionCard(
              title: 'Payment Details',
              children: [
                _buildInfoRow('Seat Type', booking.seatType),
                const Divider(height: 24),
                _buildInfoRow(
                  'Fare',
                  booking.fareString,
                  valueStyle: Styles().textStyle(
                    16,
                    Styles.bold,
                    Constants.GREEN_COLOR,
                  ),
                ),
                if (booking.paymentMethod != null) ...[
                  const Divider(height: 24),
                  _buildInfoRow('Payment Method', booking.paymentMethod!),
                ],
                if (booking.passengerType != null) ...[
                  const Divider(height: 24),
                  _buildInfoRow('Passenger Type', booking.passengerType!),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // Trip Details
            _buildSectionCard(
              title: 'Trip Details',
              children: [
                _buildLocationInfo(
                  icon: Icons.my_location,
                  iconColor: Constants.GREEN_COLOR,
                  label: 'Pick-up Address',
                  address: booking.pickupAddress ?? 'Not available',
                ),
                const SizedBox(height: 16),
                _buildLocationInfo(
                  icon: Icons.location_on,
                  iconColor: Colors.red,
                  label: 'Destination Address',
                  address: booking.dropoffAddress ?? 'Not available',
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Constants.BLACK_COLOR.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _getStatusColor().withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getStatusIcon(),
              size: 48,
              color: _getStatusColor(),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _getStatusText(),
            style: Styles().textStyle(18, Styles.bold, _getStatusColor()),
          ),
          const SizedBox(height: 8),
          Text(
            booking.fareString,
            style: Styles().textStyle(32, Styles.bold, Constants.GREEN_COLOR),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Constants.BLACK_COLOR.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Styles().textStyle(16, Styles.bold, Styles.customBlackFont),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value, {
    TextStyle? valueStyle,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Styles().textStyle(14, Styles.medium, Colors.grey.shade600),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: valueStyle ??
                Styles().textStyle(14, Styles.semiBold, Styles.customBlackFont),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationInfo({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String address,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style:
                    Styles().textStyle(12, Styles.medium, Colors.grey.shade600),
              ),
              const SizedBox(height: 4),
              Text(
                address,
                style: Styles()
                    .textStyle(14, Styles.semiBold, Styles.customBlackFont),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getStatusColor() {
    switch (booking.rideStatus.toLowerCase()) {
      case 'completed':
        return Constants.GREEN_COLOR;
      case 'ongoing':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon() {
    switch (booking.rideStatus.toLowerCase()) {
      case 'completed':
        return Icons.check_circle;
      case 'ongoing':
        return Icons.directions_bus;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }

  String _getStatusText() {
    return booking.rideStatus.toUpperCase();
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return 'N/A';
    final dateFormat = DateFormat('MMM dd, yyyy');
    final timeFormat = DateFormat('hh:mm a');
    return '${dateFormat.format(dateTime.toLocal())} at ${timeFormat.format(dateTime.toLocal())}';
  }
}
