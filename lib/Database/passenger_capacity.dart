import 'package:flutter/material.dart';
import 'package:pasada_driver_side/Database/driver_provider.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Result class for capacity operations
class CapacityOperationResult {
  final bool success;
  final String? errorType;
  final String? errorMessage;
  final Map<String, int>? capacityData;

  CapacityOperationResult({
    required this.success,
    this.errorType,
    this.errorMessage,
    this.capacityData,
  });
}

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

  // Maximum capacity limits
  static const int MAX_SITTING_CAPACITY = 23;
  static const int MAX_STANDING_CAPACITY = 5;
  static const int MAX_TOTAL_CAPACITY =
      MAX_SITTING_CAPACITY + MAX_STANDING_CAPACITY;

  // Error types for better error handling
  static const String ERROR_DRIVER_NOT_DRIVING = 'driver_not_driving';
  static const String ERROR_CAPACITY_EXCEEDED = 'capacity_exceeded';
  static const String ERROR_NEGATIVE_VALUES = 'negative_values';
  static const String ERROR_DATABASE_FAILED = 'database_failed';
  static const String ERROR_VALIDATION_FAILED = 'validation_failed';

  /// Validate driver status for manual operations
  bool _validateDriverStatus(DriverProvider driverProvider) {
    return driverProvider.driverStatus == 'Driving';
  }

  /// Validate capacity limits
  bool _validateCapacityLimits(
      int standingCount, int sittingCount, String operation) {
    if (operation == 'increment') {
      if (standingCount >= MAX_STANDING_CAPACITY) {
        debugPrint(
            'Cannot increment: Maximum standing capacity reached ($MAX_STANDING_CAPACITY)');
        return false;
      }
      if (sittingCount >= MAX_SITTING_CAPACITY) {
        debugPrint(
            'Cannot increment: Maximum sitting capacity reached ($MAX_SITTING_CAPACITY)');
        return false;
      }
      if ((standingCount + sittingCount) >= MAX_TOTAL_CAPACITY) {
        debugPrint(
            'Cannot increment: Maximum total capacity reached ($MAX_TOTAL_CAPACITY)');
        return false;
      }
    }
    return true;
  }

  /// Validate against negative values
  bool _validateNonNegative(int totalCapacity, int standingCount,
      int sittingCount, String operation) {
    if (operation == 'decrement') {
      // Allow values to become 0, just prevent negative values
      if (totalCapacity < 0 || standingCount < 0 || sittingCount < 0) {
        debugPrint('Cannot decrement: Values would become negative');
        return false;
      }
    }
    return true;
  }

  /// Atomic update with proper rollback and validation
  Future<CapacityOperationResult> _atomicCapacityUpdate(
      BuildContext context,
      String operation, // 'increment' or 'decrement'
      String seatType,
      {bool isManual = false}) async {
    final driverProvider = Provider.of<DriverProvider>(context, listen: false);
    final String vehicleID = driverProvider.vehicleID;

    // Store original state for rollback
    final originalTotal = driverProvider.passengerCapacity;
    final originalStanding = driverProvider.passengerStandingCapacity;
    final originalSitting = driverProvider.passengerSittingCapacity;

    try {
      // Validate driver status for manual operations
      if (isManual && !_validateDriverStatus(driverProvider)) {
        return CapacityOperationResult(
          success: false,
          errorType: ERROR_DRIVER_NOT_DRIVING,
          errorMessage:
              'Driver must be in Driving status for manual operations',
        );
      }

      // Get current counts from database (source of truth)
      final vehicleData = await supabase
          .from('vehicleTable')
          .select('passenger_capacity, standing_passenger, sitting_passenger')
          .eq('vehicle_id', vehicleID)
          .single();

      int totalCapacity = vehicleData['passenger_capacity'] ?? 0;
      int standingCount = vehicleData['standing_passenger'] ?? 0;
      int sittingCount = vehicleData['sitting_passenger'] ?? 0;

      debugPrint(
          'Current state before $operation: Total: $totalCapacity, Standing: $standingCount, Sitting: $sittingCount');

      // Calculate new values
      int newTotal = totalCapacity;
      int newStanding = standingCount;
      int newSitting = sittingCount;

      if (operation == 'increment') {
        newTotal++;
        if (seatType == 'standing') {
          newStanding++;
        } else if (seatType == 'sitting') {
          newSitting++;
        }
      } else if (operation == 'decrement') {
        newTotal--;
        if (seatType == 'standing') {
          newStanding--;
        } else if (seatType == 'sitting') {
          newSitting--;
        }
      }

      debugPrint(
          'Calculated new state after $operation ($seatType): Total: $newTotal, Standing: $newStanding, Sitting: $newSitting');

      // Comprehensive validation
      if (!_validateCapacityLimits(newStanding, newSitting, operation)) {
        return CapacityOperationResult(
          success: false,
          errorType: ERROR_CAPACITY_EXCEEDED,
          errorMessage: 'Operation would exceed capacity limits',
        );
      }

      if (!_validateNonNegative(newTotal, newStanding, newSitting, operation)) {
        return CapacityOperationResult(
          success: false,
          errorType: ERROR_NEGATIVE_VALUES,
          errorMessage: 'Operation would result in negative values',
        );
      }

      // Validate data consistency
      if (newTotal != (newStanding + newSitting)) {
        return CapacityOperationResult(
          success: false,
          errorType: ERROR_VALIDATION_FAILED,
          errorMessage:
              'Data consistency check failed: Total ≠ Standing + Sitting',
        );
      }

      // Perform atomic database update
      await supabase.from('vehicleTable').update({
        'passenger_capacity': newTotal,
        'standing_passenger': newStanding,
        'sitting_passenger': newSitting,
      }).eq('vehicle_id', vehicleID);

      // Update provider state
      driverProvider.setPassengerCapacity(newTotal);
      driverProvider.setPassengerStandingCapacity(newStanding);
      driverProvider.setPassengerSittingCapacity(newSitting);

      debugPrint(
          '$operation operation successful. Total: $newTotal, Standing: $newStanding, Sitting: $newSitting');

      return CapacityOperationResult(
        success: true,
        capacityData: {
          'total': newTotal,
          'standing': newStanding,
          'sitting': newSitting,
        },
      );
    } catch (e) {
      debugPrint('Error in atomic capacity update: $e');

      // Rollback provider state
      driverProvider.setPassengerCapacity(originalTotal);
      driverProvider.setPassengerStandingCapacity(originalStanding);
      driverProvider.setPassengerSittingCapacity(originalSitting);

      return CapacityOperationResult(
        success: false,
        errorType: ERROR_DATABASE_FAILED,
        errorMessage: 'Database operation failed: $e',
      );
    }
  }

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
  Future<CapacityOperationResult> incrementCapacity(
      BuildContext context, String seatType) async {
    return await _atomicCapacityUpdate(context, 'increment', seatType);
  }

  /// Decrement passenger capacity when a passenger completes their ride
  Future<CapacityOperationResult> decrementCapacity(
      BuildContext context, String seatType) async {
    return await _atomicCapacityUpdate(context, 'decrement', seatType);
  }

  /// Manually increment standing capacity by 1
  Future<CapacityOperationResult> manualIncrementStanding(
      BuildContext context) async {
    return await _atomicCapacityUpdate(context, 'increment', 'standing',
        isManual: true);
  }

  /// Manually increment sitting capacity by 1
  Future<CapacityOperationResult> manualIncrementSitting(
      BuildContext context) async {
    return await _atomicCapacityUpdate(context, 'increment', 'sitting',
        isManual: true);
  }

  /// Manually decrement standing capacity by 1
  Future<CapacityOperationResult> manualDecrementStanding(
      BuildContext context) async {
    return await _atomicCapacityUpdate(context, 'decrement', 'standing',
        isManual: true);
  }

  /// Manually decrement sitting capacity by 1
  Future<CapacityOperationResult> manualDecrementSitting(
      BuildContext context) async {
    return await _atomicCapacityUpdate(context, 'decrement', 'sitting',
        isManual: true);
  }

  // Backward compatibility methods for existing code
  /// Legacy method for increment capacity (returns bool for backward compatibility)
  Future<bool> incrementCapacityLegacy(
      BuildContext context, String seatType) async {
    final result = await incrementCapacity(context, seatType);
    return result.success;
  }

  /// Legacy method for decrement capacity (returns bool for backward compatibility)
  Future<bool> decrementCapacityLegacy(
      BuildContext context, String seatType) async {
    final result = await decrementCapacity(context, seatType);
    return result.success;
  }

  /// Legacy method for manual increment standing (returns bool for backward compatibility)
  Future<bool> manualIncrementStandingLegacy(BuildContext context) async {
    final result = await manualIncrementStanding(context);
    return result.success;
  }

  /// Legacy method for manual increment sitting (returns bool for backward compatibility)
  Future<bool> manualIncrementSittingLegacy(BuildContext context) async {
    final result = await manualIncrementSitting(context);
    return result.success;
  }

  /// Legacy method for manual decrement standing (returns bool for backward compatibility)
  Future<bool> manualDecrementStandingLegacy(BuildContext context) async {
    final result = await manualDecrementStanding(context);
    return result.success;
  }

  /// Legacy method for manual decrement sitting (returns bool for backward compatibility)
  Future<bool> manualDecrementSittingLegacy(BuildContext context) async {
    final result = await manualDecrementSitting(context);
    return result.success;
  }

  /// Reset all capacity to zero (utility method for error recovery)
  Future<CapacityOperationResult> resetCapacityToZero(
      BuildContext context) async {
    try {
      final driverProvider =
          Provider.of<DriverProvider>(context, listen: false);
      final String vehicleID = driverProvider.vehicleID;

      debugPrint('Resetting all capacity to zero');

      // Update database directly to zero
      await supabase.from('vehicleTable').update({
        'passenger_capacity': 0,
        'standing_passenger': 0,
        'sitting_passenger': 0,
      }).eq('vehicle_id', vehicleID);

      // Update provider state
      driverProvider.setPassengerCapacity(0);
      driverProvider.setPassengerStandingCapacity(0);
      driverProvider.setPassengerSittingCapacity(0);

      debugPrint('Capacity reset successful. All values set to 0');

      return CapacityOperationResult(
        success: true,
        capacityData: {
          'total': 0,
          'standing': 0,
          'sitting': 0,
        },
      );
    } catch (e) {
      debugPrint('Error resetting capacity: $e');
      return CapacityOperationResult(
        success: false,
        errorType: ERROR_DATABASE_FAILED,
        errorMessage: 'Failed to reset capacity: $e',
      );
    }
  }
}
