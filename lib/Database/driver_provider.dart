import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pasada_driver_side/Database/AuthService.dart';
// import 'package:pasada_driver_side/Database/map_provider.dart';
import 'package:pasada_driver_side/UI/message.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// this class is used to store values just like a global variable
class DriverProvider with ChangeNotifier {
  String _driverID = 'N/A';
  String _driverStatus = 'Online';
  String _vehicleID = 'N/A';
  int _routeID = 0;
  String _routeName = 'N/A';

  String? _lastDriverStatus;
  int _passengerCapacity = 0;
  bool _isDriving = false;

  String _driverFirstName = 'firstName';
  String _driverLastName = 'lastName';
  String _driverNumber = '00000000000';

  LatLng? _currentLocation;
  LatLng? _endingLocation;
  LatLng? _intermediateLoc1;
  LatLng? _intermediateLoc2;

  final SupabaseClient supabase = Supabase.instance.client;

  String get driverID => _driverID;
  String get vehicleID => _vehicleID;
  int get routeID => _routeID;
  String get routeName => _routeName;
  String get driverStatus => _driverStatus;
  String? get lastDriverStatus => _lastDriverStatus;
  int get passengerCapacity => _passengerCapacity;
  bool get isDriving => _isDriving;

  String? get driverFirstName => _driverFirstName;
  String? get driverLastName => _driverLastName;
  String get driverNumber => _driverNumber;

  LatLng? get currentLocation => _currentLocation;
  LatLng? get endingLocation => _endingLocation;
  LatLng? get intermediateLoc1 => _intermediateLoc1;
  LatLng? get intermediateLoc2 => _intermediateLoc2;

  void setDriverID(String value) {
    _driverID = value;
    notifyListeners();
  }

  void setVehicleID(String value) {
    _vehicleID = value;
    notifyListeners();
  }

  void setRouteID(int value) {
    _routeID = value;
    notifyListeners();
  }

  void setRoutename(String value) {
    _routeName = value;
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

  void setCurrentLocation(LatLng value) {
    _currentLocation = value;
    notifyListeners();
  }

  void setEndingLocation(LatLng value) {
    _endingLocation = value;
    notifyListeners();
  }

  void setIntermediateLoc1(LatLng value) {
    _intermediateLoc1 = value;
    notifyListeners();
  }

  void setIntermediateLoc2(LatLng value) {
    _intermediateLoc2 = value;
    notifyListeners();
  }

  Future<void> updateStatusToDB(String newStatus, BuildContext context) async {
    final response = await supabase
        .from('driverTable')
        .update({'driving_status': newStatus})
        .eq('driver_id', driverID)
        .select()
        .single();

    if (kDebugMode) {
      print('Updated status: ${response['driving_status']}');
      ShowMessage().showToast('Updated status: ${response['driving_status']}');
    }

    _lastDriverStatus = _driverStatus;
    _driverStatus = newStatus;
  }

  Future<void> getPassengerCapacity() async {
    try {
      final response = await supabase
          .from('vehicleTable')
          .select('passenger_capacity')
          .eq('vehicle_id', _vehicleID)
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

  Future<void> updateLastOnline() async {
    try {
      final response = await supabase
          .from('driverTable')
          .update({
            'last_online': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('driver_id', _driverID)
          .select('last_online')
          .single();

      if (kDebugMode) {
        ShowMessage().showToast(
            'Time updated ${DateTime.now().toUtc().toIso8601String()}');
        print('Last online updated: ${response['last_online'].toString()}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error updating last online: $e');
      }
      ShowMessage().showToast('Error: $e');
    }
  }

  Future<void> getDriverRoute() async {
    try {
      final response = await supabase
          .from('vehicleTable')
          .select('route_id')
          .eq('vehicle_id', vehicleID)
          .single();

      _routeID = response['route_id'];
      // context.read<MapProvider>().setRouteID(response['route_id'] as int);

      if (kDebugMode) {
        print('Get driver route response: ${response['route_id'].toString()}');
        ShowMessage()
            .showToast('Driver route: ${response['route_id'].toString()}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error: $e');
      }
    }
  }

  Future<void> getRouteCoordinates() async {
    try {
      final response = await supabase
          .from('driverRouteTable')
          .select()
          .eq('route_id', routeID)
          .single();

      _routeName = response['route'];
      _intermediateLoc1 = _parseLatLng(response['intermediate_location1']);
      _intermediateLoc2 = _parseLatLng(response['intermediate_location2']);
      _endingLocation = _parseLatLng(response['ending_location']);

      if (kDebugMode) {
        // print('''
        //   Route ID: $routeID
        //   Route Name: $routeName
        // ''');
        print('''
          Route: $_routeName
          Intermediate 1: ${_intermediateLoc1?.latitude},${_intermediateLoc1?.longitude}
          Intermediate 2: ${_intermediateLoc2?.latitude},${_intermediateLoc2?.longitude}
          End: ${_endingLocation?.latitude},${_endingLocation?.longitude}
        ''');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error: $e');
      }
    }
  }

  // Future<void> getRouteCoordinates(BuildContext context) async {
  //   try {
  //     final response = await supabase
  //         .from('driverRouteTable')
  //         .select()
  //         .eq('route_id', routeID)
  //         .single();

  //     _routeName = response['route'];
  //     _intermediateLoc1 = _parseLatLng(response['intermediate_location1']);
  //     _intermediateLoc2 = _parseLatLng(response['intermediate_location2']);
  //     _endingLocation = _parseLatLng(response['ending_location']);

  //     if (kDebugMode) {
  //       print('Route ID: $routeID');
  //       print('''
  //       Route: $_routeName
  //       Intermediate 1: ${_intermediateLoc1?.latitude},${_intermediateLoc1?.longitude}
  //       Intermediate 2: ${_intermediateLoc2?.latitude},${_intermediateLoc2?.longitude}
  //       End: ${_endingLocation?.latitude},${_endingLocation?.longitude}
  //     ''');
  //     }
  //   } catch (e) {
  //     if (kDebugMode) {
  //       print('Error: $e');
  //     }
  //   }
  // }

  Future<void> loadFromSecureStorage() async {
    try {
      final sessionData = await AuthService.getSession();

      if (sessionData.isNotEmpty) {
        _driverID = sessionData['driver_id'] ?? '';
        _vehicleID = sessionData['vehicle_id'] ?? '';
        _routeID = int.tryParse(sessionData['route_id']!)!;

        if (kDebugMode) {
          print('session data: ${sessionData.toString()}');
        }

        // Load other data needed
        await getDriverCreds(); // Get first name, last name, etc.
        await getPassengerCapacity(); // Get passenger capacity
        await getDriverRoute(); // Get route galing DB
        await getRouteCoordinates(); // Get coords and route name galing DB

        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) {
        ShowMessage().showToast('Error loading data: $e');
        print('Error on loading secure storage: $e');
      }
    }
  }

  LatLng? _parseLatLng(String? coordString) {
    if (coordString == null) return null;
    final parts = coordString.split(',');
    if (parts.length != 2) return null;
    final lat = double.tryParse(parts[0]);
    final lng = double.tryParse(parts[1]);
    return (lat != null && lng != null) ? LatLng(lat, lng) : null;
  }
}
