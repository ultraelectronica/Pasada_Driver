import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:pasada_driver_side/common/constants/constants.dart';
import 'package:pasada_driver_side/common/constants/text_styles.dart';
import 'package:pasada_driver_side/domain/services/passenger_capacity.dart';
import 'package:pasada_driver_side/presentation/providers/driver/driver_provider.dart';

/// Floating pill that shows / mutates passenger capacity (total, standing, sitting).
class FloatingCapacity extends StatelessWidget {
  const FloatingCapacity({
    super.key,
    required this.screenHeight,
    required this.screenWidth,
    required this.bottomPosition,
    required this.rightPosition,
    required this.driverProvider,
    required this.passengerCapacity,
    required this.icon,
    required this.text,
    required this.onTap,
    this.canIncrement = false,
    this.onDecrementTap,
  });

  final double screenHeight;
  final double screenWidth;
  final double bottomPosition;
  final double rightPosition;
  final DriverProvider driverProvider;
  final PassengerCapacity passengerCapacity;
  final String icon;
  final String text;
  final VoidCallback onTap;
  final bool canIncrement;
  final VoidCallback? onDecrementTap;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: bottomPosition,
      right: rightPosition,
      child: Row(
        children: [
          if (canIncrement && onDecrementTap != null)
            _buildDecrementButton(context),
          _buildMainIndicator(context),
        ],
      ),
    );
  }

  Widget _buildDecrementButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.white,
        elevation: 4,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          onTap: onDecrementTap,
          borderRadius: BorderRadius.circular(15),
          splashColor: Colors.red.withAlpha(77),
          highlightColor: Colors.red.withAlpha(26),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.red, width: 2),
            ),
            padding: const EdgeInsets.all(8),
            child: const Icon(Icons.remove_circle_outline,
                color: Colors.red, size: 22),
          ),
        ),
      ),
    );
  }

  Widget _buildMainIndicator(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 4,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        splashColor: Constants.GREEN_COLOR.withAlpha(77),
        highlightColor: Constants.GREEN_COLOR.withAlpha(26),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: canIncrement ? Colors.blue : Constants.GREEN_COLOR,
              width: 2,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                icon,
                colorFilter: ColorFilter.mode(
                  canIncrement ? Colors.blue : Constants.GREEN_COLOR,
                  BlendMode.srcIn,
                ),
                height: 30,
                width: 30,
              ),
              const SizedBox(width: 10),
              Text(
                text,
                style: Styles()
                    .textStyle(22, Styles.w600Weight, Styles.customBlackFont),
              ),
              if (canIncrement) ...[
                const SizedBox(width: 8),
                const Icon(Icons.add_circle_outline,
                    color: Colors.blue, size: 20),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
