import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pasada_driver_side/Database/driver_provider.dart';
import 'package:pasada_driver_side/UI/message.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class MapProvider with ChangeNotifier {
  LatLng? _currentLocation;
  LatLng? _endingLocation;
  LatLng? _intermediateLoc1;
  LatLng? _intermediateLoc2;
  // int _routeID = 0;
  String? _routeName;

  final SupabaseClient supabase = Supabase.instance.client;

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

  // TODO: This is still incomplete, need to work after finishing the features in the map
  Future<void> getPassenger(int driverID) async {
    try {
      final response = await supabase
          .from('bookings')
          .select()
          .eq('driver_id', driverID)
          .single();

      if (kDebugMode) {
        print('Passenger: ${response['booking_id']}');
        print('     Get passenger response: $response');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error: $e');
      }
    }
  }

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

  // Method to change the driver route
  Future<void> changeRouteLocation(BuildContext context) async {
    try {
      int currentRouteID = context.read<DriverProvider>().routeID;

      if (currentRouteID == 1) {
        // change route to Malinta to Novaliches
        currentRouteID = 2; 
        context.read<DriverProvider>().setRouteID(currentRouteID);
        getRouteCoordinates(currentRouteID);
      } else {
        // change route to Novaliches to Malinta
        currentRouteID = 1;
        context.read<DriverProvider>().setRouteID(currentRouteID);
        getRouteCoordinates(currentRouteID);
      }

      final response = await supabase
          .from('vehicleTable')
          .update({'route_id': currentRouteID}).eq(
              'vehicle_id', context.read<DriverProvider>().vehicleID).select();

      debugPrint('Change route response: $response');

      if (kDebugMode) {
        print(
            "Reached destination! Triggering route change. Current Route: $currentRouteID");
        ShowMessage()
            .showToast('Reached destination! Triggering route change...');
      }
    } catch (e) {
      debugPrint('Error: $e');
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
