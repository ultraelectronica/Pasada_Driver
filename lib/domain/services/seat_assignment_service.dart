// ignore_for_file: constant_identifier_names

import 'package:flutter/foundation.dart';
import 'package:pasada_driver_side/domain/services/capacity_config.dart';

/// Service for managing priority-based seat assignments for manual bookings
///
/// Priority Order (Highest to Lowest):
/// 1. PWD - Must sit (accessibility requirement)
/// 2. Senior Citizen - Should sit (comfort/safety)
/// 3. Student - Can sit or stand
/// 4. Regular - Can sit or stand
class SeatAssignmentService {
  // Maximum capacity constants (matching PassengerCapacity)
  static const int MAX_SITTING_CAPACITY = CapacityConfig.MAX_SITTING_CAPACITY;
  static const int MAX_STANDING_CAPACITY = CapacityConfig.MAX_STANDING_CAPACITY;
  static const int MAX_TOTAL_CAPACITY = CapacityConfig.MAX_TOTAL_CAPACITY;

  /// Result of seat assignment calculation
  static SeatAssignmentResult assignSeats({
    required int currentSitting,
    required int currentStanding,
    required int pwdCount,
    required int seniorCount,
    required int studentCount,
    required int regularCount,
  }) {
    // Calculate available capacity (defensive: clamp to avoid negatives
    // if current values are already above configured limits)
    final int availableSittingRaw = MAX_SITTING_CAPACITY - currentSitting;
    final int availableStandingRaw = MAX_STANDING_CAPACITY - currentStanding;
    final int availableSitting =
        availableSittingRaw < 0 ? 0 : availableSittingRaw;
    final int availableStanding =
        availableStandingRaw < 0 ? 0 : availableStandingRaw;
    final availableTotal = availableSitting + availableStanding;
    final totalPassengers =
        pwdCount + seniorCount + studentCount + regularCount;

    debugPrint('=== Seat Assignment Calculation ===');
    debugPrint(
        'Current capacity: $currentSitting sitting, $currentStanding standing');
    debugPrint(
        'Available: $availableSitting sitting, $availableStanding standing');
    debugPrint('Requested: $totalPassengers passengers');
    debugPrint('  - PWD: $pwdCount');
    debugPrint('  - Senior: $seniorCount');
    debugPrint('  - Student: $studentCount');
    debugPrint('  - Regular: $regularCount');

    // Validate total capacity
    if (totalPassengers > availableTotal) {
      debugPrint('ERROR: Not enough capacity!');
      return SeatAssignmentResult.error(
        message: 'Not enough capacity',
        details: 'Need $totalPassengers seats, only $availableTotal available',
      );
    }

    // Initialize assignment trackers
    final sitting = PassengerTypeCount();
    final standing = PassengerTypeCount();
    int remainingSitting = availableSitting;
    int remainingStanding = availableStanding;

    // Priority 1: Assign PWD
    final pwdSitting =
        pwdCount <= remainingSitting ? pwdCount : remainingSitting;
    sitting.pwd = pwdSitting;
    remainingSitting -= pwdSitting;

    final pwdStanding = pwdCount - pwdSitting;
    standing.pwd = pwdStanding;
    remainingStanding -= pwdStanding;

    debugPrint(
        'After PWD assignment: $remainingSitting sitting, $remainingStanding standing available');

    // Priority 2: Assign Senior
    final seniorSitting =
        seniorCount <= remainingSitting ? seniorCount : remainingSitting;
    sitting.senior = seniorSitting;
    remainingSitting -= seniorSitting;

    final seniorStanding = seniorCount - seniorSitting;
    standing.senior = seniorStanding;
    remainingStanding -= seniorStanding;

    debugPrint(
        'After Senior assignment: $remainingSitting sitting, $remainingStanding standing available');

    // Priority 3: Assign Student
    final studentSitting =
        studentCount <= remainingSitting ? studentCount : remainingSitting;
    sitting.student = studentSitting;
    remainingSitting -= studentSitting;

    final studentStanding = studentCount - studentSitting;
    standing.student = studentStanding;
    remainingStanding -= studentStanding;

    debugPrint(
        'After Student assignment: $remainingSitting sitting, $remainingStanding standing available');

    // Priority 4: Assign Regular
    final regularSitting =
        regularCount <= remainingSitting ? regularCount : remainingSitting;
    sitting.regular = regularSitting;
    remainingSitting -= regularSitting;

    final regularStanding = regularCount - regularSitting;
    standing.regular = regularStanding;
    remainingStanding -= regularStanding;

    debugPrint(
        'After Regular assignment: $remainingSitting sitting, $remainingStanding standing available');
    debugPrint('Final sitting: ${sitting.total}');
    debugPrint('Final standing: ${standing.total}');

    return SeatAssignmentResult.success(
      sittingAssignments: sitting,
      standingAssignments: standing,
    );
  }

  /// Check if assignment has priority passengers in standing
  /// (PWD or Senior assigned to standing - should show warning)
  static bool hasPriorityPassengersStanding(PassengerTypeCount standing) {
    return standing.pwd > 0 || standing.senior > 0;
  }

  /// Generate a human-readable summary of seat assignments
  static String generateAssignmentSummary({
    required PassengerTypeCount sitting,
    required PassengerTypeCount standing,
  }) {
    final lines = <String>[];

    if (sitting.total > 0) {
      final parts = <String>[];
      if (sitting.pwd > 0) parts.add('${sitting.pwd} PWD');
      if (sitting.senior > 0) parts.add('${sitting.senior} Senior');
      if (sitting.student > 0) parts.add('${sitting.student} Student');
      if (sitting.regular > 0) parts.add('${sitting.regular} Regular');
      lines.add('Sitting (${sitting.total}): ${parts.join(", ")}');
    }

    if (standing.total > 0) {
      final parts = <String>[];
      if (standing.pwd > 0) parts.add('${standing.pwd} PWD');
      if (standing.senior > 0) parts.add('${standing.senior} Senior');
      if (standing.student > 0) parts.add('${standing.student} Student');
      if (standing.regular > 0) parts.add('${standing.regular} Regular');
      lines.add('Standing (${standing.total}): ${parts.join(", ")}');
    }

    return lines.join('\n');
  }
}

/// Holds passenger counts by type
class PassengerTypeCount {
  int pwd = 0;
  int senior = 0;
  int student = 0;
  int regular = 0;

  int get total => pwd + senior + student + regular;

  bool get isEmpty => total == 0;
  bool get isNotEmpty => total > 0;

  @override
  String toString() =>
      'PWD: $pwd, Senior: $senior, Student: $student, Regular: $regular (Total: $total)';
}

/// Result of seat assignment operation
class SeatAssignmentResult {
  final bool success;
  final String? errorMessage;
  final String? errorDetails;
  final PassengerTypeCount? sittingAssignments;
  final PassengerTypeCount? standingAssignments;

  SeatAssignmentResult._({
    required this.success,
    this.errorMessage,
    this.errorDetails,
    this.sittingAssignments,
    this.standingAssignments,
  });

  factory SeatAssignmentResult.success({
    required PassengerTypeCount sittingAssignments,
    required PassengerTypeCount standingAssignments,
  }) {
    return SeatAssignmentResult._(
      success: true,
      sittingAssignments: sittingAssignments,
      standingAssignments: standingAssignments,
    );
  }

  factory SeatAssignmentResult.error({
    required String message,
    String? details,
  }) {
    return SeatAssignmentResult._(
      success: false,
      errorMessage: message,
      errorDetails: details,
    );
  }

  int get totalSitting => sittingAssignments?.total ?? 0;
  int get totalStanding => standingAssignments?.total ?? 0;
  int get totalPassengers => totalSitting + totalStanding;

  /// Check if priority passengers (PWD/Senior) are assigned to standing
  bool get hasPriorityInStanding {
    if (standingAssignments == null) return false;
    return standingAssignments!.pwd > 0 || standingAssignments!.senior > 0;
  }

  /// Generate warning message if priority passengers are standing
  String? get priorityWarningMessage {
    if (!hasPriorityInStanding) return null;

    final parts = <String>[];
    if (standingAssignments!.pwd > 0) {
      parts.add('${standingAssignments!.pwd} PWD');
    }
    if (standingAssignments!.senior > 0) {
      parts.add('${standingAssignments!.senior} Senior');
    }

    return 'Note: ${parts.join(" and ")} assigned to standing due to limited sitting capacity';
  }
}
