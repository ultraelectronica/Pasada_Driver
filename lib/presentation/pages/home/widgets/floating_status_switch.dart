import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pasada_driver_side/UI/constants.dart';
import 'package:pasada_driver_side/UI/text_styles.dart';
import 'package:pasada_driver_side/presentation/providers/driver/driver_provider.dart';
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
    final driverProvider = context.watch<DriverProvider>();
    final bool isDriving = driverProvider.driverStatus == 'Driving';
    final int totalPassengers = driverProvider.passengerStandingCapacity +
        driverProvider.passengerSittingCapacity;

    return Positioned(
      bottom: screenHeight * 0.115,
      left: screenWidth * 0.05,
      child: SizedBox(
        width: 135,
        height: 50,
        child: Material(
          color: Colors.white,
          elevation: 4,
          borderRadius: BorderRadius.circular(15),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isDriving ? 'Driving' : 'Online',
                  style: Styles().textStyle(
                    14,
                    Styles.w600Weight,
                    isDriving ? Constants.GREEN_COLOR : Colors.grey[700]!,
                  ),
                ),
                Switch(
                  value: isDriving,
                  activeColor: Constants.GREEN_COLOR,
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

  void _switchToDriving(BuildContext context, DriverProvider driverProvider) {
    driverProvider.updateStatusToDB('Driving', context);
    driverProvider.setDriverStatus('Driving');
    driverProvider.setIsDriving(true);

    // Trigger initial bookings fetch
    context.read<PassengerProvider>().getBookingRequestsID(context);

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

    driverProvider.updateStatusToDB('Online', context);
    driverProvider.setDriverStatus('Online');
    driverProvider.setIsDriving(false);

    SnackBarUtils.show(context, 'Status set to Online', Colors.grey[700]!);
  }
}
