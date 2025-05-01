import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pasada_driver_side/Database/driver_provider.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PassengerCapacity {
  final SupabaseClient supabase = Supabase.instance.client;

  ///Checks how many passengers are ongoing in the bookings table
  Future<void> getPassengerCapacityToDB(BuildContext context) async {
    try {
      final String driverID = context.read<DriverProvider>().driverID;
      final String vehicleID = context.read<DriverProvider>().vehicleID;

      debugPrint('Driver ID in getPassengerCapacityToDB: $driverID');
      debugPrint('Vehicle ID in getPassengerCapacityToDB: $vehicleID');

      final getOngoingPassenger =
          await supabase.from('bookings').select('booking_id').eq('driver_id', driverID).eq('ride_status', 'ongoing').select();

      debugPrint('Ongoing Passenger: $getOngoingPassenger');

      //updates how many passengers are ongoing in the vehicle table
      final response =
          await supabase.from('vehicleTable').update({'passenger_capacity': getOngoingPassenger.length}).eq('vehicle_id', vehicleID).select();

      debugPrint('Passenger capacity updated to DB: $response');

      if (getOngoingPassenger.isNotEmpty) {
        context.read<DriverProvider>().setPassengerCapacity(getOngoingPassenger.length);

        debugPrint('provider vehicle capacity: ${context.read<DriverProvider>().passengerCapacity.toString()}');
      } else {
        context.read<DriverProvider>().setPassengerCapacity(getOngoingPassenger.length);
        debugPrint('provider vehicle capacity: ${context.read<DriverProvider>().passengerCapacity.toString()}');
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
      debugPrint('Error fetching passenger capacity: $e');
      debugPrint('Passenger Capacity Stack Trace: $StackTrace');
      debugPrint('Error: Driver ID in checking capacity: ${context.read<DriverProvider>().driverID}');
      debugPrint('Error: Vehicle ID in checking capacity: ${context.read<DriverProvider>().vehicleID}');
    }
  }
}
