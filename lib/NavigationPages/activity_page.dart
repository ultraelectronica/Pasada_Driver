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

    final bookingDetails = context.watch<PassengerProvider>().bookingDetails;
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
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            // TITLE
            Text(
              'Driver Activity',
              style:
                  Styles().textStyle(20, FontWeight.w600, Styles.customBlack),
            ),

            SizedBox(height: screenHeight * 0.03),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // COMPLETED BOOKINGS
                Container(
                  padding: padding,
                  width: bookingContainerWidth,
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
                          style: Styles().textStyle(
                              30, FontWeight.w600, Styles.customBlack)),
                    ],
                  ),
                ),

                // ONGOING BOOKINGS
                Container(
                  padding: padding,
                  width: bookingContainerWidth,
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
                          style: Styles().textStyle(
                              30, FontWeight.w600, Styles.customBlack)),
                    ],
                  ),
                ),

                // REQUESTED BOOKINGS
                Container(
                  padding: padding,
                  width: bookingContainerWidth,
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
                      Text(bookingDetails.length.toString(),
                          style: Styles().textStyle(
                              30, FontWeight.w600, Styles.customBlack)),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: screenHeight * 0.02),

            // Refresh Button
            TextButton.icon(
              onPressed: () {
                // Use post-frame callbacks for state updates
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    context
                        .read<PassengerProvider>()
                        .getBookingRequestsID(context);
                    context
                        .read<PassengerProvider>()
                        .getCompletedBookings(context);
                  }
                });
              },
              icon: const Icon(Icons.refresh),
              label: Text('Refresh Bookings',
                  style: Styles()
                      .textStyle(14, FontWeight.w400, Styles.customBlack)),
            ),

            SizedBox(height: screenHeight * 0.01),

            // Booking List
            bookingList(bookingDetails),
          ],
        ),
      ),
    );
  }

  Expanded bookingList(List<BookingDetail> bookingDetails) {
    return Expanded(
      child: bookingDetails.isEmpty
          ? Center(
              child: Text(
                'No active bookings',
                style: Styles().textStyle(16, FontWeight.w400, Colors.grey),
              ),
            )
          : ListView.separated(
              itemCount: bookingDetails.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                return _buildBookingItem(bookingDetails[index]);
              },
            ),
    );
  }

  Widget _buildBookingItem(BookingDetail booking) {
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
                  'Booking ID: ${booking.bookingId}',
                  style: Styles()
                      .textStyle(14, FontWeight.w500, Styles.customBlack),
                ),
                // const SizedBox(height: 2),
                // Text(
                //   'Passenger ID: ${booking.passengerId}',
                //   style: Styles().textStyle(14, FontWeight.w400, Colors.grey[700]!),
                // ),
                const SizedBox(height: 2),
                Text(
                  'Status: ${booking.rideStatus}',
                  style: Styles()
                      .textStyle(14, FontWeight.w400, Colors.grey[700]!),
                ),
                const SizedBox(height: 2),
                Text(
                  'Pickup: (${booking.pickupLat.toStringAsFixed(2)}, ${booking.pickupLng.toStringAsFixed(2)})',
                  style: Styles()
                      .textStyle(12, FontWeight.w400, Colors.grey[700]!),
                ),
                Text(
                  'Dropoff: (${booking.dropoffLat.toStringAsFixed(2)}, ${booking.dropoffLng.toStringAsFixed(2)})',
                  style: Styles()
                      .textStyle(12, FontWeight.w400, Colors.grey[700]!),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
        ],
      ),
    );
  }
}
