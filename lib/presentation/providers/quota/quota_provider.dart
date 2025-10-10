import 'package:pasada_driver_side/presentation/providers/driver/driver_provider.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';

class QuotaProvider extends ChangeNotifier {
  final SupabaseClient supabase = Supabase.instance.client;

  int _todayQuota = 0;
  int _weeklyQuota = 0;
  int _monthlyQuota = 0;
  int _todayTargetQuota = 0;
  int _weeklyTargetQuota = 0;
  int _monthlyTargetQuota = 0;

  int get todayQuota => _todayQuota;
  int get weeklyQuota => _weeklyQuota;
  int get monthlyQuota => _monthlyQuota;
  int get todayTargetQuota => _todayTargetQuota;
  int get weeklyTargetQuota => _weeklyTargetQuota;
  int get monthlyTargetQuota => _monthlyTargetQuota;

  void setTodayQuota(int todayQuota) {
    _todayQuota = todayQuota;
    notifyListeners();
  }

  void setWeeklyQuota(int weeklyQuota) {
    _weeklyQuota = weeklyQuota;
    notifyListeners();
  }

  void setMonthlyQuota(int monthlyQuota) {
    _monthlyQuota = monthlyQuota;
    notifyListeners();
  }

  void setTodayTargetQuota(int todayTargetQuota) {
    _todayTargetQuota = todayTargetQuota;
    notifyListeners();
  }

  void setWeeklyTargetQuota(int weeklyTargetQuota) {
    _weeklyTargetQuota = weeklyTargetQuota;
    notifyListeners();
  }

  void setMonthlyTargetQuota(int monthlyTargetQuota) {
    _monthlyTargetQuota = monthlyTargetQuota;
    notifyListeners();
  }

  Future<void> setQuota(BuildContext context) async {
    try {
      final driverProvider = context.read<DriverProvider>();
      String driverIdStr = driverProvider.driverID;

      // Ensure driver ID is loaded before proceeding
      if (driverIdStr.isEmpty) {
        final loaded = await driverProvider.loadFromSecureStorage(context);
        if (!loaded || driverProvider.driverID.isEmpty) {
          debugPrint(
              'Error: Driver ID is empty on fetchQuota (after load attempt)');
          return;
        }
        driverIdStr = driverProvider.driverID;
      }

      final int? driverID = int.tryParse(driverIdStr);
      if (driverID == null) {
        debugPrint(
            'Error: Invalid driver ID format on fetchQuota: $driverIdStr');
        return;
      }

      // Compute local period starts
      final now = DateTime.now();
      final startOfTodayLocal = DateTime(now.year, now.month, now.day);
      final startOfWeekLocal = startOfTodayLocal.subtract(
          Duration(days: startOfTodayLocal.weekday - 1)); // Monday as start
      final startOfMonthLocal = DateTime(now.year, now.month, 1);

      // Convert to UTC for DB comparisons
      final startOfTodayUtcDT = startOfTodayLocal.toUtc();
      final startOfWeekUtcDT = startOfWeekLocal.toUtc();
      final startOfMonthUtcDT = startOfMonthLocal.toUtc();

      // Single monthly query; compute day/week/month sums client-side
      final getThisMonthBooking = await supabase
          .from('bookings')
          .select('fare, created_at')
          .match({'driver_id': driverID, 'ride_status': 'completed'}).gte(
              'created_at', startOfMonthUtcDT.toIso8601String());

      _todayQuota = 0;
      _weeklyQuota = 0;
      _monthlyQuota = 0;

      if (getThisMonthBooking.isEmpty) {
        debugPrint('No bookings found for this month');
        notifyListeners();
        return;
      }

      for (final row in getThisMonthBooking) {
        final int fare = (row['fare'] as num?)?.toInt() ?? 0;
        final dynamic createdAtRaw = row['created_at'];
        DateTime? createdAt;
        if (createdAtRaw is String) {
          createdAt = DateTime.tryParse(createdAtRaw)?.toUtc();
        } else if (createdAtRaw is DateTime) {
          createdAt = createdAtRaw.toUtc();
        }
        if (createdAt == null) continue;

        if (!createdAt.isBefore(startOfMonthUtcDT)) {
          _monthlyQuota += fare;
        }
        if (!createdAt.isBefore(startOfWeekUtcDT)) {
          _weeklyQuota += fare;
        }
        if (!createdAt.isBefore(startOfTodayUtcDT)) {
          _todayQuota += fare;
        }
      }

      await supabase.from('driverQuotasTable').update({
        'current_quota_daily': _todayQuota,
        'current_quota_weekly': _weeklyQuota,
        'current_quota_monthly': _monthlyQuota,
      }).eq('driver_id', driverID);

      debugPrint(
          'Quotas computed — Today: $_todayQuota, Week: $_weeklyQuota, Month: $_monthlyQuota');
      notifyListeners();
    } catch (e) {
      debugPrint('Error setting quota: $e');
    }
  }

  Future<void> fetchQuota(BuildContext context) async {
    try {
      final driverProvider = context.read<DriverProvider>();
      String driverIdStr = driverProvider.driverID;

      // Ensure driver ID is loaded before proceeding
      if (driverIdStr.isEmpty) {
        final loaded = await driverProvider.loadFromSecureStorage(context);
        if (!loaded || driverProvider.driverID.isEmpty) {
          debugPrint(
              'Error: Driver ID is empty on fetchQuota (after load attempt)');
          return;
        }
        driverIdStr = driverProvider.driverID;
      }

      final int? driverID = int.tryParse(driverIdStr);
      if (driverID == null) {
        debugPrint(
            'Error: Invalid driver ID format on fetchQuota: $driverIdStr');
        return;
      }

      final response = await supabase
          .from('driverQuotasTable')
          .select('quota_daily, quota_weekly, quota_monthly')
          .eq('driver_id', driverID)
          .maybeSingle();

      if (response == null) {
        debugPrint('No quota row found for driver_id: $driverID');
        return;
      }

      _todayTargetQuota = (response['quota_daily'] as num?)?.toInt() ?? 0;
      _weeklyTargetQuota = (response['quota_weekly'] as num?)?.toInt() ?? 0;
      _monthlyTargetQuota = (response['quota_monthly'] as num?)?.toInt() ?? 0;

      notifyListeners();
      debugPrint(
          'Quota fetched: $_todayTargetQuota, $_weeklyTargetQuota, $_monthlyTargetQuota');
      debugPrint('Setting quota');
      setQuota(context);
    } catch (e) {
      debugPrint('Error fetching quota: $e');
    }
  }
}
