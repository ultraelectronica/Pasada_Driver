// ignore_for_file: constant_identifier_names

import 'package:flutter/material.dart';
import 'package:pasada_driver_side/presentation/providers/driver/driver_provider.dart';
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

  bool _validateDriverStatus(DriverProvider driverProvider) =>
      driverProvider.driverStatus == 'Driving';

  bool _validateCapacityLimits(
      int standingCount, int sittingCount, String operation) {
    if (operation == 'increment') {
      if (standingCount >= MAX_STANDING_CAPACITY) return false;
      if (sittingCount >= MAX_SITTING_CAPACITY) return false;
      if ((standingCount + sittingCount) >= MAX_TOTAL_CAPACITY) return false;
    }
    return true;
  }

  bool _validateNonNegative(int totalCapacity, int standingCount,
      int sittingCount, String operation) {
    if (operation == 'decrement') {
      if (totalCapacity < 0 || standingCount < 0 || sittingCount < 0) {
        return false;
      }
    }
    return true;
  }

  Future<CapacityOperationResult> _atomicCapacityUpdate(
    BuildContext context,
    String operation,
    String seatType, {
    bool isManual = false,
  }) async {
    final driverProvider = context.read<DriverProvider>();
    final String vehicleID = driverProvider.vehicleID;

    // Backup for rollback
    final originalTotal = driverProvider.passengerCapacity;
    final originalStanding = driverProvider.passengerStandingCapacity;
    final originalSitting = driverProvider.passengerSittingCapacity;

    try {
      if (isManual && !_validateDriverStatus(driverProvider)) {
        return CapacityOperationResult(
          success: false,
          errorType: ERROR_DRIVER_NOT_DRIVING,
          errorMessage:
              'Driver must be in Driving status for manual operations',
        );
      }

      final vehicleData = await supabase
          .from('vehicleTable')
          .select('passenger_capacity, standing_passenger, sitting_passenger')
          .eq('vehicle_id', vehicleID)
          .single();

      int totalCapacity = vehicleData['passenger_capacity'] ?? 0;
      int standingCount = vehicleData['standing_passenger'] ?? 0;
      int sittingCount = vehicleData['sitting_passenger'] ?? 0;

      int newTotal = totalCapacity;
      int newStanding = standingCount;
      int newSitting = sittingCount;

      if (operation == 'increment') {
        newTotal++;
        if (seatType == 'Standing') {
          newStanding++;
        } else {
          newSitting++;
        }
      } else {
        newTotal--;
        if (seatType == 'Standing') {
          newStanding--;
        } else {
          newSitting--;
        }
      }

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
      if (newTotal != (newStanding + newSitting)) {
        return CapacityOperationResult(
          success: false,
          errorType: ERROR_VALIDATION_FAILED,
          errorMessage: 'Data consistency check failed',
        );
      }

      await supabase.from('vehicleTable').update({
        'passenger_capacity': newTotal,
        'standing_passenger': newStanding,
        'sitting_passenger': newSitting,
      }).eq('vehicle_id', vehicleID);

      driverProvider.setPassengerCapacity(newTotal);
      driverProvider.setPassengerStandingCapacity(newStanding);
      driverProvider.setPassengerSittingCapacity(newSitting);

      return CapacityOperationResult(success: true, capacityData: {
        'total': newTotal,
        'Standing': newStanding,
        'Sitting': newSitting,
      });
    } catch (e) {
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

  Future<void> initializeCapacity(BuildContext context) async {
    try {
      final driverProvider = context.read<DriverProvider>();
      final vehicleID = driverProvider.vehicleID;
      final response = await supabase
          .from('vehicleTable')
          .select('passenger_capacity, standing_passenger, sitting_passenger')
          .eq('vehicle_id', vehicleID)
          .maybeSingle();

      if (response == null ||
          response['passenger_capacity'] == null ||
          response['standing_passenger'] == null ||
          response['sitting_passenger'] == null) {
        await supabase.from('vehicleTable').upsert({
          'vehicle_id': vehicleID,
          'passenger_capacity': 0,
          'standing_passenger': 0,
          'sitting_passenger': 0,
        });
      }
      await getPassengerCapacityToDB(context);
    } catch (_) {}
  }

  Future<void> getPassengerCapacityToDB(BuildContext context) async {
    try {
      final driverProvider = context.read<DriverProvider>();
      final vehicleID = driverProvider.vehicleID;
      final response = await supabase
          .from('vehicleTable')
          .select('passenger_capacity, standing_passenger, sitting_passenger')
          .eq('vehicle_id', vehicleID)
          .single();

      driverProvider.setPassengerCapacity(response['passenger_capacity'] ?? 0);
      driverProvider
          .setPassengerStandingCapacity(response['standing_passenger'] ?? 0);
      driverProvider
          .setPassengerSittingCapacity(response['sitting_passenger'] ?? 0);
    } catch (_) {}
  }

  Future<CapacityOperationResult> incrementCapacity(
          BuildContext context, String seatType) async =>
      _atomicCapacityUpdate(context, 'increment', seatType);

  Future<CapacityOperationResult> decrementCapacity(
          BuildContext context, String seatType) async =>
      _atomicCapacityUpdate(context, 'decrement', seatType);

  Future<CapacityOperationResult> manualIncrementStanding(
          BuildContext context) async =>
      _atomicCapacityUpdate(context, 'increment', 'Standing', isManual: true);

  Future<CapacityOperationResult> manualIncrementSitting(
          BuildContext context) async =>
      _atomicCapacityUpdate(context, 'increment', 'Sitting', isManual: true);

  Future<CapacityOperationResult> manualDecrementStanding(
          BuildContext context) async =>
      _atomicCapacityUpdate(context, 'decrement', 'Standing', isManual: true);

  Future<CapacityOperationResult> manualDecrementSitting(
          BuildContext context) async =>
      _atomicCapacityUpdate(context, 'decrement', 'Sitting', isManual: true);

  Future<CapacityOperationResult> resetCapacityToZero(
      BuildContext context) async {
    try {
      final driverProvider = context.read<DriverProvider>();
      final vehicleID = driverProvider.vehicleID;
      await supabase.from('vehicleTable').update({
        'passenger_capacity': 0,
        'standing_passenger': 0,
        'sitting_passenger': 0,
      }).eq('vehicle_id', vehicleID);
      driverProvider.setPassengerCapacity(0);
      driverProvider.setPassengerStandingCapacity(0);
      driverProvider.setPassengerSittingCapacity(0);
      return CapacityOperationResult(success: true, capacityData: {
        'total': 0,
        'Standing': 0,
        'Sitting': 0,
      });
    } catch (e) {
      return CapacityOperationResult(
        success: false,
        errorType: ERROR_DATABASE_FAILED,
        errorMessage: 'Failed to reset capacity: $e',
      );
    }
  }
}
