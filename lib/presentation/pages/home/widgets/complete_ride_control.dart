import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cherry_toast/resources/arrays.dart';

import 'package:pasada_driver_side/common/constants/booking_constants.dart';
import 'package:pasada_driver_side/data/models/booking_model.dart';
import 'package:pasada_driver_side/domain/services/passenger_capacity.dart';
import 'package:pasada_driver_side/presentation/pages/home/controllers/id_acceptance_controller.dart';
import 'package:pasada_driver_side/presentation/pages/home/utils/snackbar_utils.dart';
import 'package:pasada_driver_side/presentation/pages/home/widgets/complete_ride_button.dart';
import 'package:pasada_driver_side/presentation/providers/map_provider.dart';
import 'package:pasada_driver_side/presentation/providers/passenger/passenger_provider.dart';
import 'package:pasada_driver_side/presentation/providers/quota/quota_provider.dart';
import 'package:pasada_driver_side/Services/notification_service.dart';
import 'package:pasada_driver_side/Services/passenger_name_service.dart';
import 'package:pasada_driver_side/common/constants/constants.dart';

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

  static const double _locationEpsilon = 1e-5;

  List<Booking> _getDropoffGroup(PassengerProvider passengerProvider) {
    if (widget.ongoingBookingId == null) return [];

    final List<Booking> all = passengerProvider.bookings;
    Booking? target;
    for (final booking in all) {
      if (booking.id == widget.ongoingBookingId) {
        target = booking;
        break;
      }
    }
    if (target == null) return [];

    final targetDropoff = target.dropoffLocation;

    return all.where((b) {
      if (b.rideStatus != BookingConstants.statusOngoing) return false;
      final latDiff =
          (b.dropoffLocation.latitude - targetDropoff.latitude).abs();
      final lngDiff =
          (b.dropoffLocation.longitude - targetDropoff.longitude).abs();
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
              title: const Text('Select passengers to drop off'),
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
                              color: Colors.orange,
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
    final dropoffGroup = _getDropoffGroup(passengerProvider);
    final groupCount = dropoffGroup.length;

    final bool isControlVisible =
        widget.isVisible && widget.ongoingBookingId != null;

    if (!isControlVisible) {
      return const SizedBox.shrink();
    }

    return Stack(
      children: [
        // Single-ride complete button (original behavior)
        CompleteRideButton(
          isVisible: true,
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
              bool? isIdAccepted;
              try {
                final booking = passengerProvider.bookings
                    .firstWhere((b) => b.id == bookingId);
                seatType = booking.seatType;
                passengerIdImagePath = booking.passengerIdImagePath;
                isIdAccepted = booking.isIdAccepted;
                debugPrint(
                    '[COMPLETE] Loaded booking details. seatType=$seatType hasIdImage=${passengerIdImagePath != null && passengerIdImagePath.isNotEmpty}');
              } catch (_) {}

              final success =
                  await passengerProvider.markBookingAsCompleted(bookingId);
              if (!mounted) return;

              if (success) {
                debugPrint(
                    '[COMPLETE][NOTIFICATION] Cancelling notifications for booking: $bookingId');
                // Cancel both pickup and dropoff notifications since we're completing the ride
                await NotificationService.instance
                    .cancelNotificationByBookingId('Pickup: $bookingId');
                await NotificationService.instance
                    .cancelNotificationByBookingId('Dropoff: $bookingId');
                debugPrint(
                    '[COMPLETE] Backend status update success. Decrementing capacity...');
                final capacityResult = await PassengerCapacity()
                    .decrementCapacity(context, seatType);
                if (!mounted) return;
                if (capacityResult.success) {
                  debugPrint(
                      '[COMPLETE] Capacity decrement success. Considering auto-accept...');
                  // Clear any lingering pickup marker and passenger markers
                  try {
                    if (mounted) {
                      context.read<MapProvider>().clearBookingMarkerLocation();
                    }
                    if (mounted) {
                      context.read<MapProvider>().clearPassengerMarkers();
                    }
                  } catch (e) {
                    debugPrint(
                        '[COMPLETE][ERROR] Failed to clear map markers: $e');
                  }
                  // Auto-accept discount ID only if request exists and decision is still pending
                  try {
                    if (passengerIdImagePath != null &&
                        passengerIdImagePath.isNotEmpty &&
                        isIdAccepted == null) {
                      debugPrint(
                          '[COMPLETE] Auto-accepting discount ID for booking: $bookingId');
                      await IdAcceptanceController().acceptID(bookingId);
                      debugPrint('[COMPLETE] Auto-accept invoked.');
                    } else {
                      debugPrint(
                          '[COMPLETE] Skipping auto-accept. hasIdImage=${passengerIdImagePath != null && passengerIdImagePath.isNotEmpty} isIdAccepted=$isIdAccepted');
                    }
                  } catch (e) {
                    debugPrint(
                        '[COMPLETE][ERROR] Failed to auto-accept ID: $e');
                  }
                  SnackBarUtils.showSuccess(
                    context,
                    'Ride completed successfully',
                    'Passenger $bookingId has been dropped off successfully',
                    position: Position.top,
                    animationType: AnimationType.fromTop,
                  );
                  context.read<QuotaProvider>().fetchQuota(context);
                } else {
                  debugPrint(
                      '[COMPLETE][ERROR] Capacity decrement failed: ${capacityResult.errorMessage}');
                  // rollback booking status if capacity update failed
                  await passengerProvider.markBookingAsAccepted(bookingId);
                  SnackBarUtils.showError(
                      context,
                      capacityResult.errorMessage ?? 'Capacity update failed',
                      'Please try again');
                }
              } else {
                debugPrint('[COMPLETE][ERROR] Backend status update failed.');
                SnackBarUtils.showError(
                    context, 'Failed to complete ride', 'Please try again');
              }
            } catch (e, st) {
              debugPrint('[COMPLETE][ERROR] Failed to complete ride: $e');
              debugPrint('[COMPLETE][ERROR] Stack trace: $st');
              if (!mounted) return;
              SnackBarUtils.showError(
                  context, 'Failed to complete ride', 'Please try again');
            } finally {
              if (mounted) setState(() => _isProcessing = false);
              debugPrint(
                  '[COMPLETE] Completion flow ended for booking: $bookingId');
            }
          },
        ),

        // Bulk complete button – only when there is more than one passenger at this dropoff
        if (groupCount > 1)
          BulkCompleteRideButton(
            isVisible: true,
            isEnabled: !_isProcessing && !isMutating,
            isLoading: _isProcessing || isMutating,
            label: 'Drop off $groupCount passengers',
            onTap: () async {
              if (_isProcessing) return;
              setState(() => _isProcessing = true);
              try {
                final provider =
                    Provider.of<PassengerProvider>(context, listen: false);
                List<Booking> bookingsToProcess = _getDropoffGroup(provider);

                if (bookingsToProcess.isEmpty) {
                  SnackBarUtils.showError(
                      context,
                      'No passengers found at this dropoff location',
                      'Operation cancelled');
                  return;
                }

                // Let driver select which passengers at this location to drop off
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
                  final String bookingId = booking.id;
                  String seatType = booking.seatType;
                  String? passengerIdImagePath = booking.passengerIdImagePath;
                  bool? isIdAccepted = booking.isIdAccepted;

                  debugPrint(
                      '[COMPLETE][BULK] Start completion for booking: $bookingId');

                  final success =
                      await provider.markBookingAsCompleted(bookingId);
                  if (!mounted) return;

                  if (success) {
                    debugPrint(
                        '[COMPLETE][BULK][NOTIFICATION] Cancelling notifications for booking: $bookingId');
                    // Cancel both pickup and dropoff notifications since we're completing the ride
                    await NotificationService.instance
                        .cancelNotificationByBookingId('Pickup: $bookingId');
                    await NotificationService.instance
                        .cancelNotificationByBookingId('Dropoff: $bookingId');
                    debugPrint(
                        '[COMPLETE][BULK] Backend status update success. Decrementing capacity...');
                    final capacityResult = await PassengerCapacity()
                        .decrementCapacity(context, seatType);
                    if (!mounted) return;
                    if (capacityResult.success) {
                      successCount++;
                      debugPrint(
                          '[COMPLETE][BULK] Capacity decrement success. Considering auto-accept...');
                      // Auto-accept discount ID only if request exists and decision is still pending
                      try {
                        if (passengerIdImagePath != null &&
                            passengerIdImagePath.isNotEmpty &&
                            isIdAccepted == null) {
                          debugPrint(
                              '[COMPLETE][BULK] Auto-accepting discount ID for booking: $bookingId');
                          await IdAcceptanceController().acceptID(bookingId);
                          debugPrint('[COMPLETE][BULK] Auto-accept invoked.');
                        } else {
                          debugPrint(
                              '[COMPLETE][BULK] Skipping auto-accept. hasIdImage=${passengerIdImagePath != null && passengerIdImagePath.isNotEmpty} isIdAccepted=$isIdAccepted');
                        }
                      } catch (e) {
                        debugPrint(
                            '[COMPLETE][BULK][ERROR] Failed to auto-accept ID: $e');
                      }
                    } else {
                      debugPrint(
                          '[COMPLETE][BULK][ERROR] Capacity decrement failed: ${capacityResult.errorMessage}');
                      // rollback booking status if capacity update failed
                      await provider.markBookingAsAccepted(bookingId);
                      SnackBarUtils.showError(
                          context,
                          capacityResult.errorMessage ??
                              'Capacity update failed',
                          'Please try again for booking $bookingId');
                    }
                  } else {
                    debugPrint(
                        '[COMPLETE][BULK][ERROR] Backend status update failed for booking: $bookingId.');
                    SnackBarUtils.showError(
                        context,
                        'Failed to complete ride for passenger $bookingId',
                        'Please try again');
                  }
                }

                if (!mounted) return;

                if (successCount > 0) {
                  debugPrint(
                      '[COMPLETE][BULK] Successfully completed rides for $successCount passenger(s).');
                  // Clear any lingering pickup marker and passenger markers
                  try {
                    if (mounted) {
                      context.read<MapProvider>().clearBookingMarkerLocation();
                    }
                    if (mounted) {
                      context.read<MapProvider>().clearPassengerMarkers();
                    }
                  } catch (e) {
                    debugPrint(
                        '[COMPLETE][BULK][ERROR] Failed to clear map markers: $e');
                  }

                  SnackBarUtils.showSuccess(
                    context,
                    'Rides completed successfully',
                    '$successCount passengers have been dropped off successfully',
                    position: Position.top,
                    animationType: AnimationType.fromTop,
                  );
                  context.read<QuotaProvider>().fetchQuota(context);
                }
              } catch (e, st) {
                debugPrint(
                    '[COMPLETE][BULK][ERROR] Failed to complete rides: $e');
                debugPrint('[COMPLETE][BULK][ERROR] Stack trace: $st');
                if (!mounted) return;
                SnackBarUtils.showError(
                    context, 'Failed to complete rides', 'Please try again');
              } finally {
                if (mounted) setState(() => _isProcessing = false);
                debugPrint(
                    '[COMPLETE][BULK] Bulk completion flow ended for dropoff group');
              }
            },
          ),
      ],
    );
  }
}
