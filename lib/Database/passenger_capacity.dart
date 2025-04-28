import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pasada_driver_side/Database/driver_provider.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PassengerCapacity {
  final SupabaseClient supabase = Supabase.instance.client;

  Future<void> getPassengerCapacityToDB(BuildContext context) async {
    try {
      final String driverID = context.read<DriverProvider>().driverID;

      print('Driver ID in getPassengerCapacityToDB: $driverID');

      final getOngoingPassenger = await supabase
          .from('bookings')
          .select('booking_id')
          .eq('driver_id', driverID)
          .eq('ride_status', 'ongoing')
          .single();

      if (kDebugMode) {
        print('Ongoing Passenger: $getOngoingPassenger');
      }

      if (getOngoingPassenger.isNotEmpty) {
        context
            .read<DriverProvider>()
            .setPassengerCapacity(getOngoingPassenger.length);
        print(
            'provider vehicle capacity: ${context.read<DriverProvider>().passengerCapacity.toString()}');
      } else {
        context.read<DriverProvider>().setPassengerCapacity(0);
      }

      // final getPassengerCapacity = await supabase
      //     .from('vehicleTable')
      //     .select('passenger_capacity')
      //     .eq('vehicle_id', vehicleID)
      //     .single();

      // if (kDebugMode) {
      //   print('Vehicle ID: $getPassengerCapacity');
      // }

      // context
      //     .read<DriverProvider>()
      //     .setPassengerCapacity(getPassengerCapacity['passenger_capacity']);

      // if (kDebugMode) {
      //   print(
      //       'provider vehicle capacity: ${context.read<DriverProvider>().passengerCapacity.toString()}');
      // }

    } catch (e, StackTrace) {
      if (kDebugMode) {
        print('Error fetching passenger capacity: $e');
        print('Passenger Capacity Stack Trace: $StackTrace');
      }
    }
  }
}
