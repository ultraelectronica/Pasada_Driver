import 'package:flutter/material.dart';
import 'package:pasada_driver_side/UI/constants.dart';
import 'package:pasada_driver_side/UI/text_styles.dart';
import '../utils/activity_constants.dart';

class RefreshButton extends StatelessWidget {
  final Size screenSize;
  final bool isRefreshing;
  final VoidCallback onPressed;

  const RefreshButton({
    super.key,
    required this.screenSize,
    required this.isRefreshing,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: screenSize.width * ActivityConstants.refreshButtonWidthFraction,
      height: screenSize.height * ActivityConstants.refreshButtonHeightFraction,
      decoration: BoxDecoration(
        border: Border.all(color: Constants.GREEN_COLOR, width: 2),
        borderRadius: BorderRadius.circular(50),
      ),
      child: TextButton.icon(
        onPressed: isRefreshing ? null : onPressed,
        icon: isRefreshing
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(Constants.GREEN_COLOR),
                ),
              )
            : const Icon(Icons.refresh),
        label: Text(
          isRefreshing ? 'Refreshing...' : 'Refresh Bookings',
          style: Styles().textStyle(14, FontWeight.w400, Styles.customBlack),
        ),
      ),
    );
  }
}
