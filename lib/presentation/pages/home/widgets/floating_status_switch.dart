import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pasada_driver_side/common/constants/constants.dart';
import 'package:pasada_driver_side/common/constants/text_styles.dart';
import 'package:pasada_driver_side/presentation/providers/driver/driver_provider.dart';
import 'package:pasada_driver_side/presentation/providers/map_provider.dart';
import 'package:pasada_driver_side/presentation/pages/route_setup/route_selection_sheet.dart';
import 'package:pasada_driver_side/presentation/providers/passenger/passenger_provider.dart';
import 'package:pasada_driver_side/presentation/pages/home/utils/snackbar_utils.dart';

/// Toggle between Online ↔️ Driving status.
/// - Shows validation when trying to go Online while passengers are onboard.
class FloatingStatusSwitch extends StatelessWidget {
  const FloatingStatusSwitch({
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
      bottom: screenHeight * 0.11,
      left: screenWidth * 0.025,
      child: SizedBox(
        width: 135,
        height: 50,
        child: Material(
          color: Colors.white,
          elevation: 4,
          borderRadius: BorderRadius.circular(15),
          child: Padding(
            padding: const EdgeInsets.only(left: 12.0, right: 7.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isDriving ? 'Driving' : 'Online',
                  style: Styles().textStyle(
                    14,
                    Styles.semiBold,
                    isDriving ? Constants.GREEN_COLOR_DARK : Colors.grey[700]!,
                  ),
                ),
                Switch(
                  value: isDriving,
                  activeThumbColor: Constants.GREEN_COLOR,
                  activeTrackColor: Constants.GREEN_COLOR_LIGHT,
                  inactiveThumbColor: Constants.SWITCH_GREY_COLOR_DARK,
                  inactiveTrackColor: Constants.SWITCH_GREY_COLOR,
                  trackOutlineWidth: WidgetStateProperty.all(1.5),
                  onChanged: (value) {
                    if (value) {
                      _switchToDriving(context, driverProvider);
                    } else {
                      _trySwitchToOnline(
                          context, driverProvider, totalPassengers);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _switchToDriving(
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

    SnackBarUtils.show(context, 'Status set to Online', Colors.grey[700]!);
  }
}
