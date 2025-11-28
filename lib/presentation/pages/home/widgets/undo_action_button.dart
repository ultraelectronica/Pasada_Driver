import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pasada_driver_side/presentation/providers/passenger/passenger_provider.dart';
import 'package:pasada_driver_side/presentation/providers/passenger/booking_action_model.dart';
import 'package:pasada_driver_side/data/models/booking_model.dart';
import 'package:pasada_driver_side/domain/services/booking_undo_service.dart';
import 'package:pasada_driver_side/Services/passenger_name_service.dart';
import 'package:pasada_driver_side/common/constants/text_styles.dart';
import 'package:pasada_driver_side/common/constants/constants.dart';
import 'package:flutter_svg/flutter_svg.dart';

class UndoActionButton extends StatelessWidget {
  const UndoActionButton({super.key});

  @override
  Widget build(BuildContext context) {
    final hasHistory = context
        .select<PassengerProvider, bool>((p) => p.actionHistory.isNotEmpty);

    if (!hasHistory) return const SizedBox.shrink();

    return Positioned(
      bottom: 100, // Adjust position as needed
      left: 20,
      child: FloatingActionButton.extended(
        onPressed: () => _showUndoDialog(context),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        label: const Text('Undo'),
        icon: const Icon(Icons.undo),
      ),
    );
  }

  Future<void> _showUndoDialog(BuildContext context) async {
    final provider = context.read<PassengerProvider>();
    if (provider.actionHistory.isEmpty) return;

    final action = provider.actionHistory.last;
    final actionName =
        action.type == BookingActionType.pickup ? 'Pickup' : 'Dropoff';

    // Default: Select all bookings to undo
    final Set<String> selectedIds = action.bookings.map((b) => b.id).toSet();

    final List<Booking>? bookingsToUndo = await showDialog<List<Booking>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Undo ',
                        style: Styles().textStyle(
                            18, Styles.normal, Styles.customBlackFont),
                      ),
                      Text(
                        '$actionName?',
                        style: Styles()
                            .textStyle(18, Styles.semiBold, Colors.orange),
                      )
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Select passengers to undo $actionName:',
                    style: Styles()
                        .textStyle(16, Styles.normal, Styles.customBlackFont),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: action.bookings.length,
                        itemBuilder: (ctx, index) {
                          final booking = action.bookings[index];
                          final isSelected = selectedIds.contains(booking.id);

                          return FutureBuilder<String?>(
                            future: PassengerNameService.instance
                                .getDisplayNameForPassengerId(
                                    booking.passengerId ?? ''),
                            builder: (context, snapshot) {
                              final name = snapshot.data ?? '#${booking.id}';
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8.0, vertical: 4.0),
                                child: Material(
                                  color: isSelected
                                      ? Colors.orange.withValues(alpha: 0.2)
                                      : Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    side: const BorderSide(color: Colors.grey),
                                    borderRadius: BorderRadius.circular(16.0),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: CheckboxListTile(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16.0),
                                    ),
                                    value: isSelected,
                                    onChanged: (val) {
                                      setState(() {
                                        if (val == true) {
                                          selectedIds.add(booking.id);
                                        } else {
                                          selectedIds.remove(booking.id);
                                        }
                                      });
                                    },
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12.0, vertical: 4.0),
                                    dense: true,
                                    secondary: Container(
                                      padding: const EdgeInsets.only(left: 5),
                                      child: Icon(Icons.person,
                                          size: 30,
                                          color: action.type ==
                                                  BookingActionType.pickup
                                              ? Constants.GRADIENT_COLOR_1
                                              : Colors.orange),
                                    ),
                                    title: Text(
                                      name,
                                      style: Styles().textStyle(
                                          16,
                                          Styles.normal,
                                          Styles.customBlackFont),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            SvgPicture.asset(
                                              'assets/svg/sitting.svg',
                                              width: 16,
                                              height: 16,
                                              colorFilter: ColorFilter.mode(
                                                  action.type ==
                                                          BookingActionType
                                                              .pickup
                                                      ? Constants
                                                          .GRADIENT_COLOR_1
                                                      : Colors.orange,
                                                  BlendMode.srcIn),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '  ${booking.seatType}',
                                              style: Styles().textStyle(
                                                  14,
                                                  Styles.normal,
                                                  Styles.customBlackFont),
                                            ),
                                          ],
                                        ),
                                        if (action.type ==
                                            BookingActionType.pickup)
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.start,
                                            children: [
                                              Icon(Icons.location_on,
                                                  size: 16,
                                                  color: Constants
                                                      .GRADIENT_COLOR_1),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  '${booking.pickupAddress}',
                                                  style: Styles().textStyle(
                                                      14,
                                                      Styles.normal,
                                                      Styles.customBlackFont),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        if (action.type ==
                                            BookingActionType.dropoff)
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.start,
                                            children: [
                                              const Icon(Icons.location_on,
                                                  size: 16,
                                                  color: Colors.orange),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  '  ${booking.dropoffAddress}',
                                                  style: Styles().textStyle(
                                                      14,
                                                      Styles.normal,
                                                      Styles.customBlackFont),
                                                  maxLines: 1,
                                                  // overflow:
                                                  //     TextOverflow.visible,
                                                ),
                                              ),
                                            ],
                                          ),
                                      ],
                                    ),
                                    controlAffinity:
                                        ListTileControlAffinity.trailing,
                                    activeColor: Colors.orange,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.grey.withValues(alpha: 0.2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: Text(
                          'Cancel',
                          style: Styles().textStyle(
                              16, Styles.normal, Styles.customBlackFont),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor: selectedIds.isEmpty
                              ? Colors.grey.withValues(alpha: 0.2)
                              : Colors.orange,
                          foregroundColor: selectedIds.isEmpty
                              ? Colors.grey.withValues(alpha: 0.2)
                              : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onPressed: selectedIds.isEmpty
                            ? null // Disable if none selected
                            : () {
                                final toUndo = action.bookings
                                    .where((b) => selectedIds.contains(b.id))
                                    .toList();
                                Navigator.of(dialogContext).pop(toUndo);
                              },
                        child: Text(
                          'Undo [ ${selectedIds.length} ]',
                          style: Styles().textStyle(
                              16,
                              selectedIds.isEmpty
                                  ? Styles.normal
                                  : Styles.semiBold,
                              selectedIds.isEmpty
                                  ? Styles.customBlackFont
                                  : Colors.white),
                        ),
                      ),
                    ),
                  ],
                )
              ],
            );
          },
        );
      },
    );

    if (bookingsToUndo != null && bookingsToUndo.isNotEmpty) {
      await BookingUndoService.undoBookings(context, bookingsToUndo);
    }
  }
}
