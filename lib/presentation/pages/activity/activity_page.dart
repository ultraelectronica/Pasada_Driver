import 'package:flutter/material.dart';

// import 'package:provider/provider.dart';
// import 'package:pasada_driver_side/presentation/providers/driver/driver_provider.dart';
// import 'package:pasada_driver_side/presentation/providers/passenger/passenger_provider.dart';
// import 'package:pasada_driver_side/common/constants/booking_constants.dart';
import 'package:pasada_driver_side/common/constants/constants.dart';
import 'package:pasada_driver_side/common/constants/text_styles.dart';
// import 'utils/activity_constants.dart';
// import 'package:pasada_driver_side/presentation/pages/home/utils/snackbar_utils.dart';
// import 'widgets/stat_card.dart';
// import 'widgets/error_message_widget.dart';
// import 'widgets/refresh_button.dart';
// import 'widgets/booking_item.dart';

/// Activity page showing driver statistics and booking information.
/// Refactored into `presentation/pages/activity`.
class ActivityPage extends StatefulWidget {
  const ActivityPage({super.key});

  @override
  ActivityPageState createState() => ActivityPageState();
}

class ActivityPageState extends State<ActivityPage> {
  int todayEarnings = 200;
  int todayTargetEarnings = 1000;
  int weeklyEarnings = 1500;
  int weeklyTargetEarnings = 10000;
  int monthlyEarnings = 5000;
  int monthlyTargetEarnings = 10000;
  // State management
  // bool _isRefreshing = false;
  // String? _errorMessage;

  // UI layout constants moved to ActivityConstants
  // Container padding moved into StatCard widget

  @override
  void initState() {
    super.initState();
    // WidgetsBinding.instance.addPostFrameCallback((_) => _fetchCompleted());
  }

  // Future<void> _fetchCompleted() async {
  //   try {
  //     await context.read<PassengerProvider>().getCompletedBookings(context);
  //     if (!mounted) return;
  //     setState(() => _errorMessage = null);
  //   } catch (e) {
  //     if (!mounted) return;
  //     setState(() => _errorMessage = 'Failed to load completed bookings: $e');
  //   }
  // }

  // Future<void> _refreshBookingData() async {
  //   if (_isRefreshing) return;
  //   setState(() {
  //     _isRefreshing = true;
  //     _errorMessage = null;
  //   });

  //   try {
  //     await Future.wait([
  //       context.read<PassengerProvider>().getBookingRequestsID(context),
  //       context.read<PassengerProvider>().getCompletedBookings(context),
  //     ]);
  //     if (mounted) {
  //       SnackBarUtils.show(context, 'Booking data refreshed successfully',
  //           Constants.GREEN_COLOR);
  //     }
  //   } catch (e) {
  //     if (mounted) {
  //       _errorMessage = 'Failed to refresh bookings: $e';
  //       SnackBarUtils.show(context, 'Error refreshing data: $e', Colors.red,
  //           duration: const Duration(seconds: 3));
  //     }
  //   } finally {
  //     if (mounted) setState(() => _isRefreshing = false);
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: Colors.grey.shade300,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildTitle(),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: Constants.WHITE_COLOR,
                  borderRadius: BorderRadius.circular(20),
                  // border: Border.all(
                  //     color: Constants.BLACK_COLOR.withValues(alpha: 0.3),
                  //     width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Constants.BLACK_COLOR.withValues(alpha: 0.1),
                      blurRadius: 15,
                      offset: const Offset(0, 15),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Circular progress section
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: _buildCircularEarningProgress(
                          'Earning Progress',
                          todayEarnings,
                          todayTargetEarnings,
                          weeklyEarnings,
                          weeklyTargetEarnings,
                          monthlyEarnings,
                          monthlyTargetEarnings),
                    ),

                    // Earnings cards section
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildEarningsCard('Today\'s\nEarnings', 'Today',
                              todayEarnings, todayTargetEarnings),
                          _buildEarningsCard('Weekly\nEarnings', 'Weekly',
                              weeklyEarnings, weeklyTargetEarnings),
                          _buildEarningsCard('Monthly\nEarnings', 'Monthly',
                              monthlyEarnings, monthlyTargetEarnings),
                        ],
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

  Widget _buildEarningsCard(
      String title, String target, int earnings, int targetEarnings) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Row(
        children: [
          Column(
            children: [
              Text(
                title,
                style: Styles()
                    .textStyle(13, Styles.medium, Styles.customBlackFont),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                '₱$earnings',
                style: Styles().textStyle(
                    18,
                    FontWeight.w700,
                    target == 'Today'
                        ? Constants.GREEN_COLOR
                        : target == 'Weekly'
                            ? Colors.blue
                            : Colors.red),
                textAlign: TextAlign.center,
              ),
              Container(
                width: 50,
                height: 1,
                color: Constants.BLACK_COLOR,
              ),
              Text(
                '₱$targetEarnings',
                style: Styles()
                    .textStyle(14, FontWeight.w500, Styles.customBlackFont),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTitle() => SizedBox(
        width: double.infinity,
        child: Text('Driver Activity',
            style:
                Styles().textStyle(20, FontWeight.w600, Styles.customBlackFont),
            textAlign: TextAlign.center),
      );

  Widget _buildCircularEarningProgress(
      String title,
      int todayEarnings,
      int todayTargetEarnings,
      int weeklyEarnings,
      int weeklyTargetEarnings,
      int monthlyEarnings,
      int monthlyTargetEarnings) {
    // Sample data - replace with your actual data
    final progress = todayEarnings / todayTargetEarnings;
    final weeklyProgress = weeklyEarnings / weeklyTargetEarnings;
    final monthlyProgress = monthlyEarnings / monthlyTargetEarnings;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          title,
          style:
              Styles().textStyle(17, FontWeight.w600, Styles.customBlackFont),
        ),
        SizedBox(
          width: double.infinity,
          height: MediaQuery.of(context).size.height * 0.14,
          child: Stack(
            alignment: Alignment.center,
            children: [
              //Today's earning background
              SizedBox(
                width: 110,
                height: 110,
                child: CircularProgressIndicator(
                  value: 1,
                  strokeWidth: 15,
                  strokeCap: StrokeCap.round,
                  valueColor: AlwaysStoppedAnimation<Color>(
                      Constants.GREEN_COLOR.withValues(alpha: 0.1)),
                ),
              ),

              //Today's earning progress
              SizedBox(
                width: 110,
                height: 110,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 15,
                  strokeCap: StrokeCap.round,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(Constants.GREEN_COLOR),
                ),
              ),

              //Weekly earning progress background
              SizedBox(
                width: 75,
                height: 75,
                child: CircularProgressIndicator(
                  value: 1,
                  strokeWidth: 15,
                  strokeCap: StrokeCap.round,
                  valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.blue.withValues(alpha: 0.2)),
                ),
              ),

              //Weekly earning progress
              SizedBox(
                width: 75,
                height: 75,
                child: CircularProgressIndicator(
                  value: weeklyProgress,
                  strokeWidth: 15,
                  strokeCap: StrokeCap.round,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
              ),

              //Monthly earning progress background
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  value: 1,
                  strokeWidth: 15,
                  strokeCap: StrokeCap.round,
                  valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.red.withValues(alpha: 0.2)),
                ),
              ),

              //Monthly earning progress
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  value: monthlyProgress,
                  strokeWidth: 15,
                  strokeCap: StrokeCap.round,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.red),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Widget _buildContent(Size screenSize) {
  //   return Center(
  //     child: Padding(
  //       padding: EdgeInsets.only(
  //         top: screenSize.width * ActivityConstants.topPaddingFraction,
  //         left: screenSize.width * ActivityConstants.horizontalPaddingFraction,
  //         right: screenSize.width * ActivityConstants.horizontalPaddingFraction,
  //       ),
  //       child: Column(
  //         mainAxisAlignment: MainAxisAlignment.center,
  //         children: [
  //           _buildTitle(),
  //           SizedBox(
  //               height: screenSize.height * ActivityConstants.spacingRatio),
  //           _buildBookingStats(),
  //           SizedBox(
  //               height:
  //                   screenSize.height * ActivityConstants.smallSpacingHeight),
  //           RefreshButton(
  //             screenSize: screenSize,
  //             isRefreshing: _isRefreshing,
  //             onPressed: _refreshBookingData,
  //           ),
  //           if (_errorMessage != null)
  //             ErrorMessageWidget(
  //               message: _errorMessage!,
  //               onClose: () => setState(() => _errorMessage = null),
  //             ),
  //           SizedBox(
  //               height:
  //                   screenSize.height * ActivityConstants.tinySpacingHeight),
  //           Expanded(child: _buildBookingList()),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  // Legacy helper widgets have been extracted into dedicated widgets.

  // Widget _buildBookingStats() {
  //   return Consumer2<PassengerProvider, DriverProvider>(
  //     builder: (context, passengerProvider, driverProvider, _) {
  //       final bookings = passengerProvider.bookings;
  //       final completedBooking = passengerProvider.completedBooking;
  //       final requestedCount = bookings
  //           .where((b) => b.rideStatus == BookingConstants.statusRequested)
  //           .length;
  //       final activeCount = bookings.where((b) => b.isActive).length;

  //       return Row(
  //         mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //         children: [
  //           StatCard(
  //             title: 'Completed\nBookings',
  //             value: completedBooking.toString(),
  //             color: Colors.green,
  //             icon: Icons.check_circle_outline,
  //           ),
  //           StatCard(
  //             title: 'Active\nBookings',
  //             value: activeCount.toString(),
  //             color: Colors.blue,
  //             icon: Icons.directions_car,
  //           ),
  //           StatCard(
  //             title: 'Requested\nBookings',
  //             value: requestedCount.toString(),
  //             color: Colors.orange,
  //             icon: Icons.pending_actions,
  //           ),
  //         ],
  //       );
  //     },
  //   );
  // }

  // Widget _buildBookingList() {
  //   return Consumer<PassengerProvider>(
  //     builder: (context, passengerProvider, _) {
  //       final bookings = passengerProvider.bookings;
  //       if (passengerProvider.isProcessingBookings) {
  //         return const Center(child: CircularProgressIndicator());
  //       }
  //       if (passengerProvider.error != null) {
  //         return Center(
  //             child: Text('Error: ${passengerProvider.error}',
  //                 style: const TextStyle(color: Colors.red)));
  //       }
  //       if (bookings.isEmpty) {
  //         return const Center(child: Text('No active bookings'));
  //       }
  //       return ListView.separated(
  //         padding: EdgeInsets.zero,
  //         itemCount: bookings.length,
  //         separatorBuilder: (_, __) => const SizedBox(height: 10),
  //         itemBuilder: (_, i) => BookingItem(booking: bookings[i]),
  //       );
  //     },
  //   );
  // }
}
