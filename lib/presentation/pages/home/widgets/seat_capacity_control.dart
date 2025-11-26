import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pasada_driver_side/presentation/providers/driver/driver_provider.dart';
import 'package:pasada_driver_side/presentation/providers/passenger/passenger_provider.dart';
import 'package:pasada_driver_side/common/constants/booking_constants.dart';
import 'package:pasada_driver_side/domain/services/passenger_capacity.dart';
import 'package:pasada_driver_side/presentation/pages/home/utils/snackbar_utils.dart';
import 'package:pasada_driver_side/presentation/pages/home/widgets/floating_capacity.dart';
// import 'package:pasada_driver_side/common/config/app_config.dart';

class SeatCapacityControl extends StatelessWidget {
  const SeatCapacityControl({
    super.key,
    required this.screenHeight,
    required this.screenWidth,
    required this.bottomFraction,
    required this.rightFraction,
    required this.seatType, // 'Standing' or 'Sitting'
  });

  final double screenHeight;
  final double screenWidth;
  final double bottomFraction;
  final double rightFraction;
  final String seatType;

  bool get _isStanding => seatType == 'Standing';

  @override
  Widget build(BuildContext context) {
    final driverProvider = context.read<DriverProvider>();

    // Current counts
    final int seatCount = context.select<DriverProvider, int>((p) =>
        _isStanding ? p.passengerStandingCapacity : p.passengerSittingCapacity);

    // Booked counts (ongoing only)
    final int bookedCount = context.select<PassengerProvider, int>((pp) => pp
        .bookings
        .where((b) => b.rideStatus == BookingConstants.statusOngoing)
        .where((b) => b.seatType == seatType)
        .length);

    final int manualHeadroom = (seatCount - bookedCount).clamp(0, seatCount);

    return FloatingCapacity(
      driverProvider: driverProvider,
      passengerCapacity: PassengerCapacity(),
      screenHeight: screenHeight,
      screenWidth: screenWidth,
      bottomPosition: screenHeight * bottomFraction,
      rightPosition: screenWidth * rightFraction,
      icon: _isStanding ? 'assets/svg/standing.svg' : 'assets/svg/sitting.svg',
      text: seatCount.toString(),
      canIncrement:
          false, //(AppConfig.isTestMode) ? true : false, TODO: Uncomment this if need na mag add mabilis ng capacity
      onTap: () {},
      // async {
      //   if (AppConfig.isTestMode) {
      //     final result = _isStanding
      //         ? await PassengerCapacity().manualIncrementStanding(context)
      //         : await PassengerCapacity().manualIncrementSitting(context);

      //     if (result.success) {
      //       SnackBarUtils.pop(context, '$seatType passenger added manually',
      //           'Capacity updated successfully',
      //           backgroundColor: Colors.blue);
      //     } else {
      //       String errorMessage = 'Failed to add passenger';
      //       Color errorColor = Colors.red;
      //       switch (result.errorType) {
      //         case PassengerCapacity.ERROR_DRIVER_NOT_DRIVING:
      //           errorMessage =
      //               'Cannot add passenger: Driver is not in Driving status';
      //           break;
      //         case PassengerCapacity.ERROR_CAPACITY_EXCEEDED:
      //           errorMessage = 'Cannot add passenger: Maximum capacity reached';
      //           errorColor = Colors.orange;
      //           break;
      //         case PassengerCapacity.ERROR_NEGATIVE_VALUES:
      //           errorMessage = 'Cannot add passenger: Invalid operation';
      //           break;
      //         default:
      //           errorMessage = result.errorMessage ?? 'Unknown error occurred';
      //       }
      //       SnackBarUtils.show(context, errorMessage, 'Operation failed',
      //           backgroundColor: errorColor,
      //           duration: const Duration(seconds: 3));
      //     }
      //   }
      // },
      onDecrementTap: manualHeadroom > 0
          ? () async {
              final result = _isStanding
                  ? await PassengerCapacity().manualDecrementStanding(context)
                  : await PassengerCapacity().manualDecrementSitting(context);

              if (result.success) {
                SnackBarUtils.pop(
                    context,
                    '$seatType passenger removed manually',
                    'Capacity updated successfully',
                    backgroundColor: Colors.red);
              } else {
                String errorMessage = 'Failed to remove passenger';
                Color errorColor = Colors.red;
                switch (result.errorType) {
                  case PassengerCapacity.ERROR_DRIVER_NOT_DRIVING:
                    errorMessage =
                        'Cannot remove passenger: Driver is not in Driving status';
                    break;
                  case PassengerCapacity.ERROR_MANUAL_FORBIDDEN:
                    errorMessage =
                        'Cannot remove: passenger was added via booking';
                    errorColor = Colors.orange;
                    break;
                  case PassengerCapacity.ERROR_NEGATIVE_VALUES:
                    errorMessage =
                        'Cannot remove: No ${seatType.toLowerCase()} passengers';
                    errorColor = Colors.grey;
                    break;
                  default:
                    errorMessage =
                        result.errorMessage ?? 'Unknown error occurred';
                }
                SnackBarUtils.show(context, errorMessage, 'Operation failed',
                    backgroundColor: errorColor,
                    duration: const Duration(seconds: 3));
              }
            }
          : null,
    );
  }
}
