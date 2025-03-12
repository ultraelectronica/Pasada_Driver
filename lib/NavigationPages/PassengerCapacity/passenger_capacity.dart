import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:pasada_driver_side/driver_provider.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PassengerCapacity {
  int capacity = 0;
  final SupabaseClient supabase = Supabase.instance.client;

  Future<void> getPassengerCapacityToDB(BuildContext context) async {
    try {
      final String? driverID = context.read<DriverProvider>().driverID;
      final String? vehicleID = context.read<DriverProvider>().vehicleID;

      if (vehicleID == null) {
        if (kDebugMode) {
          print('DriverID not fount');
        }
        return;
      }

      final getPassengerCapacity = await supabase
          .from('vehicleTable')
          .select('passengerCapacity')
          .eq('vehicleID', vehicleID)
          .single();

      print('Vehicle ID: $getPassengerCapacity');

      context
          .read<DriverProvider>()
          .setPassengerCapacity(getPassengerCapacity['passengerCapacity']);

      print(
          'provider vehicle capacity: ${context.read<DriverProvider>().passengerCapacity.toString()}');

      // Fluttertoast.showToast(msg: msg)
    } catch (e) {
      print('Error: $e');
    }
    // final response = await supabase
    //     .from('vechicleTable')
    //     .select('passengerCapacity')
    //     .eq('vehicleID', vehicleID)
    //     .single();
  }
}
