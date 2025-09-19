import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:pasada_driver_side/presentation/providers/driver/driver_provider.dart';
import 'package:pasada_driver_side/presentation/providers/passenger/passenger_provider.dart';
import 'package:pasada_driver_side/common/constants/booking_constants.dart';
import 'package:pasada_driver_side/common/constants/constants.dart';
import 'package:pasada_driver_side/common/constants/text_styles.dart';
import 'utils/activity_constants.dart';
import 'package:pasada_driver_side/presentation/pages/home/utils/snackbar_utils.dart';
import 'widgets/stat_card.dart';
import 'widgets/error_message_widget.dart';
import 'widgets/refresh_button.dart';
import 'widgets/booking_item.dart';

/// Activity page showing driver statistics and booking information.
/// Refactored into `presentation/pages/activity`.
class ActivityPage extends StatefulWidget {
  const ActivityPage({super.key});

  @override
  ActivityPageState createState() => ActivityPageState();
}

class ActivityPageState extends State<ActivityPage> {
  // State management
  bool _isRefreshing = false;
  String? _errorMessage;

  // UI layout constants moved to ActivityConstants
  // Container padding moved into StatCard widget

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchCompleted());
  }

  Future<void> _fetchCompleted() async {
    try {
      await context.read<PassengerProvider>().getCompletedBookings(context);
      if (!mounted) return;
      setState(() => _errorMessage = null);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Failed to load completed bookings: $e');
    }
  }

  Future<void> _refreshBookingData() async {
    if (_isRefreshing) return;
    setState(() {
      _isRefreshing = true;
      _errorMessage = null;
    });

    try {
      await Future.wait([
        context.read<PassengerProvider>().getBookingRequestsID(context),
        context.read<PassengerProvider>().getCompletedBookings(context),
      ]);
      if (mounted) {
        SnackBarUtils.show(context, 'Booking data refreshed successfully',
            Constants.GREEN_COLOR);
      }
    } catch (e) {
      if (mounted) {
        _errorMessage = 'Failed to refresh bookings: $e';
        SnackBarUtils.show(context, 'Error refreshing data: $e', Colors.red,
            duration: const Duration(seconds: 3));
      }
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      body: SafeArea(child: _buildContent(size)),
    );
  }

  Widget _buildContent(Size screenSize) {
    return Center(
      child: Padding(
        padding: EdgeInsets.only(
          top: screenSize.width * ActivityConstants.topPaddingFraction,
          left: screenSize.width * ActivityConstants.horizontalPaddingFraction,
          right: screenSize.width * ActivityConstants.horizontalPaddingFraction,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildTitle(),
            SizedBox(
                height: screenSize.height * ActivityConstants.spacingRatio),
            _buildBookingStats(),
            SizedBox(
                height:
                    screenSize.height * ActivityConstants.smallSpacingHeight),
            RefreshButton(
              screenSize: screenSize,
              isRefreshing: _isRefreshing,
              onPressed: _refreshBookingData,
            ),
            if (_errorMessage != null)
              ErrorMessageWidget(
                message: _errorMessage!,
                onClose: () => setState(() => _errorMessage = null),
              ),
            SizedBox(
                height:
                    screenSize.height * ActivityConstants.tinySpacingHeight),
            Expanded(child: _buildBookingList()),
          ],
        ),
      ),
    );
  }

  Widget _buildTitle() => Text('Driver Activity',
      style: Styles().textStyle(20, FontWeight.w600, Styles.customBlack));

  // Legacy helper widgets have been extracted into dedicated widgets.

  Widget _buildBookingStats() {
    return Consumer2<PassengerProvider, DriverProvider>(
      builder: (context, passengerProvider, driverProvider, _) {
        final bookings = passengerProvider.bookings;
        final completedBooking = passengerProvider.completedBooking;
        final requestedCount = bookings
            .where((b) => b.rideStatus == BookingConstants.statusRequested)
            .length;
        final activeCount = bookings.where((b) => b.isActive).length;

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            StatCard(
              title: 'Completed\nBookings',
              value: completedBooking.toString(),
              color: Colors.green,
              icon: Icons.check_circle_outline,
            ),
            StatCard(
              title: 'Active\nBookings',
              value: activeCount.toString(),
              color: Colors.blue,
              icon: Icons.directions_car,
            ),
            StatCard(
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

  Widget _buildBookingList() {
    return Consumer<PassengerProvider>(
      builder: (context, passengerProvider, _) {
        final bookings = passengerProvider.bookings;
        if (passengerProvider.isProcessingBookings) {
          return const Center(child: CircularProgressIndicator());
        }
        if (passengerProvider.error != null) {
          return Center(
              child: Text('Error: ${passengerProvider.error}',
                  style: const TextStyle(color: Colors.red)));
        }
        if (bookings.isEmpty) {
          return const Center(child: Text('No active bookings'));
        }
        return ListView.separated(
          padding: EdgeInsets.zero,
          itemCount: bookings.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => BookingItem(booking: bookings[i]),
        );
      },
    );
  }
}
