import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pasada_driver_side/common/constants/constants.dart';
import 'package:pasada_driver_side/common/constants/text_styles.dart';
import 'package:pasada_driver_side/presentation/providers/driver/driver_provider.dart';
import 'package:pasada_driver_side/presentation/providers/map_provider.dart';
import 'package:pasada_driver_side/presentation/pages/route_setup/route_selection_sheet.dart';
import 'package:pasada_driver_side/presentation/providers/passenger/passenger_provider.dart';
import 'package:pasada_driver_side/presentation/pages/home/utils/snackbar_utils.dart';
import 'package:cherry_toast/resources/arrays.dart';

/// Button to start driving.
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
                          'Later',
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

  void _startDriving(
      BuildContext context, DriverProvider driverProvider) async {
    final mapProvider = context.read<MapProvider>();

    // Guard: require a vehicle assigned to this driver account
    final vehicleId = driverProvider.vehicleID;
    final normalizedVehicleId = vehicleId.trim().toLowerCase();
    final hasVehicle = normalizedVehicleId.isNotEmpty &&
        normalizedVehicleId != 'n/a' &&
        normalizedVehicleId != 'null';

    if (!hasVehicle) {
      SnackBarUtils.show(
        context,
        'Vehicle required to start Driving',
        'Your account has no vehicle assigned. Please contact your admin before going Driving.',
        duration: const Duration(seconds: 3),
        backgroundColor: Colors.red,
        position: Position.top,
        animationType: AnimationType.fromTop,
      );
      return;
    }

    // Guard: require a valid, loaded route
    final bool hasValidRoute = driverProvider.routeID > 0 &&
        mapProvider.routeState == RouteState.loaded;

    if (!hasValidRoute) {
      final selected = await RouteSelectionSheet.show(context);
      if (selected == null) {
        SnackBarUtils.show(
          context,
          'Select a route before going Driving',
          'Go to Route Selection to select a route',
          backgroundColor: Colors.red,
        );
        return;
      }
    }

    await driverProvider.updateStatusToDB('Driving');
    // Ensure the new status is preserved if app is backgrounded immediately
    driverProvider.setLastDriverStatus('Driving');

    // Trigger initial bookings fetch
    context.read<PassengerProvider>().getBookingRequestsID(context);

    // ignore: use_build_context_synchronously
    SnackBarUtils.show(context, 'Status set to Driving', 'Ingat manong!',
        backgroundColor: Constants.GREEN_COLOR,
        duration: const Duration(seconds: 2),
        position: Position.top,
        animationType: AnimationType.fromTop);
  }
}
