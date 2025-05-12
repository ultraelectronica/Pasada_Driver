import 'package:flutter/material.dart';
import 'package:pasada_driver_side/Database/driver_provider.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PassengerCapacity {
  final SupabaseClient supabase = Supabase.instance.client;

  ///Checks how many passengers are ongoing in the bookings table
  Future<void> getPassengerCapacityToDB(BuildContext context) async {
    try {
      // Get all needed data from provider at the beginning
      final driverProvider =
          Provider.of<DriverProvider>(context, listen: false);
      final String driverID = driverProvider.driverID;
      final String vehicleID = driverProvider.vehicleID;

      debugPrint('Driver ID in getPassengerCapacityToDB: $driverID');
      debugPrint('Vehicle ID in getPassengerCapacityToDB: $vehicleID');

      final getOngoingPassenger = await supabase
          .from('bookings')
          .select('booking_id, seat_type')
          .eq('driver_id', driverID)
          .eq('ride_status', 'ongoing');

      debugPrint('Number of ongoing bookings: ${getOngoingPassenger.length}');
      for (var i = 0; i < getOngoingPassenger.length; i++) {
        debugPrint(
            'Ongoing booking ${i + 1}: ${getOngoingPassenger[i]['booking_id']}');
      }

      int standingPassengers = 0;
      int sittingPassengers = 0;

      for (var passenger in getOngoingPassenger) {
        if (passenger['seat_type'] == 'standing') {
          standingPassengers++;
          debugPrint('Passenger is standing');
        }
      }

      for (var passenger in getOngoingPassenger) {
        if (passenger['seat_type'] == 'sitting') {
          sittingPassengers++;
          debugPrint('Passenger is sitting');
        }
      }

      debugPrint('Standing Passengers: $standingPassengers');
      driverProvider.setPassengerStandingCapacity(standingPassengers);

      debugPrint('Sitting Passengers: $sittingPassengers');
      driverProvider.setPassengerSittingCapacity(sittingPassengers);

      //updates how many passengers are ongoing in the vehicle table
      final response = await supabase
          .from('vehicleTable')
          .update({'passenger_capacity': getOngoingPassenger.length})
          .eq('vehicle_id', vehicleID)
          .select();

      debugPrint('Passenger capacity updated to DB: $response');

      // Update passenger capacity in provider
      driverProvider.setPassengerCapacity(getOngoingPassenger.length);

      debugPrint(
          'provider vehicle capacity: ${driverProvider.passengerCapacity.toString()}');
    } catch (e, stackTrace) {
      debugPrint('Error fetching passenger capacity: $e');
      debugPrint('Passenger Capacity Stack Trace: $stackTrace');

      // Get provider info for error logs even if main operation failed
      final driverProvider =
          Provider.of<DriverProvider>(context, listen: false);
      debugPrint(
          'Error: Driver ID in checking capacity: ${driverProvider.driverID}');
      debugPrint(
          'Error: Vehicle ID in checking capacity: ${driverProvider.vehicleID}');
    }
  }
}
