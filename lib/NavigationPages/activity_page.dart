import 'package:flutter/material.dart';
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
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final bookingIDs = context.watch<PassengerProvider>().bookingIDs;

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

            // First Container
            Container(
              padding: const EdgeInsets.all(20),
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: Constants.GREEN_COLOR, width: 2),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              // CONTAINER CONTENT
              child: Text(bookingIDs.toString()),
            ),

            const SizedBox(height: 10),
            TextButton(
                onPressed: () {
                  // Call the method to get booking IDs
                  context.read<PassengerProvider>().getBookingIDs(context).toString();
                },
                child: Text('Check Booking IDs')),
          ],
        ),
      ),
    );
  }

  void _getIndividualPassengers() {
    
  }
}
