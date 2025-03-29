import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// this class is used to store values just like a global variable
class DriverProvider with ChangeNotifier {
  String? _driverID;
  String? _vehicleID;
  String? _driverStatus;
  int _passengerCapacity = 0;
  final SupabaseClient supabase = Supabase.instance.client;

  String? get driverID => _driverID;
  String? get vehicleID => _vehicleID;
  String? get driverStatus => _driverStatus;
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

  Future<void> updateStatusToDB(String newStatus, BuildContext context) async {
    // String driverID = this.driverID;
    final response = await supabase
        .from('driverTable')
        .update({'driving_status': newStatus})
        .eq('driver_id', driverID!)
        .select()
        .single();

    if (kDebugMode) {
      print('New status: ${response['driving_status']}');
      _showToast('New status: ${response['driving_status']}');
    }

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
        _showToast('Capacity: ${response['passenger_capacity'].toString()}');
      }

      _passengerCapacity = response['passenger_capacity'];
    } catch (e) {
      _showToast('Error: $e');
    }
  }

  void _showToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.black,
      textColor: Colors.white,
    );
  }
}
