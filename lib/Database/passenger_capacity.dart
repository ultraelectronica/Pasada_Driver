import 'package:flutter/material.dart';
import 'package:pasada_driver_side/Database/driver_provider.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// PassengerCapacity manages the current vehicle occupancy.
///
/// Database schema in vehicleTable:
/// - passenger_capacity: Total current passengers
/// - standing_count: Number of standing passengers
/// - sitting_count: Number of sitting passengers
///
/// The capacity is:
/// - Incremented when driver confirms passenger pickup
/// - Decremented when driver completes a passenger's ride
class PassengerCapacity {
  final SupabaseClient supabase = Supabase.instance.client;

  /// Initialize vehicle capacity with zero values if columns don't exist
  Future<void> initializeCapacity(BuildContext context) async {
    try {
      final driverProvider =
          Provider.of<DriverProvider>(context, listen: false);
      final String vehicleID = driverProvider.vehicleID;

      // Check if the vehicle record exists and has the required columns
      final response = await supabase
          .from('vehicleTable')
          .select('passenger_capacity, standing_passenger, sitting_passenger')
          .eq('vehicle_id', vehicleID)
          .maybeSingle();

      // If no record or missing columns, initialize them
      if (response == null ||
          response['passenger_capacity'] == null ||
          response['standing_passenger'] == null ||
          response['sitting_passenger'] == null) {
        // Update with default values
        await supabase.from('vehicleTable').upsert({
          'vehicle_id': vehicleID,
          'passenger_capacity': 0,
          'standing_passenger': 0,
          'sitting_passenger': 0,
        });

        debugPrint('Initialized vehicle capacity columns with zeros');
      }

      // Update provider values
      await getPassengerCapacityToDB(context);
    } catch (e) {
      debugPrint('Error initializing capacity: $e');
    }
  }

  /// Retrieves the current passenger capacity from the database
  Future<void> getPassengerCapacityToDB(BuildContext context) async {
    try {
      // Get all needed data from provider at the beginning
      final driverProvider =
          Provider.of<DriverProvider>(context, listen: false);
      final String driverID = driverProvider.driverID;
      final String vehicleID = driverProvider.vehicleID;

      debugPrint('Driver ID in getPassengerCapacityToDB: $driverID');
      debugPrint('Vehicle ID in getPassengerCapacityToDB: $vehicleID');

      // Get the vehicle's current passenger capacity from the database
      final response = await supabase
          .from('vehicleTable')
          .select('passenger_capacity, standing_passenger, sitting_passenger')
          .eq('vehicle_id', vehicleID)
          .single();

      final int totalCapacity = response['passenger_capacity'] ?? 0;
      final int standingCount = response['standing_passenger'] ?? 0;
      final int sittingCount = response['sitting_passenger'] ?? 0;

      // Update local state in the provider
      driverProvider.setPassengerCapacity(totalCapacity);
      driverProvider.setPassengerStandingCapacity(standingCount);
      driverProvider.setPassengerSittingCapacity(sittingCount);

      debugPrint('Total passenger capacity: $totalCapacity');
      debugPrint('Standing passengers: $standingCount');
      debugPrint('Sitting passengers: $sittingCount');
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

  /// Increment passenger capacity when a passenger is picked up
  Future<bool> incrementCapacity(BuildContext context, String seatType) async {
    try {
      final driverProvider =
          Provider.of<DriverProvider>(context, listen: false);
      final String vehicleID = driverProvider.vehicleID;

      debugPrint('Incrementing capacity for seat type: $seatType');

      // Get current counts
      final vehicleData = await supabase
          .from('vehicleTable')
          .select('passenger_capacity, standing_passenger, sitting_passenger')
          .eq('vehicle_id', vehicleID)
          .single();

      int totalCapacity = vehicleData['passenger_capacity'] ?? 0;
      int standingCount = vehicleData['standing_passenger'] ?? 0;
      int sittingCount = vehicleData['sitting_passenger'] ?? 0;

      // Increment appropriate counts
      totalCapacity++;
      if (seatType == 'standing') {
        standingCount++;
      } else if (seatType == 'sitting') {
        sittingCount++;
      }

      // Update the database
      await supabase.from('vehicleTable').update({
        'passenger_capacity': totalCapacity,
        'standing_passenger': standingCount,
        'sitting_passenger': sittingCount,
      }).eq('vehicle_id', vehicleID);

      // Update provider
      driverProvider.setPassengerCapacity(totalCapacity);
      driverProvider.setPassengerStandingCapacity(standingCount);
      driverProvider.setPassengerSittingCapacity(sittingCount);

      debugPrint('Capacity incremented. Total: $totalCapacity');
      debugPrint('Standing: $standingCount, Sitting: $sittingCount');
      return true;
    } catch (e) {
      debugPrint('Error incrementing capacity: $e');
      return false;
    }
  }

  /// Decrement passenger capacity when a passenger completes their ride
  Future<bool> decrementCapacity(BuildContext context, String seatType) async {
    try {
      final driverProvider =
          Provider.of<DriverProvider>(context, listen: false);
      final String vehicleID = driverProvider.vehicleID;

      debugPrint('Decrementing capacity for seat type: $seatType');

      // Get current counts
      final vehicleData = await supabase
          .from('vehicleTable')
          .select('passenger_capacity, standing_passenger, sitting_passenger')
          .eq('vehicle_id', vehicleID)
          .single();

      int totalCapacity = vehicleData['passenger_capacity'] ?? 0;
      int standingCount = vehicleData['standing_passenger'] ?? 0;
      int sittingCount = vehicleData['sitting_passenger'] ?? 0;

      // Prevent negative values
      if (totalCapacity > 0) {
        totalCapacity--;
        if (seatType == 'standing' && standingCount > 0) {
          standingCount--;
        } else if (seatType == 'sitting' && sittingCount > 0) {
          sittingCount--;
        }
      }

      // Update the database
      await supabase.from('vehicleTable').update({
        'passenger_capacity': totalCapacity,
        'standing_passenger': standingCount,
        'sitting_passenger': sittingCount,
      }).eq('vehicle_id', vehicleID);

      // Update provider
      driverProvider.setPassengerCapacity(totalCapacity);
      driverProvider.setPassengerStandingCapacity(standingCount);
      driverProvider.setPassengerSittingCapacity(sittingCount);

      debugPrint('Capacity decremented. Total: $totalCapacity');
      debugPrint('Standing: $standingCount, Sitting: $sittingCount');
      return true;
    } catch (e) {
      debugPrint('Error decrementing capacity: $e');
      return false;
    }
  }

  /// Manually increment standing capacity by 1
  Future<bool> manualIncrementStanding(BuildContext context) async {
    try {
      final driverProvider =
          Provider.of<DriverProvider>(context, listen: false);
      final String vehicleID = driverProvider.vehicleID;

      debugPrint('Manually incrementing standing capacity');

      // Get current counts
      final vehicleData = await supabase
          .from('vehicleTable')
          .select('passenger_capacity, standing_passenger, sitting_passenger')
          .eq('vehicle_id', vehicleID)
          .single();

      int totalCapacity = vehicleData['passenger_capacity'] ?? 0;
      int standingCount = vehicleData['standing_passenger'] ?? 0;

      // Increment counts
      totalCapacity++;
      standingCount++;

      // Update the database
      await supabase.from('vehicleTable').update({
        'passenger_capacity': totalCapacity,
        'standing_passenger': standingCount,
      }).eq('vehicle_id', vehicleID);

      // Update provider
      driverProvider.setPassengerCapacity(totalCapacity);
      driverProvider.setPassengerStandingCapacity(standingCount);

      debugPrint(
          'Standing capacity manually incremented. Total: $totalCapacity, Standing: $standingCount');
      return true;
    } catch (e) {
      debugPrint('Error manually incrementing standing capacity: $e');
      return false;
    }
  }

  /// Manually increment sitting capacity by 1
  Future<bool> manualIncrementSitting(BuildContext context) async {
    try {
      final driverProvider =
          Provider.of<DriverProvider>(context, listen: false);
      final String vehicleID = driverProvider.vehicleID;

      debugPrint('Manually incrementing sitting capacity');

      // Get current counts
      final vehicleData = await supabase
          .from('vehicleTable')
          .select('passenger_capacity, standing_passenger, sitting_passenger')
          .eq('vehicle_id', vehicleID)
          .single();

      int totalCapacity = vehicleData['passenger_capacity'] ?? 0;
      int sittingCount = vehicleData['sitting_passenger'] ?? 0;

      // Increment counts
      totalCapacity++;
      sittingCount++;

      // Update the database
      await supabase.from('vehicleTable').update({
        'passenger_capacity': totalCapacity,
        'sitting_passenger': sittingCount,
      }).eq('vehicle_id', vehicleID);

      // Update provider
      driverProvider.setPassengerCapacity(totalCapacity);
      driverProvider.setPassengerSittingCapacity(sittingCount);

      debugPrint(
          'Sitting capacity manually incremented. Total: $totalCapacity, Sitting: $sittingCount');
      return true;
    } catch (e) {
      debugPrint('Error manually incrementing sitting capacity: $e');
      return false;
    }
  }

  /// Manually decrement standing capacity by 1
  Future<bool> manualDecrementStanding(BuildContext context) async {
    try {
      final driverProvider =
          Provider.of<DriverProvider>(context, listen: false);
      final String vehicleID = driverProvider.vehicleID;

      debugPrint('Manually decrementing standing capacity');

      // Get current counts
      final vehicleData = await supabase
          .from('vehicleTable')
          .select('passenger_capacity, standing_passenger, sitting_passenger')
          .eq('vehicle_id', vehicleID)
          .single();

      int totalCapacity = vehicleData['passenger_capacity'] ?? 0;
      int standingCount = vehicleData['standing_passenger'] ?? 0;

      // Only decrement if values are greater than 0
      if (totalCapacity > 0 && standingCount > 0) {
        totalCapacity--;
        standingCount--;

        // Update the database
        await supabase.from('vehicleTable').update({
          'passenger_capacity': totalCapacity,
          'standing_passenger': standingCount,
        }).eq('vehicle_id', vehicleID);

        // Update provider
        driverProvider.setPassengerCapacity(totalCapacity);
        driverProvider.setPassengerStandingCapacity(standingCount);

        debugPrint(
            'Standing capacity manually decremented. Total: $totalCapacity, Standing: $standingCount');
        return true;
      } else {
        debugPrint('Cannot decrement: standing count is already 0');
        return false;
      }
    } catch (e) {
      debugPrint('Error manually decrementing standing capacity: $e');
      return false;
    }
  }

  /// Manually decrement sitting capacity by 1
  Future<bool> manualDecrementSitting(BuildContext context) async {
    try {
      final driverProvider =
          Provider.of<DriverProvider>(context, listen: false);
      final String vehicleID = driverProvider.vehicleID;

      debugPrint('Manually decrementing sitting capacity');

      // Get current counts
      final vehicleData = await supabase
          .from('vehicleTable')
          .select('passenger_capacity, standing_passenger, sitting_passenger')
          .eq('vehicle_id', vehicleID)
          .single();

      int totalCapacity = vehicleData['passenger_capacity'] ?? 0;
      int sittingCount = vehicleData['sitting_passenger'] ?? 0;

      // Only decrement if values are greater than 0
      if (totalCapacity > 0 && sittingCount > 0) {
        totalCapacity--;
        sittingCount--;

        // Update the database
        await supabase.from('vehicleTable').update({
          'passenger_capacity': totalCapacity,
          'sitting_passenger': sittingCount,
        }).eq('vehicle_id', vehicleID);

        // Update provider
        driverProvider.setPassengerCapacity(totalCapacity);
        driverProvider.setPassengerSittingCapacity(sittingCount);

        debugPrint(
            'Sitting capacity manually decremented. Total: $totalCapacity, Sitting: $sittingCount');
        return true;
      } else {
        debugPrint('Cannot decrement: sitting count is already 0');
        return false;
      }
    } catch (e) {
      debugPrint('Error manually decrementing sitting capacity: $e');
      return false;
    }
  }
}
