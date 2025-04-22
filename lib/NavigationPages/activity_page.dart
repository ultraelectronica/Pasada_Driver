import 'package:flutter/material.dart';
import 'package:pasada_driver_side/Database/passenger_provider.dart';
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
    final bookingIDs = context.watch<PassengerProvider>().bookingIDs;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(screenWidth * 0.04),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            // First Container
            Container(
              padding: const EdgeInsets.all(20),
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.blue, width: 2),
                borderRadius: BorderRadius.circular(10),
              ),
              // CONTAINER CONTENT
              child: Text(
                bookingIDs.toString()
              ),
            ),

            const SizedBox(height: 20),
            TextButton(onPressed: 
                () {
                  // Call the method to get booking IDs
                  context.read<PassengerProvider>().getBookingIDs(context);
                }
            , child: Text('Check Booking IDs')),
          ],
        ),
      ),
    );
  }
}
