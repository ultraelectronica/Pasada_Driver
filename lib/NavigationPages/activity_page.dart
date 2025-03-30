import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:pasada_driver_side/Database/driver_provider.dart';
import 'package:pasada_driver_side/Database/passenger_capacity.dart';
import 'package:pasada_driver_side/Database/driver_provider.dart';
import 'package:pasada_driver_side/Messages/message.dart';
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
    final driverProvider = context.watch<DriverProvider>();
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Activity page'),
          const SizedBox(height: 30),
          ElevatedButton(onPressed: () {}, child: const Text('sample')),
          const SizedBox(
            height: 20,
          ),
          Container(
            height: 50,
            width: 50,
            decoration: BoxDecoration(
                border: Border.all(width: 2),
                borderRadius: BorderRadius.circular(20)),
            child: Center(
              child: Text(
                driverProvider.passengerCapacity.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}
