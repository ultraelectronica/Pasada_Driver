import 'package:flutter/material.dart';
import 'package:pasada_driver_side/Database/driver_provider.dart';
import 'package:pasada_driver_side/Database/passenger_provider.dart';
import 'package:pasada_driver_side/Database/booking_model.dart';
import 'package:pasada_driver_side/Database/booking_constants.dart';
import 'package:pasada_driver_side/UI/constants.dart';
import 'package:pasada_driver_side/UI/text_styles.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Activity page showing driver statistics and booking information
class ActivityPage extends StatefulWidget {
  const ActivityPage({super.key});

  @override
  ActivityPageState createState() => ActivityPageState();
}

class ActivityPageState extends State<ActivityPage> {
  // State management
  bool _isRefreshing = false;
  String? _errorMessage;

  // Constants for UI layout
  static const double _topPadding = 0.155;
  static const double _horizontalPadding = 0.04;
  static const double _refreshButtonWidth = 0.6;
  static const double _refreshButtonHeight = 0.05;
  static const double _spacingRatio = 0.03;
  static const EdgeInsets _containerPadding = EdgeInsets.symmetric(
    horizontal: 5,
    vertical: 10,
  );

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  /// Initialize data with error handling
  void _initializeData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _fetchCompletedBookings();
      }
    });
  }

  /// Fetch completed bookings with error handling
  Future<void> _fetchCompletedBookings() async {
    try {
      if (!mounted) return;

      await context.read<PassengerProvider>().getCompletedBookings(context);

      if (mounted) {
        setState(() {
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load completed bookings: $e';
        });
      }
    }
  }

  /// Refresh all booking data
  Future<void> _refreshBookingData() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
      _errorMessage = null;
    });

    try {
      if (!mounted) return;

      // Use post-frame callbacks for state updates
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (mounted) {
          await Future.wait([
            context.read<PassengerProvider>().getBookingRequestsID(context),
            context.read<PassengerProvider>().getCompletedBookings(context),
          ]);
        }
      });

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Booking data refreshed successfully'),
            backgroundColor: Constants.GREEN_COLOR,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to refresh bookings: $e';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error refreshing data: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      body: SafeArea(
        child: _buildContent(screenSize),
      ),
    );
  }

  /// Build the main content with error handling
  Widget _buildContent(Size screenSize) {
    return Center(
      child: Padding(
        padding: EdgeInsets.only(
          top: screenSize.width * _topPadding,
          left: screenSize.width * _horizontalPadding,
          right: screenSize.width * _horizontalPadding,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildTitle(),
            SizedBox(height: screenSize.height * _spacingRatio),
            _buildBookingStats(screenSize),
            SizedBox(height: screenSize.height * 0.02),
            _buildRefreshButton(screenSize),
            if (_errorMessage != null) _buildErrorMessage(),
            SizedBox(height: screenSize.height * 0.022),
            Expanded(child: _buildBookingList()),
          ],
        ),
      ),
    );
  }

  /// Build the page title
  Widget _buildTitle() {
    return Text(
      'Driver Activity',
      style: Styles().textStyle(20, FontWeight.w600, Styles.customBlack),
    );
  }

  /// Build error message widget
  Widget _buildErrorMessage() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => setState(() => _errorMessage = null),
            color: Colors.red,
          ),
        ],
      ),
    );
  }

  /// Build the refresh button with loading state
  Widget _buildRefreshButton(Size screenSize) {
    return Container(
      width: screenSize.width * _refreshButtonWidth,
      height: screenSize.height * _refreshButtonHeight,
      decoration: BoxDecoration(
        border: Border.all(color: Constants.GREEN_COLOR, width: 2),
        borderRadius: BorderRadius.circular(50),
      ),
      child: TextButton.icon(
        onPressed: _isRefreshing ? null : _refreshBookingData,
        icon: _isRefreshing
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(Constants.GREEN_COLOR),
                ),
              )
            : const Icon(Icons.refresh),
        label: Text(
          _isRefreshing ? 'Refreshing...' : 'Refresh Bookings',
          style: Styles().textStyle(14, FontWeight.w400, Styles.customBlack),
        ),
      ),
    );
  }

  /// Build booking statistics with proper state management
  Widget _buildBookingStats(Size screenSize) {
    return Consumer2<PassengerProvider, DriverProvider>(
      builder: (context, passengerProvider, driverProvider, child) {
        final bookings = passengerProvider.bookings;
        final completedBooking = passengerProvider.completedBooking;
        final bookingCapacity = driverProvider.passengerCapacity;

        // Calculate different booking counts
        final requestedCount = bookings
            .where((booking) =>
                booking.rideStatus == BookingConstants.statusRequested)
            .length;

        final activeCount =
            bookings.where((booking) => booking.isActive).length;

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildStatCard(
              title: 'Completed\nBookings',
              value: completedBooking.toString(),
              color: Colors.green,
              icon: Icons.check_circle_outline,
            ),
            _buildStatCard(
              title: 'Active\nBookings',
              value: activeCount.toString(),
              color: Colors.blue,
              icon: Icons.directions_car,
            ),
            _buildStatCard(
              title: 'Requested\nBookings',
              value: requestedCount.toString(),
              color: Colors.orange,
              icon: Icons.pending_actions,
            ),
          ],
        );
      },
    );
  }

  /// Build individual stat card
  Widget _buildStatCard({
    required String title,
    required String value,
    required MaterialColor color,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: _containerPadding,
        decoration: BoxDecoration(
          color: color[50],
          border: Border.all(color: Constants.GREEN_COLOR, width: 2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color[700], size: 24),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style:
                  Styles().textStyle(13, FontWeight.w600, Styles.customBlack),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Styles().textStyle(28, FontWeight.w700, color[700]!),
            ),
          ],
        ),
      ),
    );
  }

  /// Build the booking list with better error handling
  Widget _buildBookingList() {
    return Consumer<PassengerProvider>(
      builder: (context, passengerProvider, child) {
        final bookings = passengerProvider.bookings;
        final isLoading = passengerProvider.isProcessingBookings;
        final error = passengerProvider.error;

        if (isLoading) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading bookings...'),
              ],
            ),
          );
        }

        if (error != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Error loading bookings',
                  style: Styles().textStyle(16, FontWeight.w600, Colors.red),
                ),
                const SizedBox(height: 8),
                Text(
                  error,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _refreshBookingData,
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (bookings.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox_outlined, size: 48, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No active bookings',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ClipRRect(
          child: ListView.separated(
            padding: const EdgeInsets.all(0),
            itemCount: bookings.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) => _buildBookingItem(bookings[index]),
          ),
        );
      },
    );
  }

  /// Build individual booking item with enhanced UI
  Widget _buildBookingItem(Booking booking) {
    Color statusColor = _getStatusColor(booking.rideStatus);
    IconData statusIcon = _getStatusIcon(booking.rideStatus);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: statusColor, width: 2),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
              color: statusColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(statusIcon, color: statusColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Booking #${booking.id}',
                  style: Styles()
                      .textStyle(16, FontWeight.w600, Styles.customBlack),
                ),
                const SizedBox(height: 4),
                _buildStatusChip(booking.rideStatus, statusColor),
                const SizedBox(height: 8),
                _buildLocationInfo('Pickup', booking.pickupLocation),
                const SizedBox(height: 4),
                _buildLocationInfo('Dropoff', booking.dropoffLocation),
                const SizedBox(height: 4),
                Text(
                  'Seat: ${booking.seatType}',
                  style: Styles()
                      .textStyle(12, FontWeight.w500, Colors.grey[600]!),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
        ],
      ),
    );
  }

  /// Build status chip
  Widget _buildStatusChip(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  /// Build location information
  Widget _buildLocationInfo(String label, LatLng location) {
    return Text(
      '$label: (${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)})',
      style: Styles().textStyle(12, FontWeight.w400, Colors.grey[600]!),
    );
  }

  /// Get status color based on booking status
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

  /// Get status icon based on booking status
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
