import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pasada_driver_side/presentation/pages/home/widgets/complete_ride_button.dart';
import 'package:pasada_driver_side/presentation/providers/passenger/passenger_provider.dart';
import 'package:pasada_driver_side/domain/services/passenger_capacity.dart';
import 'package:pasada_driver_side/presentation/pages/home/utils/snackbar_utils.dart';

class CompleteRideControl extends StatelessWidget {
  const CompleteRideControl({
    super.key,
    required this.isVisible,
    required this.ongoingBookingId,
  });

  final bool isVisible;
  final String? ongoingBookingId;

  @override
  Widget build(BuildContext context) {
    return CompleteRideButton(
      isVisible: isVisible && ongoingBookingId != null,
      onTap: () async {
        if (ongoingBookingId == null) return;
        String seatType = 'Sitting';
        final passengerProvider =
            Provider.of<PassengerProvider>(context, listen: false);

        try {
          try {
            final booking = passengerProvider.bookings
                .firstWhere((b) => b.id == ongoingBookingId);
            seatType = booking.seatType;
          } catch (_) {}

          final success =
              await passengerProvider.markBookingAsCompleted(ongoingBookingId!);
          if (!context.mounted) return;

          if (success) {
            final capacityResult =
                await PassengerCapacity().decrementCapacity(context, seatType);
            if (!context.mounted) return;
            if (capacityResult.success) {
              SnackBarUtils.showSuccess(context, 'Ride completed successfully');
            }
          } else {
            SnackBarUtils.showError(context, 'Failed to complete ride');
          }
        } catch (_) {
          if (!context.mounted) return;
          SnackBarUtils.showError(context, 'Failed to complete ride');
        }
      },
    );
  }
}
