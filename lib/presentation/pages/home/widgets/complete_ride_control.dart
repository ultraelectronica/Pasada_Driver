import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pasada_driver_side/presentation/pages/home/widgets/complete_ride_button.dart';
import 'package:pasada_driver_side/presentation/providers/passenger/passenger_provider.dart';
import 'package:pasada_driver_side/presentation/providers/quota/quota_provider.dart';
import 'package:pasada_driver_side/domain/services/passenger_capacity.dart';
import 'package:pasada_driver_side/presentation/pages/home/utils/snackbar_utils.dart';
import 'package:pasada_driver_side/presentation/pages/home/controllers/id_acceptance_controller.dart';

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
        final String bookingId = widget.ongoingBookingId!;
        setState(() => _isProcessing = true);
        String seatType = 'Sitting';
        final passengerProvider =
            Provider.of<PassengerProvider>(context, listen: false);

        try {
          debugPrint('[COMPLETE] Start completion for booking: $bookingId');
          String? passengerIdImagePath;
          try {
            final booking =
                passengerProvider.bookings.firstWhere((b) => b.id == bookingId);
            seatType = booking.seatType;
            passengerIdImagePath = booking.passengerIdImagePath;
            debugPrint(
                '[COMPLETE] Loaded booking details. seatType=$seatType hasIdImage=${passengerIdImagePath != null && passengerIdImagePath.isNotEmpty}');
          } catch (_) {}

          final success =
              await passengerProvider.markBookingAsCompleted(bookingId);
          if (!mounted) return;

          if (success) {
            debugPrint(
                '[COMPLETE] Backend status update success. Decrementing capacity...');
            final capacityResult =
                await PassengerCapacity().decrementCapacity(context, seatType);
            if (!mounted) return;
            if (capacityResult.success) {
              debugPrint(
                  '[COMPLETE] Capacity decrement success. Considering auto-accept...');
              // Auto-accept discount ID if a discount request (ID image) exists
              try {
                if (passengerIdImagePath != null &&
                    passengerIdImagePath.isNotEmpty) {
                  debugPrint(
                      '[COMPLETE] Auto-accepting discount ID for booking: $bookingId');
                  await IdAcceptanceController().acceptID(bookingId);
                  debugPrint('[COMPLETE] Auto-accept invoked.');
                }
              } catch (_) {}
              SnackBarUtils.showSuccess(context, 'Ride completed successfully');
              context.read<QuotaProvider>().fetchQuota(context);
              // quotaProvider.setQuota(context);
            } else {
              debugPrint(
                  '[COMPLETE][ERROR] Capacity decrement failed: ${capacityResult.errorMessage}');
              // rollback booking status if capacity update failed
              await passengerProvider.markBookingAsAccepted(bookingId);
              SnackBarUtils.showError(context,
                  capacityResult.errorMessage ?? 'Capacity update failed');
            }
          } else {
            debugPrint('[COMPLETE][ERROR] Backend status update failed.');
            SnackBarUtils.showError(context, 'Failed to complete ride');
          }
        } catch (e, st) {
          debugPrint('[COMPLETE][EXCEPTION] $e');
          debugPrint(st.toString());
          if (!mounted) return;
          SnackBarUtils.showError(context, 'Failed to complete ride');
        } finally {
          if (mounted) setState(() => _isProcessing = false);
          debugPrint(
              '[COMPLETE] Completion flow ended for booking: $bookingId');
        }
      },
    );
  }
}
