import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pasada_driver_side/common/constants/constants.dart';
import 'package:pasada_driver_side/common/constants/text_styles.dart';

class ActivityPage extends StatefulWidget {
  const ActivityPage({super.key});

  @override
  ActivityPageState createState() => ActivityPageState();
}

class ActivityPageState extends State<ActivityPage> {
  int todayEarnings = 200;
  int todayTargetEarnings = 1000;
  int weeklyEarnings = 1500;
  int weeklyTargetEarnings = 5000;
  int monthlyEarnings = 9000;
  int monthlyTargetEarnings = 10000;

  final NumberFormat _numberFormat = NumberFormat.decimalPattern();
  String _formatPeso(int value) => '₱${_numberFormat.format(value)}';

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // backgroundColor: Colors.grey.shade300,
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildTitle(),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Constants.BLACK_COLOR.withValues(alpha: 0.2),
                            width: 1),
                        // boxShadow: [
                        //   BoxShadow(
                        //     color: Constants.BLACK_COLOR.withValues(alpha: 0.1),
                        //     blurRadius: 15,
                        //     offset: const Offset(0, 15),
                        //   ),
                        // ],
                      ),
                      child: Column(
                        children: [
                          // Circular progress section
                          Container(
                            padding: const EdgeInsets.all(16),
                            child: _earningMetric(
                              label: 'Today\'s Earnings',
                              color: Constants.GREEN_COLOR,
                              progress: todayEarnings / todayTargetEarnings,
                              currentEarnings: todayEarnings,
                              targetEarnings: todayTargetEarnings,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        // color: Constants.WHITE_COLOR,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Constants.BLACK_COLOR.withValues(alpha: 0.2),
                            width: 1),
                        // boxShadow: [
                        //   BoxShadow(
                        //     color: Constants.BLACK_COLOR.withValues(alpha: 0.1),
                        //     blurRadius: 15,
                        //     offset: const Offset(0, 15),
                        //   ),
                        // ],
                      ),
                      child: Column(
                        children: [
                          // Circular progress section
                          Container(
                            padding: const EdgeInsets.all(16),
                            child: _earningMetric(
                              label: 'Weekly Earnings',
                              color: Colors.blue,
                              progress: weeklyEarnings / weeklyTargetEarnings,
                              currentEarnings: weeklyEarnings,
                              targetEarnings: weeklyTargetEarnings,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  // color: Constants.WHITE_COLOR,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: Constants.BLACK_COLOR.withValues(alpha: 0.2),
                      width: 1),
                  // boxShadow: [
                  //   BoxShadow(
                  //     color: Constants.BLACK_COLOR.withValues(alpha: 0.1),
                  //     blurRadius: 15,
                  //     offset: const Offset(0, 15),
                  //   ),
                  // ],
                ),
                child: Column(
                  children: [
                    // Circular progress section
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: _earningMetric(
                        label: 'Monthly Earnings',
                        color: Colors.red,
                        progress: monthlyEarnings / monthlyTargetEarnings,
                        currentEarnings: monthlyEarnings,
                        targetEarnings: monthlyTargetEarnings,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitle() => SizedBox(
        width: double.infinity,
        child: Text('Driver Activity',
            style:
                Styles().textStyle(20, FontWeight.w600, Styles.customBlackFont),
            textAlign: TextAlign.center),
      );

  Widget _buildCircularEarningProgress(
      String title,
      int todayEarnings,
      int todayTargetEarnings,
      int weeklyEarnings,
      int weeklyTargetEarnings,
      int monthlyEarnings,
      int monthlyTargetEarnings) {
    final progress =
        todayTargetEarnings == 0 ? 0.0 : todayEarnings / todayTargetEarnings;
    final weeklyProgress =
        weeklyTargetEarnings == 0 ? 0.0 : weeklyEarnings / weeklyTargetEarnings;
    final monthlyProgress = monthlyTargetEarnings == 0
        ? 0.0
        : monthlyEarnings / monthlyTargetEarnings;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Text(
        //   title,
        //   style:
        //       Styles().textStyle(18, Styles.semiBold, Styles.customBlackFont),
        // ),
        // const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _earningMetric(
              label: "Today's Earnings",
              color: Constants.GREEN_COLOR,
              progress: progress,
              currentEarnings: todayEarnings,
              targetEarnings: todayTargetEarnings,
            ),
            // const SizedBox(width: 5),
            // _earningMetric(
            //   label: 'Weekly Earnings',
            //   color: Colors.blue,
            //   progress: weeklyProgress,
            //   currentEarnings: weeklyEarnings,
            //   targetEarnings: weeklyTargetEarnings,
            // ),
            // _earningMetric(
            //   label: 'Monthly\nEarnings',
            //   color: Colors.red,
            //   progress: monthlyProgress,
            //   currentEarnings: monthlyEarnings,
            //   targetEarnings: monthlyTargetEarnings,
            // ),
          ],
        ),
        // const SizedBox(height: 15),
        // _earningMetric(
        //   label: 'Monthly Earnings',
        //   color: Colors.red,
        //   progress: monthlyProgress,
        //   currentEarnings: monthlyEarnings,
        //   targetEarnings: monthlyTargetEarnings,
        // ),
      ],
    );
  }

  Widget _earningMetric({
    required String label,
    required Color color,
    required double progress,
    required int currentEarnings,
    required int targetEarnings,
  }) {
    double circleSize = 100;
    double strokeWidth = 18 ;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style:
              Styles().textStyle(14, Styles.semiBold, Styles.customBlackFont),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        // Circular progress indicator
        Stack(alignment: Alignment.center, children: [
          SizedBox(
            width: circleSize,
            height: circleSize,
            child: CircularProgressIndicator(
              value: 1,
              strokeWidth: strokeWidth,
              strokeCap: StrokeCap.round,
              valueColor:
                  AlwaysStoppedAnimation<Color>(color.withValues(alpha: 0.2)),
            ),
          ),
          SizedBox(
            width: circleSize,
            height: circleSize,
            child: CircularProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              strokeWidth: strokeWidth,
              strokeCap: StrokeCap.round,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          Column(
            children: [
              Text(
                _formatPeso(currentEarnings),
                style: Styles().textStyle(16, Styles.bold, color),
                textAlign: TextAlign.center,
              ),
              // Target earnings
              Text(
                '/${_formatPeso(targetEarnings)}',
                style: Styles()
                    .textStyle(12, Styles.medium, Styles.customBlackFont),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ]),
        const SizedBox(height: 15),

        // Current earnings
        // Text(
        //   '₱$current',
        //   style: Styles().textStyle(16, FontWeight.w700, color),
        //   textAlign: TextAlign.center,
        // ),

        // Text(
        //   'Target Earnings:',
        //   style: Styles().textStyle(14, Styles.medium, Styles.customBlackFont),
        //   textAlign: TextAlign.center,
        // ),

        // Divider
        // Container(
        //   width: 50,
        //   height: 1,
        //   margin: const EdgeInsets.symmetric(vertical: 1),
        //   color: Constants.BLACK_COLOR,
        // ),
      ],
    );
  }
}
