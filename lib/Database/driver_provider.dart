import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pasada_driver_side/Database/auth_service.dart';
import 'package:pasada_driver_side/Database/passenger_capacity.dart';
// import 'package:pasada_driver_side/Database/map_provider.dart';
import 'package:pasada_driver_side/UI/message.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// this class is used to store values just like a global variable
class DriverProvider with ChangeNotifier {
  // Driver identification
  String _driverID = '';
  String _driverFullName = 'firstName';
  String _driverNumber = '00000000000';

  // Vehicle and route information
  String _vehicleID = 'N/A';
  String _plateNumber = 'N/A';
  int _routeID = 0;
  String _routeName = 'N/A';

  // Driver status
  String _driverStatus = 'Online';
  String? _lastDriverStatus;
  bool _isDriving = false;

  // Passenger capacity
  int _passengerCapacity = 0;
  int _passengerStandingCapacity = 0;
  int _passengerSittingCapacity = 0;

  final SupabaseClient supabase = Supabase.instance.client;

  // Getters
  String get driverID => _driverID;
  String get plateNumber => _plateNumber;
  String get vehicleID => _vehicleID;
  int get routeID => _routeID;
  String get routeName => _routeName;
  String get driverStatus => _driverStatus;
  String? get lastDriverStatus => _lastDriverStatus;
  int get passengerCapacity => _passengerCapacity;
  int get passengerStandingCapacity => _passengerStandingCapacity;
  int get passengerSittingCapacity => _passengerSittingCapacity;
  bool get isDriving => _isDriving;
  String? get driverFullName => _driverFullName;
  String get driverNumber => _driverNumber;
  // Setters
  void setDriverID(String value) {
    _driverID = value;
    notifyListeners();
  }

  void setVehicleID(String value) {
    _vehicleID = value;
    notifyListeners();
  }

  void setPlateNumber(String value) {
    _plateNumber = value;
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

  void setPassengerStandingCapacity(int value) {
    _passengerStandingCapacity = value;
    notifyListeners();
  }

  void setPassengerSittingCapacity(int value) {
    _passengerSittingCapacity = value;
    notifyListeners();
  }

  void setIsDriving(bool value) {
    _isDriving = value;
    notifyListeners();
  }

  // Driver Creds
  void setDriverFirstName(String value) {
    _driverFullName = value;
    notifyListeners();
  }

  void setDriverNumber(String value) {
    _driverNumber = value;
    notifyListeners();
  }

  Future<void> updateStatusToDB(String newStatus, BuildContext context) async {
    try {
      final response = await supabase
          .from('driverTable')
          .update({'driving_status': newStatus.toLowerCase()})
          .eq('driver_id', driverID)
          .select()
          .single();

      if (kDebugMode) {
        print('Updated status: ${response['driving_status']}');
        ShowMessage()
            .showToast('Updated status: ${response['driving_status']}');
      }

      _lastDriverStatus = _driverStatus;
      _driverStatus = newStatus;
    } catch (e) {
      debugPrint('Error updating status: $e');
      ShowMessage().showToast('Error updating status: $e');
    }
  }

  Future<void> getPassengerCapacity() async {
    try {
      final response = await supabase
          .from('vehicleTable')
          .select('passenger_capacity, plate_number')
          .eq('vehicle_id', _vehicleID)
          .single();

      if (kDebugMode) {
        print('Capacity: ${response['passenger_capacity'].toString()}');
        ShowMessage().showToast(
            'Capacity: ${response['passenger_capacity'].toString()}');
      }

      // sets the capacity to the provider
      _passengerCapacity = response['passenger_capacity'];
      _plateNumber = response['plate_number'];
    } catch (e) {
      debugPrint('Error getting passenger capacity: $e');
      ShowMessage().showToast('Error on passenger capacity: $e');
    }
  }

  Future<void> getDriverCreds() async {
    try {
      final response = await supabase
          .from('driverTable')
          .select('full_name, driver_number')
          .eq('driver_id', _driverID)
          .single();

      // ShowMessage().showToast(response.toString());

      if (kDebugMode) {
        print(response.toString());
      }

      _driverFullName = response['full_name'].toString();
      _driverNumber = response['driver_number'].toString();
    } catch (e) {
      ShowMessage().showToast('Error fetching driver creds: $e');
      if (kDebugMode) {
        print('Error fetching driver creds: $e');
      }
    }
  }

  Future<bool> loadFromSecureStorage(BuildContext context) async {
    try {
      final sessionData = await AuthService.getSession();

      if (sessionData.isEmpty) {
        if (kDebugMode) {
          print('Session data is empty');
        }
        return false;
      }

      if (sessionData['driver_id'] == null || sessionData['driver_id'] == '') {
        if (kDebugMode) {
          print('Driver ID is missing in session data');
        }
        return false;
      }

      // Ensure driver_id is a string
      _driverID = sessionData['driver_id'].toString();
      _vehicleID = sessionData['vehicle_id'].toString();
      _routeID = int.tryParse(sessionData['route_id'] ?? '0') ?? 0;

      if (kDebugMode) {
        print('Loaded driver_id: $_driverID');
        print('Loaded vehicle_id: $_vehicleID');
        print('Loaded route_id: $_routeID');
      }

      // Load other data needed
      await getDriverCreds();
      await updateLastOnline(context);
      await PassengerCapacity().getPassengerCapacityToDB(context);
      await getDriverRoute();

      notifyListeners();
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error on loading secure storage: $e');
      }
      return false;
    }
  }

  Future<void> updateLastOnline(BuildContext context) async {
    try {
      // Try to load session data if driver_id is empty
      if (_driverID.isEmpty) {
        bool loaded = await loadFromSecureStorage(context);
        if (!loaded || _driverID.isEmpty) {
          if (kDebugMode) {
            print('Failed to load driver session data');
          }
          return;
        }
      }

      // Format date as PostgreSQL timestamp
      final now = DateTime.now().toUtc();
      final formattedDate = now.toIso8601String();

      final response = await supabase
          .from('driverTable')
          .update({
            'last_online': formattedDate,
          })
          .eq('driver_id', _driverID)
          .select('last_online')
          .single();

      if (kDebugMode) {
        print('Last online updated: ${response['last_online'].toString()}');
      }
    } catch (e, stacktrace) {
      if (kDebugMode) {
        print('Error updating last online: $e');
        print('Update Last Online StackTrace: $stacktrace');
      }
    }
  }

  Future<void> getDriverRoute() async {
    try {
      // Validate vehicle ID before query
      if (vehicleID.isEmpty || vehicleID == 'N/A') {
        debugPrint('Invalid vehicle ID: $vehicleID');
        return;
      }

      final vehicleResponse = await supabase
          .from('vehicleTable')
          .select('route_id, plate_number')
          .eq('vehicle_id', vehicleID)
          .single();

      // Validate response and route_id
      if (vehicleResponse['route_id'] == null) {
        debugPrint('No route ID found for vehicle: $vehicleID');
        return;
      }

      // Safely parse route_id
      final routeId = vehicleResponse['route_id'];
      if (routeId is int) {
        _routeID = routeId;
      } else if (routeId is String) {
        _routeID = int.tryParse(routeId) ?? 0;
      } else {
        _routeID = 0;
      }

      _plateNumber = vehicleResponse['plate_number'];

      // Only fetch route name if we have a valid route ID
      if (_routeID > 0) {
        try {
          final routeResponse = await supabase
              .from('official_routes')
              .select('route_name')
              .eq('officialroute_id', _routeID)
              .single();

          if (routeResponse['route_name'] != null) {
            _routeName = routeResponse['route_name'];
            debugPrint('Route name loaded: $_routeName');
          }
        } catch (e) {
          debugPrint('Error loading route name: $e');
        }
      }

      debugPrint('Get driver route response: $_routeID | $_routeName');
    } catch (e, stacktrace) {
      debugPrint('Error getting driver route: $e');
      debugPrint('Get Driver Route StackTrace: $stacktrace');
      _routeID = 0; // Set to default value on error
    }
  }

  // LatLng? _parseLatLng(String? coordString) {
  //   if (coordString == null) return null;
  //   final parts = coordString.split(',');
  //   if (parts.length != 2) return null;
  //   final lat = double.tryParse(parts[0]);
  //   final lng = double.tryParse(parts[1]);
  //   return (lat != null && lng != null) ? LatLng(lat, lng) : null;
  // }
}
