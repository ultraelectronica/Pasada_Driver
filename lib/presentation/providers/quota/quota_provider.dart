import 'package:flutter/foundation.dart';

class QuotaProvider extends ChangeNotifier {
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

  Future<void> fetchQuota() async {}
}
