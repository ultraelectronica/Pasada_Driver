import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pasada_driver_side/common/constants/constants.dart';
import 'package:pasada_driver_side/common/constants/text_styles.dart';
import 'package:pasada_driver_side/presentation/providers/driver/driver_provider.dart';
import 'package:pasada_driver_side/presentation/providers/map_provider.dart';
import 'package:pasada_driver_side/presentation/pages/route_setup/route_selection_sheet.dart';
import 'package:pasada_driver_side/presentation/providers/passenger/passenger_provider.dart';
import 'package:pasada_driver_side/presentation/pages/home/utils/snackbar_utils.dart';

/// Button to start driving.
/// - Shows validation when trying to start driving while passengers are onboard.
class FloatingStartDrivingButton extends StatelessWidget {
  const FloatingStartDrivingButton({
    super.key,
    required this.screenHeight,
    required this.screenWidth,
  });

  final double screenHeight;
  final double screenWidth;

  @override
  Widget build(BuildContext context) {
    final bool isDriving = context
        .select<DriverProvider, bool>((p) => p.driverStatus == 'Driving');
    final int totalPassengers = context.select<DriverProvider, int>(
        (p) => p.passengerStandingCapacity + p.passengerSittingCapacity);
    final driverProvider = context.read<DriverProvider>();
    return Positioned(
      bottom: screenHeight * 0.115,
      left: screenWidth * 0.02,
      height: 50,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Styles.customBlackFont,
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          elevation: 4,
        ),
        onPressed: () {
          showDialog(
            barrierColor: Constants.BLACK_COLOR.withValues(alpha: 0.5),
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: Constants.WHITE_COLOR,
              title: Text(
                'Start Driving?',
                style: Styles()
                    .textStyle(24, Styles.semiBold, Styles.customBlackFont),
              ),
              content: Padding(
                padding: const EdgeInsets.all(10),
                child: Text(
                  'Bago mag drive, mag dasal at siguraduhing safe ang pag d\'drive.',
                  textAlign: TextAlign.center,
                  style: Styles()
                      .textStyle(17, Styles.normal, Styles.customBlackFont),
                ),
              ),
              actions: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black,
                          side: BorderSide(
                            color: Constants.BLACK_COLOR.withValues(alpha: 0.5),
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Mamaya',
                          style: Styles()
                              .textStyle(16, Styles.semiBold, Colors.black),
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Constants.GREEN_COLOR,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          _startDriving(context, driverProvider);
                        },
                        child: Text(
                          'Start Driving',
                          style: Styles()
                              .textStyle(16, Styles.semiBold, Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
        label: Text('Start Driving',
            style: Styles()
                .textStyle(15, Styles.semiBold, Styles.customBlackFont)),
        icon: Icon(
          Icons.directions_bus,
          color: Constants.GREEN_COLOR,
          size: 25,
        ),
      ),
    );
  }

// return Positioned(
//   bottom: screenHeight * 0.11,
//   left: screenWidth * 0.025,
//   child: SizedBox(
//     width: 135,
//     height: 50,
//     child: Material(
//       color: Colors.white,
//       elevation: 4,
//       borderRadius: BorderRadius.circular(15),
//       child: Padding(
//         padding: const EdgeInsets.only(left: 12.0, right: 7.0),
//         child: Row(
//           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//           children: [
//             Text(
//               isDriving ? 'Driving' : 'Online',
//               style: Styles().textStyle(
//                 14,
//                 Styles.semiBold,
//                 isDriving ? Constants.GREEN_COLOR_DARK : Colors.grey[700]!,
//               ),
//             ),
//             Switch(
//               value: isDriving,
//               activeThumbColor: Constants.GREEN_COLOR,
//               activeTrackColor: Constants.GREEN_COLOR_LIGHT,
//               inactiveThumbColor: Constants.SWITCH_GREY_COLOR_DARK,
//               inactiveTrackColor: Constants.SWITCH_GREY_COLOR,
//               trackOutlineWidth: WidgetStateProperty.all(1.5),
//               onChanged: (value) {
//                 if (value) {
//                   _switchToDriving(context, driverProvider);
//                 } else {
//                   _trySwitchToOnline(
//                       context, driverProvider, totalPassengers);
//                 }
//               },
//             ),
//           ],
//         ),
//       ),
//     ),
//   ),
// );
// }

  void _startDriving(
      BuildContext context, DriverProvider driverProvider) async {
    final mapProvider = context.read<MapProvider>();

    // Guard: require a valid, loaded route
    final bool hasValidRoute = driverProvider.routeID > 0 &&
        mapProvider.routeState == RouteState.loaded;

    if (!hasValidRoute) {
      final selected = await RouteSelectionSheet.show(context);
      if (selected == null) {
        SnackBarUtils.show(
          context,
          'Select a route before going Driving',
          Colors.red,
        );
        return;
      }
    }

    await driverProvider.updateStatusToDB('Driving');
    // Ensure the new status is preserved if app is backgrounded immediately
    driverProvider.setLastDriverStatus('Driving');

    // Trigger initial bookings fetch
    // Note: downstream flows depend on Driving status now being set
    // so we fetch bookings after status flips.
    // ignore: use_build_context_synchronously
    context.read<PassengerProvider>().getBookingRequestsID(context);

    // ignore: use_build_context_synchronously
    SnackBarUtils.show(context, 'Status set to Driving', Constants.GREEN_COLOR);
  }

  void _trySwitchToOnline(BuildContext context, DriverProvider driverProvider,
      int totalPassengers) {
    if (totalPassengers > 0) {
      SnackBarUtils.show(
        context,
        'Cannot go Online: Vehicle still has $totalPassengers passenger${totalPassengers > 1 ? "s" : ""}',
        Colors.red,
        duration: const Duration(seconds: 3),
      );
      return;
    }

    driverProvider.updateStatusToDB('Online');
    // Ensure the new status is preserved if app is backgrounded immediately
    driverProvider.setLastDriverStatus('Online');

    SnackBarUtils.show(context, 'Status set to Online', Colors.grey[700]!);
  }
}
