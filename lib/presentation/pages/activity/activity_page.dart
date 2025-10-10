import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pasada_driver_side/common/constants/constants.dart';
import 'package:pasada_driver_side/common/constants/text_styles.dart';
import 'package:pasada_driver_side/presentation/providers/quota/quota_provider.dart';
import 'package:provider/provider.dart';

class ActivityPage extends StatefulWidget {
  const ActivityPage({super.key});

  @override
  ActivityPageState createState() => ActivityPageState();
}

class ActivityPageState extends State<ActivityPage> {

  final NumberFormat _numberFormat = NumberFormat.decimalPattern();
  String _formatPeso(int value) => '₱${_numberFormat.format(value)}';

  @override
  void initState() {
    super.initState();
    // Trigger quota fetch after first frame to ensure providers are ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<QuotaProvider>().fetchQuota(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Read target quotas from provider
    final quotaProv = context.watch<QuotaProvider>();
    final int todayTargetEarnings = quotaProv.todayTargetQuota;
    final int weeklyTargetEarnings = quotaProv.weeklyTargetQuota;
    final int monthlyTargetEarnings = quotaProv.monthlyTargetQuota;

    final int todayEarnings = quotaProv.todayQuota;
    final int weeklyEarnings = quotaProv.weeklyQuota;
    final int monthlyEarnings = quotaProv.monthlyQuota;

    // Safe progress calculations
    final double todayProgress =
        todayTargetEarnings > 0 ? todayEarnings / todayTargetEarnings : 0.0;
    final double weeklyProgress =
        weeklyTargetEarnings > 0 ? weeklyEarnings / weeklyTargetEarnings : 0.0;
    final double monthlyProgress = monthlyTargetEarnings > 0
        ? monthlyEarnings / monthlyTargetEarnings
        : 0.0;
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
                              progress: todayProgress,
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
                              progress: weeklyProgress,
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
                        progress: monthlyProgress,
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

  Widget _earningMetric({
    required String label,
    required Color color,
    required double progress,
    required int currentEarnings,
    required int targetEarnings,
  }) {
    double circleSize = 100;
    double strokeWidth = 18;
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
      ],
    );
  }
}
