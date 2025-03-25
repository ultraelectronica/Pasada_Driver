import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:pasada_driver_side/PassengerCapacity/passenger_capacity.dart';
import 'package:pasada_driver_side/driver_provider.dart';
import 'package:provider/provider.dart';

class ActivityPage extends StatefulWidget {
  const ActivityPage({super.key});

  @override
  ActivityPageState createState() => ActivityPageState();
}

class ActivityPageState extends State<ActivityPage> {
  int capacity = 1;
  Future<void> getPassengerCapacity() async {
    await PassengerCapacity().getPassengerCapacityToDB(context);
    
    setState(() {
      capacity = context.read<DriverProvider>().passengerCapacity!;
    });

    Fluttertoast.showToast(msg: 'Vehicle Capacity: ${capacity.toString()}');
    }

  @override
  void initState() {
    super.initState();
    // getPassengerCapacity();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Activity page'),
          const SizedBox(height: 30),
          ElevatedButton(
              onPressed: () {
                PassengerCapacity().getPassengerCapacityToDB(context);
              },
              child: const Text('sample')),
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
                capacity.toString(),
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
