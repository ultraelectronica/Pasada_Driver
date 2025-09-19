import 'package:flutter/material.dart';
import 'package:pasada_driver_side/common/constants/text_styles.dart';
import 'package:pasada_driver_side/presentation/pages/home/utils/home_constants.dart';

class ResetCapacityButton extends StatelessWidget {
  final bool isVisible;
  final VoidCallback onTap;

  const ResetCapacityButton({
    super.key,
    required this.isVisible,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    final size = MediaQuery.of(context).size;

    return Positioned(
      bottom: size.height * HomeConstants.resetButtonBottomFraction,
      right: size.width * HomeConstants.sideButtonRightFraction,
      child: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.red.shade700, width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.refresh,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(height: 4),
                Text(
                  'Reset\nCapacity',
                  textAlign: TextAlign.center,
                  style:
                      Styles().textStyle(10, Styles.w600Weight, Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
