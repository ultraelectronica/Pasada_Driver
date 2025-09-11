import 'package:flutter/material.dart';
import 'package:pasada_driver_side/UI/constants.dart';
import 'package:provider/provider.dart';
import 'package:pasada_driver_side/presentation/providers/driver/driver_provider.dart';
import 'package:pasada_driver_side/presentation/pages/home/utils/snackbar_utils.dart';

/// Small floating button that refreshes booking requests (only when driver is in "Driving" mode).
class FloatingRefreshBookingButton extends StatelessWidget {
  const FloatingRefreshBookingButton({
    super.key,
    required this.screenHeight,
    required this.screenWidth,
    required this.isLoading,
    required this.onRefresh,
  });

  final double screenHeight;
  final double screenWidth;
  final bool isLoading;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final bool isDriving = context
        .select<DriverProvider, bool>((p) => p.driverStatus == 'Driving');

    return Positioned(
      bottom: screenHeight * 0.18,
      left: screenWidth * 0.025,
      child: SizedBox(
        width: 50,
        height: 50,
        child: Material(
          color: isDriving ? Colors.white : Colors.grey[300],
          elevation: isDriving ? 4 : 2,
          borderRadius: BorderRadius.circular(15),
          child: InkWell(
            onTap: () {
              if (isDriving) {
                if (!isLoading) {
                  onRefresh();
                  SnackBarUtils.show(context, 'Refreshing booking requests...',
                      Constants.GREEN_COLOR);
                }
              } else {
                SnackBarUtils.show(context,
                    'To get bookings, switch to "Driving" mode', Colors.orange);
              }
            },
            borderRadius: BorderRadius.circular(15),
            splashColor: (isDriving ? Colors.blue : Colors.grey).withAlpha(77),
            highlightColor:
                (isDriving ? Colors.blue : Colors.grey).withAlpha(26),
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                      ),
                    )
                  : Icon(
                      isDriving ? Icons.refresh : Icons.directions_car,
                      color: isDriving ? Colors.blue : Colors.grey,
                      size: 24,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
