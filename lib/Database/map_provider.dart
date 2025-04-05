import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pasada_driver_side/Database/driver_provider.dart';
import 'package:provider/provider.dart';

class MapProvider with ChangeNotifier {
  LatLng? _currentLocation;
  LatLng? _endingLocation;
  LatLng? _intermediateLoc1;
  LatLng? _intermediateLoc2;
  // int _routeID = 0;
  String? _routeName;

  final SupabaseClient supabase = Supabase.instance.client;
  final driverProvider = DriverProvider();

  LatLng? get currentLocation => _currentLocation;
  LatLng? get endingLocation => _endingLocation;
  LatLng? get intermediateLoc1 => _intermediateLoc1;
  LatLng? get intermediateLoc2 => _intermediateLoc2;
  // int get routeID => _routeID;
  String? get routeName => _routeName;

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

  // void setRouteID(int value) {
  //   _routeID = value;
  //   notifyListeners();
  // }

  // Future<void> getDriverRoute(BuildContext context) async {
  //   try {
  //     String vehicleID = context.read<DriverProvider>().vehicleID;

  //     final response = await supabase
  //         .from('vehicleTable')
  //         .select('route_id')
  //         .eq('vehicle_id', vehicleID)
  //         .single();

  //     // _routeID = response['route_id'];
  //     context.read<DriverProvider>().setRouteID(response['route_id'] as int);

  //     if (kDebugMode) {
  //       print('Get driver route response: ${response['route_id'].toString()}');
  //       ShowMessage()
  //           .showToast('Driver route: ${response['route_id'].toString()}');
  //     }
  //   } catch (e) {
  //     if (kDebugMode) {
  //       print('Error: $e');
  //     }
  //   }
  // }

  Future<void> getRouteCoordinates(int routeID) async {
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
        print('Route ID: $routeID');
        print('''
        Route: $_routeName
        Intermediate 1: ${_intermediateLoc1?.latitude},${_intermediateLoc1?.longitude}
        Intermediate 2: ${_intermediateLoc2?.latitude},${_intermediateLoc2?.longitude}
        End: ${_endingLocation?.latitude},${_endingLocation?.longitude}
      ''');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('Error: $e');
        print('Stack Trace: $stackTrace');
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
