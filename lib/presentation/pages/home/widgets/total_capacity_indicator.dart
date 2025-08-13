import 'package:flutter/material.dart';
import 'package:pasada_driver_side/UI/constants.dart';
import 'package:pasada_driver_side/presentation/pages/home/widgets/floating_capacity.dart';
import 'package:provider/provider.dart';
import 'package:pasada_driver_side/presentation/providers/driver/driver_provider.dart';
import 'package:pasada_driver_side/domain/services/passenger_capacity.dart';

class TotalCapacityIndicator extends StatelessWidget {
  const TotalCapacityIndicator({
    super.key,
    required this.screenHeight,
    required this.screenWidth,
    required this.bottomFraction,
    required this.rightFraction,
  });

  final double screenHeight;
  final double screenWidth;
  final double bottomFraction;
  final double rightFraction;

  @override
  Widget build(BuildContext context) {
    final driverProvider = Provider.of<DriverProvider>(context, listen: false);
    final total =
        context.select<DriverProvider, int>((p) => p.passengerCapacity);

    return FloatingCapacity(
      driverProvider: driverProvider,
      passengerCapacity: PassengerCapacity(),
      screenHeight: screenHeight,
      screenWidth: screenWidth,
      bottomPosition: screenHeight * bottomFraction,
      rightPosition: screenWidth * rightFraction,
      icon: 'assets/svg/people.svg',
      text: total.toString(),
      canIncrement: false,
      onTap: () {
        // Refresh from DB
        PassengerCapacity().getPassengerCapacityToDB(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Capacity refreshed'),
          backgroundColor: Constants.GREEN_COLOR,
          duration: const Duration(seconds: 2),
        ));
      },
    );
  }
}
