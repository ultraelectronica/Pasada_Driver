import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pasada_driver_side/Database/driver_provider.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PassengerCapacity {
  int capacity = 0;
  final SupabaseClient supabase = Supabase.instance.client;

  Future<void> getPassengerCapacityToDB(BuildContext context) async {
    try {
      final String vehicleID = context.read<DriverProvider>().vehicleID;

      if (vehicleID == null) {
        if (kDebugMode) {
          print('DriverID not fount');
        }
        return;
      }

      final getPassengerCapacity = await supabase
          .from('vehicleTable')
          .select('passenger_capacity')
          .eq('vehicle_id', vehicleID)
          .single();

      if (kDebugMode) {
        print('Vehicle ID: $getPassengerCapacity');
      }

      context
          .read<DriverProvider>()
          .setPassengerCapacity(getPassengerCapacity['passenger_capacity']);

      if (kDebugMode) {
        print(
          'provider vehicle capacity: ${context.read<DriverProvider>().passengerCapacity.toString()}');
      }

      // Fluttertoast.showToast(msg: msg)
    } catch (e) {
      if (kDebugMode) {
        print('Error: $e');
      }
    }

  }
}
