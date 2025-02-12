import 'package:flutter/material.dart';

// this class is used to store values just like a global variable
class DriverProvider with ChangeNotifier {
  String? _driverID;
  String _driverStatus = 'Online';

  String? get driverID => _driverID;
  String get driverStatus => _driverStatus;

  void setDriverID(String? value) {
    _driverID = value;
    notifyListeners();
  }

  void setDriverStatus(String value) {
    _driverStatus = value;
    notifyListeners();
  }
}
