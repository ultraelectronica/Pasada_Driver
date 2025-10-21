import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:pasada_driver_side/common/constants/constants.dart';
import 'package:pasada_driver_side/common/constants/text_styles.dart';
import 'package:pasada_driver_side/presentation/providers/map_provider.dart';
import 'package:pasada_driver_side/presentation/pages/route_setup/route_selection_sheet.dart';
import 'package:pasada_driver_side/presentation/providers/driver/driver_provider.dart';
import 'package:pasada_driver_side/presentation/providers/passenger/passenger_provider.dart';

class FloatingRouteButton extends StatelessWidget {
  const FloatingRouteButton({
    super.key,
    required this.screenHeight,
    required this.screenWidth,
  });

  final double screenHeight;
  final double screenWidth;

  @override
  Widget build(BuildContext context) {
    final routeName = context.select<MapProvider, String?>(
      (provider) => provider.routeName,
    );
    final isDriving = context.select<DriverProvider, bool>(
      (provider) => provider.driverStatus == 'Driving',
    );
    final hasActiveBooking =
        context.select<PassengerProvider, bool>((passenger) {
      return passenger.bookings
          .any((b) => b.rideStatus == 'accepted' || b.rideStatus == 'ongoing');
    });
    final bool isDisabled = isDriving || hasActiveBooking;

    return Positioned(
      bottom: screenHeight * 0.04,
      left: screenWidth * 0.02,
      child: isDisabled
          ? const SizedBox.shrink()
          : SizedBox(
              height: 50,
              child: Tooltip(
                message: isDisabled
                    ? 'Cannot change route while Driving or with active booking'
                    : 'Select and change your current route',
                preferBelow: false,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Styles.customBlackFont,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 4,
                  ),
                  onPressed: isDisabled
                      ? null
                      : () async {
                          await RouteSelectionSheet.show(context);
                        },
                  icon: Icon(
                    Icons.alt_route,
                    color: Constants.GREEN_COLOR,
                    size: 25,
                  ),
                  label: Text(
                    routeName == null || routeName.isEmpty
                        ? 'Select Route'
                        : routeName,
                    overflow: TextOverflow.ellipsis,
                    style: Styles()
                        .textStyle(15, Styles.semiBold, Styles.customBlackFont),
                  ),
                ),
              ),
            ),
    );
  }
}
