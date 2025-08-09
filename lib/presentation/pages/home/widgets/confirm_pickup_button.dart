import 'package:flutter/material.dart';
import 'package:pasada_driver_side/UI/text_styles.dart';
import 'package:pasada_driver_side/UI/constants.dart';
import 'package:pasada_driver_side/presentation/pages/home/utils/home_constants.dart';

class ConfirmPickupButton extends StatelessWidget {
  final bool isVisible;
  final VoidCallback onTap;

  const ConfirmPickupButton({
    super.key,
    required this.isVisible,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    final size = MediaQuery.of(context).size;

    return Positioned(
      bottom: size.height * HomeConstants.actionButtonBottomFraction,
      left: size.width * HomeConstants.actionButtonHorizontalInsetFraction,
      right: size.width * HomeConstants.actionButtonHorizontalInsetFraction,
      child: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: Constants.GREEN_COLOR,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  color: Colors.white,
                  size: 28,
                ),
                const SizedBox(width: 10),
                Text(
                  'Confirm Pickup',
                  style:
                      Styles().textStyle(18, Styles.w600Weight, Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
