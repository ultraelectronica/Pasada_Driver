import 'package:flutter/material.dart';
import 'package:pasada_driver_side/UI/text_styles.dart';
import 'package:pasada_driver_side/UI/constants.dart';
import 'package:pasada_driver_side/presentation/pages/home/utils/home_constants.dart';

class ConfirmPickupButton extends StatelessWidget {
  final bool isVisible;
  final bool isEnabled;
  final bool isLoading;
  final VoidCallback onTap;

  const ConfirmPickupButton({
    super.key,
    required this.isVisible,
    required this.onTap,
    this.isEnabled = true,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    final size = MediaQuery.of(context).size;

    final enabled = isEnabled && !isLoading;
    return Positioned(
      bottom: size.height * HomeConstants.actionButtonBottomFraction,
      left: size.width * HomeConstants.actionButtonHorizontalInsetFraction,
      right: size.width * HomeConstants.actionButtonHorizontalInsetFraction,
      child: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(15),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: enabled
                  ? Constants.GREEN_COLOR
                  : Constants.GREEN_COLOR.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!isLoading) ...[
                  const Icon(
                    Icons.check_circle_outline,
                    color: Colors.white,
                    size: 28,
                  ),
                  const SizedBox(width: 10),
                ] else ...[
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Text(
                  isLoading ? 'Processing…' : 'Confirm Pickup',
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
