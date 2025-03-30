import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pasada_driver_side/UI/message.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// this class is used to store values just like a global variable
class DriverProvider with ChangeNotifier {
  String _driverID = 'N/A';
  String _driverStatus = 'Online';

  String? _vehicleID;
  String? _lastDriverStatus;
  int _passengerCapacity = 0;
  bool _isDriving = false;

  String _driverFirstName = 'firstName';
  String _driverLastName = 'lastName';
  String _driverNumber = '00000000000';

  final SupabaseClient supabase = Supabase.instance.client;

  String? get driverID => _driverID;
  String? get vehicleID => _vehicleID;
  String get driverStatus => _driverStatus;

  String? get lastDriverStatus => _lastDriverStatus;
  int get passengerCapacity => _passengerCapacity;

  bool get isDriving => _isDriving;

  String? get driverFirstName => _driverFirstName;
  String? get driverLastName => _driverLastName;
  String get driverNumber => _driverNumber;

  void setDriverID(String value) {
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

// for state management when the app is in the background
  void setLastDriverStatus(String value) {
    _lastDriverStatus = value;
    notifyListeners();
  }

  void setPassengerCapacity(int value) {
    _passengerCapacity = value;
    notifyListeners();
  }

  void setIsDriving(bool value) {
    _isDriving = value;
    notifyListeners();
  }

  // Driver Creds
  void setDriverFirstName(String value) {
    _driverFirstName = value;
    notifyListeners();
  }

  void setDriverLastName(String value) {
    _driverLastName = value;
    notifyListeners();
  }

  void setDriverNumber(String value) {
    _driverNumber = value;
    notifyListeners();
  }

  Future<void> updateStatusToDB(String newStatus, BuildContext context) async {
    // String driverID = this.driverID;
    final response = await supabase
        .from('driverTable')
        .update({'driving_status': newStatus})
        .eq('driver_id', driverID!)
        .select()
        .single();

    if (kDebugMode) {
      print('Updated status: ${response['driving_status']}');
      ShowMessage().showToast('Updated status: ${response['driving_status']}');
    }

    _lastDriverStatus = _driverStatus;
    _driverStatus = newStatus;
  }

  Future<void> getPassengerCapacity(BuildContext context) async {
    try {
      String? vehicleID = _vehicleID;

      if (vehicleID == null) {
        if (kDebugMode) {
          print('DriverID not fount');
        }
        return;
      }
      final response = await supabase
          .from('vehicleTable')
          .select('passenger_capacity')
          .eq('vehicle_id', vehicleID)
          .single();

      if (kDebugMode) {
        print('Capacity: ${response['passenger_capacity'].toString()}');
        ShowMessage().showToast(
            'Capacity: ${response['passenger_capacity'].toString()}');
      }

      // sets the capacity to the provider
      _passengerCapacity = response['passenger_capacity'];
    } catch (e) {
      ShowMessage().showToast('Error: $e');
    }
  }

  Future<void> getDriverCreds() async {
    try {
      final response = await supabase
          .from('driverTable')
          .select('first_name, last_name, driver_number')
          .eq('driver_id', _driverID)
          .single();

      // ShowMessage().showToast(response.toString());

      if (kDebugMode) {
        print(response.toString());
      }

      _driverFirstName = response['first_name'].toString();
      _driverLastName = response['last_name'].toString();
      _driverNumber = response['driver_number'].toString();
    } catch (e) {
      ShowMessage().showToast('Error: $e');
      if (kDebugMode) {
        print('Error: $e');
      }
    }
  }
}
