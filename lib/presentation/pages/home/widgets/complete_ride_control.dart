import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pasada_driver_side/presentation/pages/home/widgets/complete_ride_button.dart';
import 'package:pasada_driver_side/presentation/providers/passenger/passenger_provider.dart';
import 'package:pasada_driver_side/presentation/providers/quota/quota_provider.dart';
import 'package:pasada_driver_side/domain/services/passenger_capacity.dart';
import 'package:pasada_driver_side/presentation/pages/home/utils/snackbar_utils.dart';

class CompleteRideControl extends StatefulWidget {
  const CompleteRideControl({
    super.key,
    required this.isVisible,
    required this.ongoingBookingId,
  });

  final bool isVisible;
  final String? ongoingBookingId;

  @override
  State<CompleteRideControl> createState() => _CompleteRideControlState();
}

class _CompleteRideControlState extends State<CompleteRideControl> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final isMutating =
        context.select<PassengerProvider, bool>((p) => p.isMutatingBooking);
    return CompleteRideButton(
      isVisible: widget.isVisible && widget.ongoingBookingId != null,
      isEnabled: !_isProcessing && !isMutating,
      isLoading: _isProcessing || isMutating,
      onTap: () async {
        if (widget.ongoingBookingId == null || _isProcessing) return;
        setState(() => _isProcessing = true);
        String seatType = 'Sitting';
        final passengerProvider =
            Provider.of<PassengerProvider>(context, listen: false);

        try {
          try {
            final booking = passengerProvider.bookings
                .firstWhere((b) => b.id == widget.ongoingBookingId);
            seatType = booking.seatType;
          } catch (_) {}

          final success = await passengerProvider
              .markBookingAsCompleted(widget.ongoingBookingId!);
          if (!mounted) return;

          if (success) {
            final capacityResult =
                await PassengerCapacity().decrementCapacity(context, seatType);
            if (!mounted) return;
            if (capacityResult.success) {
              SnackBarUtils.showSuccess(context, 'Ride completed successfully');
              context.read<QuotaProvider>().fetchQuota(context);
              // quotaProvider.setQuota(context);
            } else {
              // rollback booking status if capacity update failed
              await passengerProvider
                  .markBookingAsAccepted(widget.ongoingBookingId!);
              SnackBarUtils.showError(context,
                  capacityResult.errorMessage ?? 'Capacity update failed');
            }
          } else {
            SnackBarUtils.showError(context, 'Failed to complete ride');
          }
        } catch (_) {
          if (!mounted) return;
          SnackBarUtils.showError(context, 'Failed to complete ride');
        } finally {
          if (mounted) setState(() => _isProcessing = false);
        }
      },
    );
  }
}
