import 'package:flutter/material.dart';

// this class is used to store values just like a global variable
class DriverProvider with ChangeNotifier {
  String? _driverID;

  String? get driverID => _driverID;

  void setDriverID(String? value) {
    _driverID = value;
    notifyListeners();
  }
}