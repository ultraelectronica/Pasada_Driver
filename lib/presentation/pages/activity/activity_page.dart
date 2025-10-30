import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pasada_driver_side/common/constants/constants.dart';
import 'package:pasada_driver_side/common/constants/text_styles.dart';
import 'package:pasada_driver_side/presentation/providers/quota/quota_provider.dart';
import 'package:pasada_driver_side/presentation/providers/booking_receipt/booking_receipt_provider.dart';
import 'package:pasada_driver_side/presentation/pages/booking_receipt/booking_receipt_detail_page.dart';
import 'package:provider/provider.dart';

class ActivityPage extends StatefulWidget {
  const ActivityPage({super.key});

  @override
  ActivityPageState createState() => ActivityPageState();
}

class ActivityPageState extends State<ActivityPage> {
  final NumberFormat _numberFormat = NumberFormat.decimalPattern();
  String _formatPeso(int value) => '₱${_numberFormat.format(value)}';

  @override
  void initState() {
    super.initState();
    // Trigger quota and booking receipt fetch after first frame to ensure providers are ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<QuotaProvider>().fetchQuota(context);
        context.read<BookingReceiptProvider>().fetchTodayBookings(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Read target quotas from provider
    final quotaProv = context.watch<QuotaProvider>();
    final int todayTargetEarnings = quotaProv.todayTargetQuota;
    final int weeklyTargetEarnings = quotaProv.weeklyTargetQuota;
    final int monthlyTargetEarnings = quotaProv.monthlyTargetQuota;

    final int todayEarnings = quotaProv.todayQuota;
    final int weeklyEarnings = quotaProv.weeklyQuota;
    final int monthlyEarnings = quotaProv.monthlyQuota;

    // Safe progress calculations
    final double todayProgress =
        todayTargetEarnings > 0 ? todayEarnings / todayTargetEarnings : 0.0;
    final double weeklyProgress =
        weeklyTargetEarnings > 0 ? weeklyEarnings / weeklyTargetEarnings : 0.0;
    final double monthlyProgress = monthlyTargetEarnings > 0
        ? monthlyEarnings / monthlyTargetEarnings
        : 0.0;
    return Scaffold(
      // backgroundColor: Colors.grey.shade300,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                //TODO: check for applicable gradient here in the future
                Colors.white,
                Colors.white
                // Color(0xFF88CB0C),
                // Color.fromARGB(255, 255, 255, 255),
              ]),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildTitle(),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Constants.BLACK_COLOR
                                    .withValues(alpha: 0.2),
                                width: 1),
                            // boxShadow: [
                            //   BoxShadow(
                            //     color: Constants.BLACK_COLOR.withValues(alpha: 0.1),
                            //     blurRadius: 15,
                            //     offset: const Offset(0, 15),
                            //   ),
                            // ],
                          ),
                          child: Column(
                            children: [
                              // Circular progress section
                              Container(
                                padding: const EdgeInsets.all(16),
                                child: _earningMetric(
                                  label: 'Today\'s Earnings',
                                  color: Constants.GREEN_COLOR,
                                  progress: todayProgress,
                                  currentEarnings: todayEarnings,
                                  targetEarnings: todayTargetEarnings,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),

                      //Weekly Earnings
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Constants.BLACK_COLOR
                                    .withValues(alpha: 0.2),
                                width: 1),
                            // boxShadow: [
                            //   BoxShadow(
                            //     color: Constants.BLACK_COLOR.withValues(alpha: 0.1),
                            //     blurRadius: 15,
                            //     offset: const Offset(0, 15),
                            //   ),
                            // ],
                          ),
                          child: Column(
                            children: [
                              // Circular progress section
                              Container(
                                padding: const EdgeInsets.all(16),
                                child: _earningMetric(
                                  label: 'Weekly Earnings',
                                  color: Colors.blue,
                                  progress: weeklyProgress,
                                  currentEarnings: weeklyEarnings,
                                  targetEarnings: weeklyTargetEarnings,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  //Monthly Earnings
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: Constants.BLACK_COLOR.withValues(alpha: 0.2),
                          width: 1),
                      // boxShadow: [
                      //   BoxShadow(
                      //     color: Constants.BLACK_COLOR.withValues(alpha: 0.1),
                      //     blurRadius: 15,
                      //     offset: const Offset(0, 15),
                      //   ),
                      // ],
                    ),
                    child: Column(
                      children: [
                        // Circular progress section
                        Container(
                          padding: const EdgeInsets.all(16),
                          child: _earningMetric(
                            label: 'Monthly Earnings',
                            color: Colors.red,
                            progress: monthlyProgress,
                            currentEarnings: monthlyEarnings,
                            targetEarnings: monthlyTargetEarnings,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Today\'s Bookings',
                          style: Styles().textStyle(
                              16, Styles.semiBold, Styles.customBlackFont)),
                      Consumer<BookingReceiptProvider>(
                        builder: (context, provider, child) {
                          return Text(
                            '${provider.todayBookingsCount} booking${provider.todayBookingsCount != 1 ? 's' : ''}',
                            style: Styles().textStyle(
                                14, Styles.medium, Colors.grey.shade600),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildBookingsList(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBookingsList() {
    return Consumer<BookingReceiptProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: Constants.BLACK_COLOR.withValues(alpha: 0.2),
                  width: 1),
            ),
            child: Center(
              child: CircularProgressIndicator(
                color: Constants.GREEN_COLOR,
              ),
            ),
          );
        }

        if (provider.hasError) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: Constants.BLACK_COLOR.withValues(alpha: 0.2),
                  width: 1),
            ),
            child: Column(
              children: [
                Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 12),
                Text(
                  provider.errorMessage ?? 'Failed to load bookings',
                  style: Styles()
                      .textStyle(14, Styles.medium, Styles.customBlackFont),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => provider.fetchTodayBookings(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Constants.GREEN_COLOR,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text('Retry',
                      style: Styles()
                          .textStyle(14, Styles.semiBold, Colors.white)),
                ),
              ],
            ),
          );
        }

        if (provider.todayBookings.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: Constants.BLACK_COLOR.withValues(alpha: 0.2),
                  width: 1),
            ),
            child: Column(
              children: [
                Icon(Icons.inbox_outlined,
                    color: Colors.grey.shade400, size: 64),
                const SizedBox(height: 16),
                Text(
                  'No bookings today',
                  style: Styles()
                      .textStyle(16, Styles.semiBold, Styles.customBlackFont),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your completed rides will appear here',
                  style: Styles()
                      .textStyle(14, Styles.medium, Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: Constants.BLACK_COLOR.withValues(alpha: 0.2),
                    width: 1),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(8),
                itemCount: provider.displayedBookings.length,
                separatorBuilder: (context, index) => Divider(
                  height: 1,
                  color: Colors.grey.shade200,
                ),
                itemBuilder: (context, index) {
                  final booking = provider.displayedBookings[index];
                  return _buildBookingItem(booking);
                },
              ),
            ),

            // Load More button
            if (provider.hasMoreBookings)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: InkWell(
                  onTap: provider.isLoadingMore
                      ? null
                      : () => provider.loadMoreBookings(),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Constants.GREEN_COLOR.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Constants.GREEN_COLOR.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (provider.isLoadingMore)
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Constants.GREEN_COLOR,
                            ),
                          )
                        else
                          Icon(
                            Icons.expand_more,
                            color: Constants.GREEN_COLOR,
                            size: 20,
                          ),
                        const SizedBox(width: 8),
                        Text(
                          provider.isLoadingMore
                              ? 'Loading...'
                              : 'Load ${provider.nextBatchCount} More (${provider.remainingBookingsCount} remaining)',
                          style: Styles().textStyle(
                            14,
                            Styles.semiBold,
                            Constants.GREEN_COLOR,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildBookingItem(booking) {
    final timeFormat = DateFormat('hh:mm a');
    final timeString = booking.createdAt != null
        ? timeFormat.format(booking.createdAt!)
        : booking.startTime ?? 'N/A';

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BookingReceiptDetailPage(booking: booking),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color:
                    _getStatusColor(booking.rideStatus).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.receipt_long,
                color: _getStatusColor(booking.rideStatus),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Booking #${booking.bookingId.substring(0, booking.bookingId.length > 8 ? 8 : booking.bookingId.length)}',
                    style: Styles()
                        .textStyle(14, Styles.semiBold, Styles.customBlackFont),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.access_time,
                          size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        timeString,
                        style: Styles()
                            .textStyle(12, Styles.medium, Colors.grey.shade600),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getStatusColor(booking.rideStatus)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          booking.rideStatus,
                          style: Styles().textStyle(10, Styles.medium,
                              _getStatusColor(booking.rideStatus)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  booking.fareString,
                  style: Styles()
                      .textStyle(16, Styles.bold, Constants.GREEN_COLOR),
                ),
                const SizedBox(height: 4),
                Icon(Icons.chevron_right,
                    color: Colors.grey.shade400, size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
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

  Widget _buildTitle() => SizedBox(
        width: double.infinity,
        child: Text('Driver Activity',
            style:
                Styles().textStyle(20, FontWeight.w600, Styles.customBlackFont),
            textAlign: TextAlign.center),
      );

  Widget _earningMetric({
    required String label,
    required Color color,
    required double progress,
    required int currentEarnings,
    required int targetEarnings,
  }) {
    double circleSize = 100;
    double strokeWidth = 18;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style:
              Styles().textStyle(14, Styles.semiBold, Styles.customBlackFont),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        // Circular progress indicator
        Stack(alignment: Alignment.center, children: [
          SizedBox(
            width: circleSize,
            height: circleSize,
            child: CircularProgressIndicator(
              value: 1,
              strokeWidth: strokeWidth,
              strokeCap: StrokeCap.round,
              valueColor:
                  AlwaysStoppedAnimation<Color>(color.withValues(alpha: 0.2)),
            ),
          ),
          SizedBox(
            width: circleSize,
            height: circleSize,
            child: CircularProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              strokeWidth: strokeWidth,
              strokeCap: StrokeCap.round,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          Column(
            children: [
              Text(
                _formatPeso(currentEarnings),
                style: Styles().textStyle(16, Styles.bold, color),
                textAlign: TextAlign.center,
              ),
              // Target earnings
              Text(
                '/${_formatPeso(targetEarnings)}',
                style: Styles()
                    .textStyle(12, Styles.medium, Styles.customBlackFont),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ]),
        const SizedBox(height: 15),
      ],
    );
  }
}
