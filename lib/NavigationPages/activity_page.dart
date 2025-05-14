import 'package:flutter/material.dart';
import 'package:pasada_driver_side/Database/driver_provider.dart';
import 'package:pasada_driver_side/Database/passenger_provider.dart';
import 'package:pasada_driver_side/UI/constants.dart';
import 'package:pasada_driver_side/UI/text_styles.dart';
import 'package:provider/provider.dart';

class ActivityPage extends StatefulWidget {
  const ActivityPage({super.key});

  @override
  ActivityPageState createState() => ActivityPageState();
}

class ActivityPageState extends State<ActivityPage> {
  @override
  void initState() {
    super.initState();
    // Use post-frame callback to avoid state updates during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<PassengerProvider>().getCompletedBookings(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final bookingContainerWidth = screenWidth * 0.28;
    const padding = EdgeInsets.symmetric(
      horizontal: 5,
      vertical: 10,
    );

    final bookings = context.watch<PassengerProvider>().bookings;
    final bookingCapacity = context.watch<DriverProvider>().passengerCapacity;
    final completedBooking =
        context.watch<PassengerProvider>().completedBooking;

    return Center(
      child: Padding(
        padding: EdgeInsets.only(
            top: screenWidth * 0.155,
            left: screenWidth * 0.04,
            right: screenWidth * 0.04),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // TITLE
            Text(
              'Driver Activity',
              style:
                  Styles().textStyle(20, FontWeight.w600, Styles.customBlack),
            ),

            SizedBox(height: screenHeight * 0.03),

            _buildBookingStats(padding, bookingContainerWidth, completedBooking,
                bookingCapacity, bookings),

            SizedBox(height: screenHeight * 0.02),

            _buildRefreshButton(screenWidth, screenHeight),

            SizedBox(height: screenHeight * 0.022),

            // Booking List
            Expanded(
              child: Container(
                child: bookingList(bookings),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRefreshButton(double screenWidth, double screenHeight) {
    return Container(
      width: screenWidth * 0.6,
      height: screenHeight * 0.05,
      decoration: BoxDecoration(
        border: Border.all(color: Constants.GREEN_COLOR, width: 2),
        borderRadius: BorderRadius.circular(50),
      ),
      child: TextButton.icon(
        onPressed: () {
          // Use post-frame callbacks for state updates
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              context.read<PassengerProvider>().getBookingRequestsID(context);
              context.read<PassengerProvider>().getCompletedBookings(context);
            }
          });
        },
        icon: const Icon(Icons.refresh),
        label: Text('Refresh Bookings',
            style: Styles().textStyle(14, FontWeight.w400, Styles.customBlack)),
      ),
    );
  }

  Row _buildBookingStats(EdgeInsets padding, double bookingContainerWidth,
      int completedBooking, int bookingCapacity, List<Booking> bookings) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // COMPLETED BOOKINGS
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: padding,
            decoration: BoxDecoration(
              color: Colors.green[50],
              border: Border.all(color: Constants.GREEN_COLOR, width: 2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Completed',
                  style: Styles()
                      .textStyle(15, FontWeight.w600, Styles.customBlack),
                ),
                Text(
                  'Bookings',
                  style: Styles()
                      .textStyle(15, FontWeight.w600, Styles.customBlack),
                ),
                const SizedBox(height: 8),
                Text(completedBooking.toString(),
                    style: Styles()
                        .textStyle(30, FontWeight.w600, Styles.customBlack)),
              ],
            ),
          ),
        ),

        // ONGOING BOOKINGS
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: padding,
            decoration: BoxDecoration(
              color: Colors.blue[50],
              border: Border.all(color: Constants.GREEN_COLOR, width: 2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Ongoing',
                  style: Styles()
                      .textStyle(15, FontWeight.w600, Styles.customBlack),
                ),
                Text(
                  'Bookings',
                  style: Styles()
                      .textStyle(15, FontWeight.w600, Styles.customBlack),
                ),
                const SizedBox(height: 8),
                Text(bookingCapacity.toString(),
                    style: Styles()
                        .textStyle(30, FontWeight.w600, Styles.customBlack)),
              ],
            ),
          ),
        ),

        // REQUESTED BOOKINGS
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(left: 8),
            padding: padding,
            decoration: BoxDecoration(
              color: Colors.orange[50],
              border: Border.all(color: Constants.GREEN_COLOR, width: 2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Requested',
                  style: Styles()
                      .textStyle(15, FontWeight.w600, Styles.customBlack),
                ),
                Text(
                  'Bookings',
                  style: Styles()
                      .textStyle(15, FontWeight.w600, Styles.customBlack),
                ),
                const SizedBox(height: 8),
                Text(bookings.length.toString(),
                    style: Styles()
                        .textStyle(30, FontWeight.w600, Styles.customBlack)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget bookingList(List<Booking> bookings) {
    return bookings.isEmpty
        ? Center(
            child: Text(
              'No active bookings',
              style: Styles().textStyle(16, FontWeight.w400, Colors.grey),
            ),
          )
        : ClipRRect(
            child: ListView.separated(
              padding: const EdgeInsets.all(0),
              itemCount: bookings.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                return _buildBookingItem(bookings[index]);
              },
            ),
          );
  }

  Widget _buildBookingItem(Booking booking) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Constants.GREEN_COLOR, width: 2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.bookmark, color: Constants.GREEN_COLOR),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Booking ID: ${booking.id}',
                  style: Styles()
                      .textStyle(14, FontWeight.w500, Styles.customBlack),
                ),
                const SizedBox(height: 2),
                // Text(
                //   'Passenger ID: ${booking.passengerId}',
                //   style: Styles()
                //       .textStyle(14, FontWeight.w400, Colors.grey[700]!),
                // ),
                const SizedBox(height: 2),
                Text(
                  'Status: ${booking.rideStatus}',
                  style: Styles()
                      .textStyle(14, FontWeight.w500, Colors.grey[700]!),
                ),
                const SizedBox(height: 2),
                Text(
                  'Pickup: (${booking.pickupLocation.latitude.toStringAsFixed(4)}, ${booking.pickupLocation.longitude.toStringAsFixed(4)})',
                  style: Styles()
                      .textStyle(12, FontWeight.w500, Colors.grey[700]!),
                ),
                Text(
                  'Dropoff: (${booking.dropoffLocation.latitude.toStringAsFixed(4)}, ${booking.dropoffLocation.longitude.toStringAsFixed(4)})',
                  style: Styles()
                      .textStyle(12, FontWeight.w500, Colors.grey[700]!),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[800]),
        ],
      ),
    );
  }
}
