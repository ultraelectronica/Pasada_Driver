import 'package:flutter/material.dart';
import 'package:pasada_driver_side/UI/text_styles.dart';
import 'package:provider/provider.dart';
import 'package:pasada_driver_side/Database/driver_provider.dart';

class PassengerCounter extends StatefulWidget {
  const PassengerCounter({super.key});

  @override
  State<PassengerCounter> createState() => PassengerCounterState();
}

class PassengerCounterState extends State<PassengerCounter> {
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final driverProvider = context.watch<DriverProvider>();

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Title and Counter Display
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                vertical: screenHeight * 0.03,
                horizontal: screenWidth * 0.06,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    'Passenger Counter',
                    style: Styles().textStyle(24, FontWeight.w600, Styles.customBlack),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${driverProvider.passengerCapacity}',
                    style: Styles().textStyle(48, FontWeight.w700, Styles.customBlack),
                  ),
                  Text(
                    'Current Passengers',
                    style: Styles().textStyle(16, FontWeight.w400, Colors.grey[600]!),
                  ),
                ],
              ),
            ),

            SizedBox(height: screenHeight * 0.04),

            // Control Buttons
            Column(
              children: [
                _CounterButton(
                  onPressed: () {
                    driverProvider.setPassengerCapacity(driverProvider.passengerCapacity + 1);
                  },
                  icon: Icons.add_circle_outline,
                  label: 'Add Passenger',
                  color: Colors.green[400]!,
                  screenHeight: screenHeight,
                  screenWidth: screenWidth,
                ),
                SizedBox(height: screenHeight * 0.02),
                _CounterButton(
                  onPressed: () {
                    if (driverProvider.passengerCapacity > 0) {
                      driverProvider.setPassengerCapacity(driverProvider.passengerCapacity - 1);
                    }
                  },
                  icon: Icons.remove_circle_outline,
                  label: 'Remove Passenger',
                  color: Colors.red[400]!,
                  screenHeight: screenHeight,
                  screenWidth: screenWidth,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CounterButton extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String label;
  final Color color;
  final double screenHeight;
  final double screenWidth;

  const _CounterButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.color,
    required this.screenHeight,
    required this.screenWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: screenHeight * 0.2,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.5), width: 2),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(15),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: color),
              const SizedBox(height: 8),
              Text(
                label,
                style: Styles().textStyle(16, FontWeight.w600, color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
