import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pasada_driver_side/common/constants/constants.dart';
import 'package:pasada_driver_side/common/constants/text_styles.dart';
import 'package:pasada_driver_side/presentation/providers/driver/driver_provider.dart';
import 'package:pasada_driver_side/presentation/providers/quota/quota_provider.dart';
import 'package:pasada_driver_side/presentation/providers/booking_receipt/booking_receipt_provider.dart';
import 'package:pasada_driver_side/presentation/pages/booking_receipt/booking_receipt_detail_page.dart';
import 'package:pasada_driver_side/Services/pdf_service.dart';
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
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${provider.todayBookingsCount} booking${provider.todayBookingsCount != 1 ? 's' : ''}',
                                style: Styles().textStyle(
                                    14, Styles.medium, Colors.grey.shade600),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                tooltip: 'Export PDF',
                                onPressed: provider.isLoading
                                    ? null
                                    : () => _showExportDialog(),
                                icon: const Icon(Icons.download),
                                color: Constants.GREEN_COLOR,
                                splashRadius: 20,
                              ),
                              IconButton(
                                tooltip: 'Refresh',
                                onPressed: provider.isLoading
                                    ? null
                                    : () =>
                                        provider.fetchTodayBookings(context),
                                icon: provider.isLoading
                                    ? SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Constants.GREEN_COLOR,
                                        ),
                                      )
                                    : const Icon(Icons.refresh),
                                color: Constants.GREEN_COLOR,
                                splashRadius: 20,
                              ),
                            ],
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

            // Load More buttons
            if (provider.hasMoreBookings)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    // Load X More button
                    Expanded(
                      child: InkWell(
                        onTap: provider.isLoadingMore
                            ? null
                            : () => provider.loadMoreBookings(),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Constants.GREEN_COLOR.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color:
                                  Constants.GREEN_COLOR.withValues(alpha: 0.3),
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
                              Flexible(
                                child: Text(
                                  provider.isLoadingMore
                                      ? 'Loading...'
                                      : 'Load ${provider.nextBatchCount} More',
                                  style: Styles().textStyle(
                                    14,
                                    Styles.semiBold,
                                    Constants.GREEN_COLOR,
                                  ),
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Load All button
                    Expanded(
                      child: InkWell(
                        onTap: provider.isLoadingMore
                            ? null
                            : () => provider.showAllBookings(),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Constants.GREEN_COLOR,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Constants.GREEN_COLOR,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (provider.isLoadingMore)
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              else
                                const Icon(
                                  Icons.list_alt,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  provider.isLoadingMore
                                      ? 'Loading...'
                                      : 'Load All (${provider.remainingBookingsCount})',
                                  style: Styles().textStyle(
                                    14,
                                    Styles.semiBold,
                                    Colors.white,
                                  ),
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildBookingItem(booking) {
    final timeFormat = DateFormat('hh:mm a');
    // Database stores Philippines time as UTC, so don't convert
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
                    'Booking #${booking.bookingId}',
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

  /// Show export dialog to select date range
  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.download, color: Constants.GREEN_COLOR),
              const SizedBox(width: 12),
              Text(
                'Export Receipts',
                style:
                    Styles().textStyle(18, Styles.bold, Styles.customBlackFont),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Select the period for your receipt:',
                style:
                    Styles().textStyle(14, Styles.medium, Colors.grey.shade700),
              ),
              const SizedBox(height: 16),
              _buildExportOption(
                dialogContext,
                'Today',
                'Export today\'s bookings',
                Icons.today,
                () => _exportReceipts(dialogContext, 'daily'),
              ),
              const SizedBox(height: 12),
              _buildExportOption(
                dialogContext,
                'This Week',
                'Export this week\'s bookings',
                Icons.calendar_view_week,
                () => _exportReceipts(dialogContext, 'weekly'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                'Cancel',
                style: Styles()
                    .textStyle(14, Styles.semiBold, Colors.grey.shade600),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Build export option button
  Widget _buildExportOption(
    BuildContext dialogContext,
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Constants.GREEN_COLOR.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Constants.GREEN_COLOR, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Styles()
                        .textStyle(14, Styles.semiBold, Styles.customBlackFont),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Styles()
                        .textStyle(12, Styles.medium, Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios,
                size: 16, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  /// Export receipts for the selected period
  Future<void> _exportReceipts(
      BuildContext dialogContext, String reportType) async {
    Navigator.of(dialogContext).pop(); // Close dialog

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Constants.GREEN_COLOR),
              const SizedBox(height: 16),
              Text(
                'Generating PDF...',
                style: Styles()
                    .textStyle(14, Styles.semiBold, Styles.customBlackFont),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final receiptProvider = context.read<BookingReceiptProvider>();
      final driverProvider = context.read<DriverProvider>();

      // Fetch bookings based on report type
      if (reportType == 'daily') {
        await receiptProvider.fetchTodayBookings(context);
      } else if (reportType == 'weekly') {
        await receiptProvider.fetchThisWeekBookings(context);
      }

      final bookings = receiptProvider.todayBookings;

      if (bookings.isEmpty) {
        if (mounted) Navigator.of(context).pop(); // Close loading
        _showErrorDialog('No bookings found for the selected period.');
        return;
      }

      // Generate date range string
      final dateRange = _getDateRangeString(reportType);

      // Generate PDF
      final pdfFile = await PdfService.instance.generateBookingReceiptPdf(
        driverName: driverProvider.driverFullName ?? 'Driver',
        vehicleId: driverProvider.vehicleID,
        plateNumber: driverProvider.plateNumber,
        routeName: driverProvider.routeName,
        bookings: bookings,
        reportType: reportType,
        dateRange: dateRange,
      );

      if (mounted) Navigator.of(context).pop(); // Close loading

      if (pdfFile != null) {
        _showSuccessDialog(pdfFile.path);
      } else {
        _showErrorDialog('Failed to generate PDF. Please try again.');
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop(); // Close loading
      _showErrorDialog('Error: ${e.toString()}');
    }
  }

  /// Get date range string based on report type
  String _getDateRangeString(String reportType) {
    final now = DateTime.now();
    final formatter = DateFormat('MMM dd, yyyy');

    if (reportType == 'daily') {
      return formatter.format(now);
    } else if (reportType == 'weekly') {
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final endOfWeek = startOfWeek.add(const Duration(days: 6));
      return '${formatter.format(startOfWeek)} - ${formatter.format(endOfWeek)}';
    }
    return formatter.format(now);
  }

  /// Show success dialog with options to open or share PDF
  void _showSuccessDialog(String filePath) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Constants.GREEN_COLOR, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'PDF Generated!',
                  style: Styles()
                      .textStyle(18, Styles.bold, Styles.customBlackFont),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your receipt has been saved successfully!',
                style:
                    Styles().textStyle(14, Styles.medium, Colors.grey.shade700),
              ),
              const SizedBox(height: 8),
              Text(
                'Use the Share button below to send it via WhatsApp, Email, or save it to your preferred location.',
                style:
                    Styles().textStyle(12, Styles.medium, Colors.grey.shade600),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Constants.GREEN_COLOR.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Constants.GREEN_COLOR.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: Constants.GREEN_COLOR, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'File: ${filePath.split('/').last}',
                        style: Styles()
                            .textStyle(11, Styles.medium, Colors.grey.shade700),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Close',
                style: Styles()
                    .textStyle(14, Styles.semiBold, Colors.grey.shade600),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.of(context).pop();
                final file = File(filePath);
                await PdfService.instance.sharePdf(file);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Constants.GREEN_COLOR,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.share, size: 18, color: Colors.white),
              label: Text(
                'Share / Save',
                style: Styles().textStyle(14, Styles.semiBold, Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Show error dialog
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 32),
              const SizedBox(width: 12),
              Text(
                'Error',
                style:
                    Styles().textStyle(18, Styles.bold, Styles.customBlackFont),
              ),
            ],
          ),
          content: Text(
            message,
            style: Styles().textStyle(14, Styles.medium, Colors.grey.shade700),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'OK',
                style: Styles()
                    .textStyle(14, Styles.semiBold, Constants.GREEN_COLOR),
              ),
            ),
          ],
        );
      },
    );
  }
}
