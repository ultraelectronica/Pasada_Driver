import 'package:flutter/material.dart';
import 'package:pasada_driver_side/common/constants/text_styles.dart';
import 'package:pasada_driver_side/presentation/pages/home/utils/home_constants.dart';

class CompleteRideButton extends StatelessWidget {
  final bool isVisible;
  final bool isEnabled;
  final bool isLoading;
  final VoidCallback onTap;
  final String label;

  const CompleteRideButton({
    super.key,
    required this.isVisible,
    required this.onTap,
    this.isEnabled = true,
    this.isLoading = false,
    this.label = 'Complete Ride',
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
                  ? Colors.orange
                  : Colors.orange.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!isLoading) ...[
                  const Icon(
                    Icons.done_all,
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
                  isLoading ? 'Processing…' : label,
                  style: Styles().textStyle(18, Styles.semiBold, Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class BulkCompleteRideButton extends StatelessWidget {
  final bool isVisible;
  final bool isEnabled;
  final bool isLoading;
  final VoidCallback onTap;
  final String label;

  const BulkCompleteRideButton({
    super.key,
    required this.isVisible,
    required this.onTap,
    this.isEnabled = true,
    this.isLoading = false,
    this.label = 'Drop off passengers',
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
                  ? Colors.orange.shade700
                  : Colors.orange.shade700.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!isLoading) ...[
                  const Icon(
                    Icons.group,
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
                  isLoading ? 'Processing…' : label,
                  style: Styles().textStyle(16, Styles.semiBold, Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
