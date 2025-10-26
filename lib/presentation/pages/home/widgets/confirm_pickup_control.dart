import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pasada_driver_side/presentation/pages/home/widgets/confirm_pickup_button.dart';
import 'package:pasada_driver_side/presentation/providers/map_provider.dart';
import 'package:pasada_driver_side/presentation/providers/passenger/passenger_provider.dart';
import 'package:pasada_driver_side/domain/services/passenger_capacity.dart';
import 'package:pasada_driver_side/presentation/pages/home/utils/snackbar_utils.dart';
import 'package:cherry_toast/resources/arrays.dart';

class ConfirmPickupControl extends StatefulWidget {
  const ConfirmPickupControl({
    super.key,
    required this.isVisible,
    required this.nearestBookingId,
  });

  final bool isVisible;
  final String? nearestBookingId;

  @override
  State<ConfirmPickupControl> createState() => _ConfirmPickupControlState();
}

class _ConfirmPickupControlState extends State<ConfirmPickupControl> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final isMutating =
        context.select<PassengerProvider, bool>((p) => p.isMutatingBooking);
    return ConfirmPickupButton(
      isVisible: widget.isVisible && widget.nearestBookingId != null,
      isEnabled: !_isProcessing && !isMutating,
      isLoading: _isProcessing || isMutating,
      onTap: () async {
        if (widget.nearestBookingId == null || _isProcessing) return;

        setState(() => _isProcessing = true);

        String seatType = 'Sitting';
        final passengerProvider =
            Provider.of<PassengerProvider>(context, listen: false);

        try {
          // Determine seat type from current booking if available
          try {
            final booking = passengerProvider.bookings
                .firstWhere((b) => b.id == widget.nearestBookingId);
            seatType = booking.seatType;
          } catch (_) {}

          final success = await passengerProvider
              .markBookingAsOngoing(widget.nearestBookingId!);
          if (!mounted) return;

          if (success) {
            final capacityResult =
                await PassengerCapacity().incrementCapacity(context, seatType);
            if (!mounted) return;
            if (capacityResult.success) {
              SnackBarUtils.showSuccess(
                context,
                'Passenger picked up successfully',
                'Operation successful',
                position: Position.top,
                animationType: AnimationType.fromTop,
              );
              // Clear pickup marker once ride begins
              try {
                if (mounted) {
                  context.read<MapProvider>().clearBookingMarkerLocation();
                }
              } catch (_) {}
            } else {
              // rollback booking status if capacity update failed
              await passengerProvider
                  .markBookingAsAccepted(widget.nearestBookingId!);
              SnackBarUtils.showError(
                  context,
                  capacityResult.errorMessage ?? 'Capacity update failed',
                  'Operation failed');
            }
          } else {
            SnackBarUtils.showError(context,
                'Failed to confirm passenger pickup', 'Operation failed');
          }
        } catch (_) {
          if (!mounted) return;
          SnackBarUtils.showError(context, 'Failed to confirm passenger pickup',
              'Operation failed');
        } finally {
          if (mounted) setState(() => _isProcessing = false);
        }
      },
    );
  }
}
