import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cherry_toast/resources/arrays.dart';

import 'package:pasada_driver_side/common/constants/booking_constants.dart';
import 'package:pasada_driver_side/data/models/booking_model.dart';
import 'package:pasada_driver_side/domain/services/passenger_capacity.dart';
import 'package:pasada_driver_side/presentation/pages/home/utils/snackbar_utils.dart';
import 'package:pasada_driver_side/presentation/pages/home/widgets/confirm_pickup_button.dart';
import 'package:pasada_driver_side/presentation/providers/map_provider.dart';
import 'package:pasada_driver_side/presentation/providers/passenger/passenger_provider.dart';
import 'package:pasada_driver_side/Services/notification_service.dart';
import 'package:pasada_driver_side/Services/passenger_name_service.dart';
import 'package:pasada_driver_side/common/constants/constants.dart';

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

  static const double _locationEpsilon = 1e-5;

  List<Booking> _getPickupGroup(PassengerProvider passengerProvider) {
    if (widget.nearestBookingId == null) return [];

    final List<Booking> all = passengerProvider.bookings;
    Booking? target;
    for (final booking in all) {
      if (booking.id == widget.nearestBookingId) {
        target = booking;
        break;
      }
    }
    if (target == null) return [];

    final targetPickup = target.pickupLocation;

    return all.where((b) {
      if (b.rideStatus != BookingConstants.statusAccepted) return false;
      final latDiff = (b.pickupLocation.latitude - targetPickup.latitude).abs();
      final lngDiff =
          (b.pickupLocation.longitude - targetPickup.longitude).abs();
      return latDiff < _locationEpsilon && lngDiff < _locationEpsilon;
    }).toList();
  }

  Future<List<Booking>?> _showBulkSelectionDialog(
      BuildContext context, List<Booking> bookings) {
    return showDialog<List<Booking>>(
      context: context,
      builder: (dialogContext) {
        final Map<String, bool> selected = {
          for (final b in bookings) b.id: true,
        };

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Select passengers to pick up'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: bookings.length,
                  itemBuilder: (context, index) {
                    final booking = bookings[index];
                    final isSelected = selected[booking.id] ?? false;
                    final isManual = booking.isManualBooking;
                    final passengerId = booking.passengerId;

                    return FutureBuilder<String?>(
                      future: passengerId == null || passengerId.isEmpty
                          ? Future.value(null)
                          : PassengerNameService.instance
                              .getDisplayNameForPassengerId(passengerId),
                      builder: (context, snapshot) {
                        final hasName =
                            snapshot.connectionState == ConnectionState.done &&
                                snapshot.data != null &&
                                snapshot.data!.isNotEmpty;
                        final String primaryText =
                            hasName ? snapshot.data! : '# ${booking.id}';
                        final discountLabel = booking.discountLabel;

                        return CheckboxListTile(
                          value: isSelected,
                          activeColor: Constants.GREEN_COLOR,
                          onChanged: (value) {
                            setState(() {
                              selected[booking.id] = value ?? false;
                            });
                          },
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  primaryText,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              if (discountLabel != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    discountLabel.toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ),
                              const SizedBox(width: 4),
                              if (isManual)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'MANUAL',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Text(
                            hasName
                                ? '# ${booking.id} • Seat: ${booking.seatType}'
                                : 'Seat: ${booking.seatType}',
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              actions: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => Navigator.of(dialogContext).pop(null),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 10, horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            final result = bookings
                                .where((b) => selected[b.id] ?? false)
                                .toList();
                            Navigator.of(dialogContext).pop(result);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 10, horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: const Text(
                              'Confirm',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMutating =
        context.select<PassengerProvider, bool>((p) => p.isMutatingBooking);
    final passengerProvider = context.watch<PassengerProvider>();
    final pickupGroup = _getPickupGroup(passengerProvider);
    final groupCount = pickupGroup.length;
    final bool isControlVisible =
        widget.isVisible && widget.nearestBookingId != null;

    if (!isControlVisible) {
      return const SizedBox.shrink();
    }

    return Stack(
      children: [
        // Single pickup button (original behavior)
        ConfirmPickupButton(
          isVisible: true,
          isEnabled: !_isProcessing && !isMutating,
          isLoading: _isProcessing || isMutating,
          onTap: () async {
            if (widget.nearestBookingId == null || _isProcessing) return;

            setState(() => _isProcessing = true);

            try {
              final provider =
                  Provider.of<PassengerProvider>(context, listen: false);

              final booking = provider.bookings
                  .where((b) => b.id == widget.nearestBookingId)
                  .cast<Booking?>()
                  .firstOrNull;

              if (booking == null) {
                SnackBarUtils.showError(context, 'Booking not found',
                    'Unable to confirm pickup for this passenger');
                return;
              }

              final bookingId = booking.id;
              final seatType = booking.seatType;

              final success = await provider.markBookingAsOngoing(bookingId);
              if (!mounted) return;

              if (success) {
                debugPrint(
                    '[PICKUP][NOTIFICATION] Cancelling pickup notification for booking: $bookingId');
                // Cancel the pickup notification since the passenger has been picked up
                await NotificationService.instance
                    .cancelNotificationByBookingId('Pickup: $bookingId');

                final capacityResult = await PassengerCapacity()
                    .incrementCapacity(context, seatType);
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
                  await provider.markBookingAsAccepted(bookingId);
                  SnackBarUtils.showError(
                      context,
                      capacityResult.errorMessage ?? 'Capacity update failed',
                      'Operation failed for booking $bookingId');
                }
              } else {
                SnackBarUtils.showError(context,
                    'Failed to confirm passenger pickup', 'Operation failed');
              }
            } catch (_) {
              if (!mounted) return;
              SnackBarUtils.showError(context,
                  'Failed to confirm passenger pickup', 'Operation failed');
            } finally {
              if (mounted) setState(() => _isProcessing = false);
            }
          },
        ),

        // Bulk pickup button – only when there is more than one passenger at this pickup
        if (groupCount > 1)
          BulkConfirmPickupButton(
            isVisible: true,
            isEnabled: !_isProcessing && !isMutating,
            isLoading: _isProcessing || isMutating,
            label: 'Pickup $groupCount passengers',
            onTap: () async {
              if (_isProcessing) return;

              setState(() => _isProcessing = true);

              try {
                final provider =
                    Provider.of<PassengerProvider>(context, listen: false);
                List<Booking> bookingsToProcess = _getPickupGroup(provider);

                if (bookingsToProcess.isEmpty) {
                  SnackBarUtils.showError(
                      context,
                      'No passengers found at this pickup location',
                      'Operation cancelled');
                  return;
                }

                // If multiple passengers share this pickup, let driver select which ones
                final selected =
                    await _showBulkSelectionDialog(context, bookingsToProcess);
                if (!mounted) return;
                if (selected == null || selected.isEmpty) {
                  // User cancelled or deselected all
                  return;
                }
                bookingsToProcess = selected;

                int successCount = 0;

                for (final booking in bookingsToProcess) {
                  final bookingId = booking.id;
                  final seatType = booking.seatType;

                  final success =
                      await provider.markBookingAsOngoing(bookingId);
                  if (!mounted) return;

                  if (success) {
                    debugPrint(
                        '[PICKUP][BULK][NOTIFICATION] Cancelling pickup notification for booking: $bookingId');
                    // Cancel the pickup notification since the passenger has been picked up
                    await NotificationService.instance
                        .cancelNotificationByBookingId('Pickup: $bookingId');

                    final capacityResult = await PassengerCapacity()
                        .incrementCapacity(context, seatType);
                    if (!mounted) return;
                    if (capacityResult.success) {
                      successCount++;
                    } else {
                      // rollback booking status if capacity update failed
                      await provider.markBookingAsAccepted(bookingId);
                      SnackBarUtils.showError(
                          context,
                          capacityResult.errorMessage ??
                              'Capacity update failed',
                          'Operation failed for booking $bookingId');
                    }
                  } else {
                    SnackBarUtils.showError(
                        context,
                        'Failed to confirm passenger pickup for booking $bookingId',
                        'Operation failed');
                  }
                }

                if (!mounted) return;

                if (successCount > 0) {
                  final message = successCount > 1
                      ? '$successCount passengers picked up successfully'
                      : 'Passenger picked up successfully';
                  SnackBarUtils.showSuccess(
                    context,
                    message,
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
                }
              } catch (_) {
                if (!mounted) return;
                SnackBarUtils.showError(context,
                    'Failed to confirm passenger pickup', 'Operation failed');
              } finally {
                if (mounted) setState(() => _isProcessing = false);
              }
            },
          ),
      ],
    );
  }
}
