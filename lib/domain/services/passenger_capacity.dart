// ignore_for_file: constant_identifier_names

import 'package:flutter/material.dart';
import 'package:pasada_driver_side/presentation/providers/driver/driver_provider.dart';
import 'package:pasada_driver_side/presentation/providers/passenger/passenger_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pasada_driver_side/common/constants/booking_constants.dart';

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
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

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
  static const String ERROR_MANUAL_FORBIDDEN = 'manual_forbidden';

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
    final passengerProvider = context.read<PassengerProvider>();
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

      // For manual decrement, ensure we're not removing booked capacity
      if (isManual && operation == 'decrement') {
        int bookedStanding = passengerProvider.bookings
            .where((b) =>
                b.rideStatus == BookingConstants.statusOngoing &&
                b.seatType == 'Standing')
            .length;
        int bookedSitting = passengerProvider.bookings
            .where((b) =>
                b.rideStatus == BookingConstants.statusOngoing &&
                b.seatType == 'Sitting')
            .length;

        int manualStanding =
            (standingCount - bookedStanding).clamp(0, standingCount);
        int manualSitting =
            (sittingCount - bookedSitting).clamp(0, sittingCount);

        // If bookings list is empty (e.g., after app restart), fall back to persisted manual counts
        if (passengerProvider.bookings.isEmpty) {
          final stored = await _loadManualCounts(vehicleID);
          manualStanding = stored.$1;
          manualSitting = stored.$2;
        }

        if (seatType == 'Standing' && manualStanding <= 0) {
          return CapacityOperationResult(
            success: false,
            errorType: ERROR_MANUAL_FORBIDDEN,
            errorMessage:
                'Cannot remove standing passenger: capacity was added via booking',
          );
        }
        if (seatType == 'Sitting' && manualSitting <= 0) {
          return CapacityOperationResult(
            success: false,
            errorType: ERROR_MANUAL_FORBIDDEN,
            errorMessage:
                'Cannot remove sitting passenger: capacity was added via booking',
          );
        }
      }

      // TODO: Uncomment this if need na i check yung capacity
      // if (!_validateCapacityLimits(newStanding, newSitting, operation)) {
      //   return CapacityOperationResult(
      //     success: false,
      //     errorType: ERROR_CAPACITY_EXCEEDED,
      //     errorMessage: 'Operation would exceed capacity limits',
      //   );
      // }
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

      // Track manual adjustments locally so we can enforce rules after app restarts
      if (isManual) {
        await _adjustAndSaveManualCounts(
          vehicleID: vehicleID,
          seatType: seatType,
          delta: operation == 'increment' ? 1 : -1,
        );
      }

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

  /// Increment capacity by a specific amount (for batch operations like manual bookings)
  Future<CapacityOperationResult> incrementCapacityBulk(
      BuildContext context, String seatType, int count) async {
    if (count <= 0) {
      return CapacityOperationResult(
        success: false,
        errorType: ERROR_VALIDATION_FAILED,
        errorMessage: 'Count must be greater than 0',
      );
    }

    final driverProvider = context.read<DriverProvider>();
    final String vehicleID = driverProvider.vehicleID;

    // Backup for rollback
    final originalTotal = driverProvider.passengerCapacity;
    final originalStanding = driverProvider.passengerStandingCapacity;
    final originalSitting = driverProvider.passengerSittingCapacity;

    try {
      final vehicleData = await supabase
          .from('vehicleTable')
          .select('passenger_capacity, standing_passenger, sitting_passenger')
          .eq('vehicle_id', vehicleID)
          .single();

      int totalCapacity = vehicleData['passenger_capacity'] ?? 0;
      int standingCount = vehicleData['standing_passenger'] ?? 0;
      int sittingCount = vehicleData['sitting_passenger'] ?? 0;

      int newTotal = totalCapacity + count;
      int newStanding = standingCount;
      int newSitting = sittingCount;

      if (seatType == 'Standing') {
        newStanding += count;
      } else {
        newSitting += count;
      }

      // Validation
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

// ───────────────────────── Manual count persistence helpers ─────────────────────────
extension _ManualCapacityStorage on PassengerCapacity {
  String _standingKey(String vehicleID) => 'manual_standing:$vehicleID';
  String _sittingKey(String vehicleID) => 'manual_sitting:$vehicleID';

  Future<(int, int)> _loadManualCounts(String vehicleID) async {
    try {
      final s = await PassengerCapacity._secureStorage
          .read(key: _standingKey(vehicleID));
      final t = await PassengerCapacity._secureStorage
          .read(key: _sittingKey(vehicleID));
      final standing = int.tryParse(s ?? '0') ?? 0;
      final sitting = int.tryParse(t ?? '0') ?? 0;
      return (standing, sitting);
    } catch (_) {
      return (0, 0);
    }
  }

  Future<void> _saveManualCounts(
      String vehicleID, int standing, int sitting) async {
    await PassengerCapacity._secureStorage
        .write(key: _standingKey(vehicleID), value: standing.toString());
    await PassengerCapacity._secureStorage
        .write(key: _sittingKey(vehicleID), value: sitting.toString());
  }

  Future<void> _adjustAndSaveManualCounts({
    required String vehicleID,
    required String seatType,
    required int delta,
  }) async {
    final current = await _loadManualCounts(vehicleID);
    int standing = current.$1;
    int sitting = current.$2;
    if (seatType == 'Standing') {
      standing = (standing + delta).clamp(0, 1 << 30);
    } else {
      sitting = (sitting + delta).clamp(0, 1 << 30);
    }
    await _saveManualCounts(vehicleID, standing, sitting);
  }
}
