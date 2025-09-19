import 'package:flutter/material.dart';
import 'package:pasada_driver_side/common/constants/constants.dart';
import 'package:pasada_driver_side/common/constants/text_styles.dart';
import '../utils/activity_constants.dart';

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final MaterialColor color;
  final IconData icon;
  final EdgeInsets padding;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
    this.padding = const EdgeInsets.symmetric(horizontal: 5, vertical: 10),
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(
            horizontal: ActivityConstants.statCardHorizontalMargin),
        padding: padding,
        decoration: BoxDecoration(
          color: color.shade50,
          border: Border.all(color: Constants.GREEN_COLOR, width: 2),
          borderRadius:
              BorderRadius.circular(ActivityConstants.statCardBorderRadius),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color.shade700, size: 24),
            const SizedBox(height: 4),
            Text(title,
                textAlign: TextAlign.center,
                style: Styles()
                    .textStyle(13, FontWeight.w600, Styles.customBlack)),
            const SizedBox(height: 8),
            Text(value,
                style: Styles().textStyle(28, FontWeight.w700, color.shade700)),
          ],
        ),
      ),
    );
  }
}
