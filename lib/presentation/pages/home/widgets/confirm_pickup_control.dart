import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pasada_driver_side/presentation/pages/home/widgets/confirm_pickup_button.dart';
import 'package:pasada_driver_side/presentation/providers/passenger/passenger_provider.dart';
import 'package:pasada_driver_side/domain/services/passenger_capacity.dart';
import 'package:pasada_driver_side/presentation/pages/home/utils/snackbar_utils.dart';

class ConfirmPickupControl extends StatelessWidget {
  const ConfirmPickupControl({
    super.key,
    required this.isVisible,
    required this.nearestBookingId,
  });

  final bool isVisible;
  final String? nearestBookingId;

  @override
  Widget build(BuildContext context) {
    return ConfirmPickupButton(
      isVisible: isVisible && nearestBookingId != null,
      onTap: () async {
        if (nearestBookingId == null) return;

        String seatType = 'Sitting';
        final passengerProvider =
            Provider.of<PassengerProvider>(context, listen: false);

        try {
          // Determine seat type from current booking if available
          try {
            final booking = passengerProvider.bookings
                .firstWhere((b) => b.id == nearestBookingId);
            seatType = booking.seatType;
          } catch (_) {}

          final success =
              await passengerProvider.markBookingAsOngoing(nearestBookingId!);
          if (!context.mounted) return;

          if (success) {
            final capacityResult =
                await PassengerCapacity().incrementCapacity(context, seatType);
            if (!context.mounted) return;
            if (capacityResult.success) {
              SnackBarUtils.showSuccess(
                  context, 'Passenger picked up successfully');
            }
          } else {
            SnackBarUtils.showError(
                context, 'Failed to confirm passenger pickup');
          }
        } catch (_) {
          if (!context.mounted) return;
          SnackBarUtils.showError(
              context, 'Failed to confirm passenger pickup');
        }
      },
    );
  }
}
