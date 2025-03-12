import 'package:flutter/material.dart';

// this class is used to store values just like a global variable
class DriverProvider with ChangeNotifier {
  String? _driverID;
  String? _vehicleID;
  String _driverStatus = 'Online';
  int? _passengerCapacity;

  String? get driverID => _driverID;
  String? get vehicleID => _vehicleID;
  String get driverStatus => _driverStatus;
  int? get passengerCapacity => _passengerCapacity;

  void setDriverID(String? value) {
    _driverID = value;
    notifyListeners();
  }

  void setVehicleID(String? value) {
    _vehicleID = value;
    notifyListeners();
  }

  void setDriverStatus(String value) {
    _driverStatus = value;
    notifyListeners();
  }

  void setPassengerCapacity(int value) {
    _passengerCapacity = value;
    notifyListeners();
  }
}
