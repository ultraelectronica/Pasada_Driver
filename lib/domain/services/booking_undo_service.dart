import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pasada_driver_side/presentation/providers/passenger/passenger_provider.dart';
import 'package:pasada_driver_side/presentation/providers/passenger/booking_action_model.dart';
import 'package:pasada_driver_side/data/models/booking_model.dart';
import 'package:pasada_driver_side/domain/services/passenger_capacity.dart';
import 'package:pasada_driver_side/presentation/pages/home/utils/snackbar_utils.dart';
import 'package:cherry_toast/resources/arrays.dart';

class BookingUndoService {
  static Future<void> undoBookings(
      BuildContext context, List<Booking> bookingsToUndo) async {
    final provider = Provider.of<PassengerProvider>(context, listen: false);
    if (provider.actionHistory.isEmpty) return;

    final action = provider.actionHistory.last;
    int successCount = 0;
    int failCount = 0;
    final List<String> successfulIds = [];

    for (final booking in bookingsToUndo) {
      final seatType = booking.seatType;

      try {
        bool statusUpdateSuccess = false;
        bool capacityUpdateSuccess = false;

        if (action.type == BookingActionType.pickup) {
          // Undo Pickup: Revert to Accepted, Decrement Capacity
          // Current status is Ongoing, we want Accepted.

          // 1. Update Status
          statusUpdateSuccess =
              await provider.markBookingAsAccepted(booking.id);

          if (statusUpdateSuccess) {
            // 2. Decrement Capacity
            final result =
                await PassengerCapacity().decrementCapacity(context, seatType);
            capacityUpdateSuccess = result.success;

            if (!capacityUpdateSuccess) {
              // If capacity failed, try to roll back status (re-pickup)
              await provider.markBookingAsOngoing(booking.id);
              statusUpdateSuccess = false; // Treat as total failure
            }
          }
        } else if (action.type == BookingActionType.dropoff) {
          // Undo Dropoff: Revert to Ongoing, Increment Capacity
          // Current status is Completed, we want Ongoing.

          // 1. Update Status
          statusUpdateSuccess = await provider.markBookingAsOngoing(booking.id);

          if (statusUpdateSuccess) {
            // 2. Increment Capacity
            final result =
                await PassengerCapacity().incrementCapacity(context, seatType);
            capacityUpdateSuccess = result.success;

            if (!capacityUpdateSuccess) {
              // If capacity failed, try to roll back status (re-complete)
              await provider.markBookingAsCompleted(booking.id);
              statusUpdateSuccess = false;
            }
          }
        }

        if (statusUpdateSuccess && capacityUpdateSuccess) {
          successCount++;
          successfulIds.add(booking.id);
        } else {
          failCount++;
        }
      } catch (e) {
        failCount++;
      }
    }

    // Update the action history with remaining bookings (those NOT successfully undone)
    // We filter the ORIGINAL list to preserve order and object integrity, removing successful ones.
    final remainingBookings =
        action.bookings.where((b) => !successfulIds.contains(b.id)).toList();

    provider.updateLastActionBookings(remainingBookings);

    if (successCount > 0) {
      SnackBarUtils.showSuccess(
        context,
        'Undo Successful',
        'Reverted $successCount actions.',
        position: Position.top,
        animationType: AnimationType.fromTop,
      );
    }

    if (failCount > 0) {
      SnackBarUtils.showError(
        context,
        'Undo Partial Failure',
        'Failed to revert $failCount actions.',
      );
    }
  }
}
