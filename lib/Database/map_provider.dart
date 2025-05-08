import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pasada_driver_side/Map/google_map.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pasada_driver_side/Database/driver_provider.dart';
import 'package:pasada_driver_side/UI/message.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

enum RouteState { initial, loading, loaded, error }

class MapProvider with ChangeNotifier {
  // State management
  RouteState _routeState = RouteState.initial;
  String? _errorMessage;

  // Location properties
  LatLng? _currentLocation;
  LatLng? _endingLocation;
  LatLng? _intermediateLoc1;
  LatLng? _intermediateLoc2;
  LatLng? _pickupLocation;

  // Route properties
  String? _routeName;
  int? _routeID;

  final SupabaseClient supabase = Supabase.instance.client;

  // Getters
  RouteState get routeState => _routeState;
  String? get errorMessage => _errorMessage;
  LatLng? get currentLocation => _currentLocation;
  LatLng? get endingLocation => _endingLocation;
  LatLng? get intermediateLoc1 => _intermediateLoc1;
  LatLng? get intermediateLoc2 => _intermediateLoc2;
  LatLng? get pickupLocation => _pickupLocation;
  String? get routeName => _routeName;
  int? get routeID => _routeID;

  // Setters with error handling
  void setCurrentLocation(LatLng value) {
    try {
      _currentLocation = value;
      notifyListeners();
    } catch (e) {
      _handleError('Error setting current location: $e');
    }
  }

  void setEndingLocation(LatLng value) {
    try {
      _endingLocation = value;
      notifyListeners();
    } catch (e) {
      _handleError('Error setting ending location: $e');
    }
  }

  void setIntermediateLoc1(LatLng value) {
    try {
      _intermediateLoc1 = value;
      notifyListeners();
    } catch (e) {
      _handleError('Error setting intermediate location 1: $e');
    }
  }

  void setIntermediateLoc2(LatLng value) {
    try {
      _intermediateLoc2 = value;
      notifyListeners();
    } catch (e) {
      _handleError('Error setting intermediate location 2: $e');
    }
  }

  void setPickUpLocation(LatLng value) {
    try {
      debugPrint('Setting pickup location: $value');
      _pickupLocation = value;
      debugPrint('Pickup location set: $_pickupLocation');
      notifyListeners();
    } catch (e) {
      _handleError('Error setting pickup location: $e');
    }
  }

  void setRouteID(int value) {
    try {
      _routeID = value;
      notifyListeners();
    } catch (e) {
      _handleError('Error setting route ID: $e');
    }
  }

  // Error handling
  void _handleError(String message) {
    _errorMessage = message;
    _routeState = RouteState.error;
    debugPrint(message);
    notifyListeners();
  }

  // Route coordinate fetching with improved error handling
  Future<void> getRouteCoordinates(int routeID) async {
    try {
      _routeState = RouteState.loading;
      notifyListeners();

      // Enhanced validation for route ID
      if (routeID <= 0) {
        debugPrint('Invalid route ID in MapProvider: $routeID');
        _routeState = RouteState.error;
        _errorMessage = 'Invalid route ID: $routeID';
        notifyListeners();
        return;
      }

      debugPrint('Fetching route coordinates for route ID: $routeID');

      final response = await supabase
          .from('official_routes')
          .select(
              'officialroute_id, route_name, description, origin_lat, origin_lng, destination_lat, destination_lng, intermediate_coordinates, origin_name, destination_name')
          .eq('officialroute_id', routeID)
          .maybeSingle();

      if (response == null) {
        debugPrint('No route found for ID: $routeID');
        _routeState = RouteState.error;
        _errorMessage = 'No route found for ID: $routeID';
        notifyListeners();
        return;
      }

      _processRouteResponse(response);
      _routeState = RouteState.loaded;
      notifyListeners();
    } catch (e, stackTrace) {
      debugPrint('Error in getRouteCoordinates: $e');
      debugPrint('Stack trace: $stackTrace');
      _handleError('Error fetching route coordinates: $e');
    }
  }

  // Process route response
  void _processRouteResponse(Map<String, dynamic> response) {
    _routeName = response['route_name'];
    _routeID = response['officialroute_id'] as int;

    _processCoordinates(response);
    _processIntermediateCoordinates(response);
  }

  // Process main coordinates
  void _processCoordinates(Map<String, dynamic> response) {
    if (response['origin_lat'] != null && response['origin_lng'] != null) {
      _currentLocation = _parseLatLng(
        response['origin_lat'].toString(),
        response['origin_lng'].toString(),
      );
    }

    if (response['destination_lat'] != null &&
        response['destination_lng'] != null) {
      _endingLocation = _parseLatLng(
        response['destination_lat'].toString(),
        response['destination_lng'].toString(),
      );
    }
  }

  // Process intermediate coordinates
  void _processIntermediateCoordinates(Map<String, dynamic> response) {
    if (response['intermediate_coordinates'] != null) {
      final intermediateCoords = response['intermediate_coordinates'] as List;

      if (intermediateCoords.isNotEmpty) {
        if (intermediateCoords.length > 0) {
          _intermediateLoc1 = _parseLatLng(
            intermediateCoords[0]['lat'].toString(),
            intermediateCoords[0]['lng'].toString(),
          );
        }
        if (intermediateCoords.length > 1) {
          _intermediateLoc2 = _parseLatLng(
            intermediateCoords[1]['lat'].toString(),
            intermediateCoords[1]['lng'].toString(),
          );
        }
      }
    }
  }

  // Route change with improved error handling
  Future<void> changeRouteLocation(BuildContext context) async {
    try {
      int? currentRouteID = context.read<DriverProvider>().routeID;

      if (currentRouteID == null || currentRouteID <= 0) {
        throw Exception('Invalid current route ID: $currentRouteID');
      }

      currentRouteID = _determineNewRouteID(currentRouteID);

      await _updateRouteAndDatabase(context, currentRouteID);

      if (kDebugMode) {
        print("Route change completed. New Route: $currentRouteID");
        ShowMessage().showToast('Route change completed successfully');
      }
    } catch (e) {
      _handleError('Error changing route location: $e');
      ShowMessage().showToast('Error changing route. Please try again.');
    }
  }

  // Determine new route ID
  int _determineNewRouteID(int currentRouteID) {
    switch (currentRouteID) {
      case 1:
        return 2; // Malinta to Novaliches
      case 2:
        return 1; // Novaliches to Malinta
      case 3:
        return 4; // Home to STI
      case 4:
        return 3; // STI to Home
      default:
        throw Exception('Invalid route ID for change: $currentRouteID');
    }
  }

  // Update route and database
  Future<void> _updateRouteAndDatabase(
      BuildContext context, int newRouteID) async {
    context.read<DriverProvider>().setRouteID(newRouteID);
    await getRouteCoordinates(newRouteID);

    final response = await supabase
        .from('vehicleTable')
        .update({'route_id': newRouteID})
        .eq('vehicle_id', context.read<DriverProvider>().vehicleID)
        .select();

    debugPrint('Change route response: $response');
  }

  // Parse LatLng with improved error handling
  LatLng? _parseLatLng(String lat, String lng) {
    try {
      final latitude = double.parse(lat);
      final longitude = double.parse(lng);
      return LatLng(latitude, longitude);
    } catch (e) {
      _handleError('Error parsing coordinates: $e');
      return null;
    }
  }
}
