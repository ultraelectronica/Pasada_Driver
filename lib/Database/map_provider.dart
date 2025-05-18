import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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

  // Response caching
  Map<int, Map<String, dynamic>>? _routeCache;

  final SupabaseClient supabase = Supabase.instance.client;

  // Getters
  RouteState get routeState => _routeState;
  String? get errorMessage => _errorMessage;
  LatLng? get originLocation => _currentLocation;
  LatLng? get currentLocation => _currentLocation;
  LatLng? get intermediateLoc1 => _intermediateLoc1;
  LatLng? get intermediateLoc2 => _intermediateLoc2;
  LatLng? get endingLocation => _endingLocation;
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
      // First check if the value is valid
      if (value.latitude == 0 && value.longitude == 0) {
        if (kDebugMode) {
          debugPrint(
              'MapProvider WARNING: Attempted to set invalid pickup location (0,0)');
        }
        return;
      }

      if (kDebugMode) {
        debugPrint('MapProvider: Setting pickup location: $value');
      }

      // Store the previous value for comparison
      final LatLng? previous = _pickupLocation;
      _pickupLocation = value;

      // Log success and compare with previous value
      if (previous != null) {
        final bool changed = previous.latitude != value.latitude ||
            previous.longitude != value.longitude;
        if (kDebugMode) {
          debugPrint(
              'MapProvider: Pickup location ${changed ? "changed" : "unchanged"}: $_pickupLocation');
        }
      } else {
        if (kDebugMode) {
          debugPrint(
              'MapProvider: Pickup location set for first time: $_pickupLocation');
        }
      }

      // Force a notification to subscribers
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('MapProvider ERROR: Failed to set pickup location: $e');
      }
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
    if (kDebugMode) {
      debugPrint(message);
    }
    notifyListeners();
  }

  // Route coordinate fetching with improved error handling
  Future<void> getRouteCoordinates(int routeID) async {
    try {
      // Set loading state
      _routeState = RouteState.loading;
      notifyListeners();

      // Check cache first
      if (_routeCache != null && _routeCache!.containsKey(routeID)) {
        _processRouteData(_routeCache![routeID]!, routeID);
        return;
      }

      final response = await Supabase.instance.client
          .from('official_routes')
          .select(
              'origin_lat, origin_lng, destination_lat, destination_lng, intermediate_coordinates, route_name')
          .eq('officialroute_id', routeID)
          .maybeSingle();

      if (response == null) {
        throw Exception('No route found with ID: $routeID');
      }

      // Cache the response
      _routeCache ??= {};
      _routeCache![routeID] = response;

      // Process route data
      _processRouteData(response, routeID);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting route coordinates: $e');
      }
      _routeState = RouteState.error;
      _errorMessage = 'Failed to load route data: ${e.toString()}';
      notifyListeners();
    }
  }

  // Process route data from response
  void _processRouteData(Map<String, dynamic> response, int routeID) {
    try {
      // Parse origin
      _currentLocation = _parseLatLng(
        response['origin_lat'],
        response['origin_lng'],
      );

      // Parse destination
      _endingLocation = _parseLatLng(
        response['destination_lat'],
        response['destination_lng'],
      );

      // Set route name and ID
      _routeName = response['route_name'];
      _routeID = routeID;

      // Reset intermediate points
      _intermediateLoc1 = null;
      _intermediateLoc2 = null;

      // Parse intermediate points
      if (response['intermediate_coordinates'] != null) {
        final intermediatePoints = response['intermediate_coordinates'];
        // No need to call json.decode - Supabase already returns parsed JSONB

        if (intermediatePoints is List) {
          // Set first intermediate point if available
          if (intermediatePoints.isNotEmpty) {
            _intermediateLoc1 = _parseLatLng(
              intermediatePoints[0]['lat'],
              intermediatePoints[0]['lng'],
            );
          }

          // Set second intermediate point if available
          if (intermediatePoints.length >= 2) {
            _intermediateLoc2 = _parseLatLng(
              intermediatePoints[1]['lat'],
              intermediatePoints[1]['lng'],
            );
          }
        }
      }

      // Update state
      _routeState = RouteState.loaded;
      notifyListeners();
    } catch (e) {
      _handleError('Error processing route data: $e');
    }
  }

  // Route change with improved error handling
  Future<void> changeRouteLocation(BuildContext context) async {
    try {
      int? currentRouteID = context.read<DriverProvider>().routeID;

      if (currentRouteID <= 0) {
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

    try {
      final response = await supabase
          .from('vehicleTable')
          .update({'route_id': newRouteID})
          .eq('vehicle_id', context.read<DriverProvider>().vehicleID)
          .select();

      if (kDebugMode) {
        debugPrint('Change route response: $response');
      }

      // Clear pickup location when route changes
      _pickupLocation = null;
      notifyListeners();
    } catch (e) {
      _handleError('Error updating route in database: $e');
      rethrow;
    }
  }

  // Parse LatLng with improved error handling
  LatLng? _parseLatLng(dynamic lat, dynamic lng) {
    try {
      final latitude = double.parse(lat.toString());
      final longitude = double.parse(lng.toString());
      return LatLng(latitude, longitude);
    } catch (e) {
      _handleError('Error parsing coordinates: $e');
      return null;
    }
  }

  // Clear route cache (useful when routes are updated)
  void clearRouteCache() {
    _routeCache = null;
  }
}
