import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pasada_driver_side/Database/driver_provider.dart';
import 'package:pasada_driver_side/UI/message.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Define clear state for route data
enum RouteState { initial, loading, loaded, error }

// Route model class for immutable route data
class RouteData {
  final LatLng? origin;
  final LatLng? destination;
  final List<LatLng> intermediatePoints;
  final String? routeName;
  final int routeId;

  const RouteData({
    this.origin,
    this.destination,
    this.intermediatePoints = const [],
    this.routeName,
    this.routeId = -1,
  });

  // Utility method to create a RouteData with all the same properties except those specified
  RouteData copyWith({
    LatLng? origin,
    LatLng? destination,
    List<LatLng>? intermediatePoints,
    String? routeName,
    int? routeId,
  }) {
    return RouteData(
      origin: origin ?? this.origin,
      destination: destination ?? this.destination,
      intermediatePoints: intermediatePoints ?? this.intermediatePoints,
      routeName: routeName ?? this.routeName,
      routeId: routeId ?? this.routeId,
    );
  }

  // Check if this route is valid
  bool get isValid => origin != null && destination != null && routeId > 0;

  // Check if this route is the reverse of another
  bool isReverseOf(RouteData other) {
    if (origin == null ||
        destination == null ||
        other.origin == null ||
        other.destination == null) {
      return false;
    }

    return _isLocationSimilar(origin!, other.destination!) &&
        _isLocationSimilar(destination!, other.origin!);
  }

  // Helper to check if two locations are similar within a threshold
  bool _isLocationSimilar(LatLng loc1, LatLng loc2,
      {double threshold = 0.001}) {
    return (loc1.latitude - loc2.latitude).abs() < threshold &&
        (loc1.longitude - loc2.longitude).abs() < threshold;
  }

  @override
  String toString() {
    return 'RouteData(origin: $origin, destination: $destination, routeId: $routeId, points: ${intermediatePoints.length})';
  }
}

class MapProvider with ChangeNotifier {
  // Private state
  RouteState _routeState = RouteState.initial;
  String? _errorMessage;

  // Immutable route data
  RouteData _routeData = const RouteData();

  // Current location (not part of route data)
  LatLng? _currentLocation;

  // Pickup location
  LatLng? _pickupLocation;

  // Cache management
  final Map<int, RouteData> _routeCache = {};

  // Database client
  final SupabaseClient supabase = Supabase.instance.client;

  // Public getters - immutable access to state
  RouteState get routeState => _routeState;
  String? get errorMessage => _errorMessage;

  // Route data access
  LatLng? get originLocation => _routeData.origin;
  LatLng? get intermediateLoc1 => _routeData.intermediatePoints.isNotEmpty
      ? _routeData.intermediatePoints[0]
      : null;
  LatLng? get intermediateLoc2 => _routeData.intermediatePoints.length > 1
      ? _routeData.intermediatePoints[1]
      : null;
  LatLng? get endingLocation => _routeData.destination;
  String? get routeName => _routeData.routeName;
  int get routeID => _routeData.routeId;

  // Current location access
  LatLng? get currentLocation => _currentLocation;

  // Pickup location access
  LatLng? get pickupLocation => _pickupLocation;

  // SETTERS - Always with proper validation

  // Set current location
  void setCurrentLocation(LatLng location) {
    try {
      if (location.latitude == 0 && location.longitude == 0) {
        if (kDebugMode) {
          debugPrint('MapProvider: Rejected invalid current location (0,0)');
        }
        return;
      }

      _currentLocation = location;
      notifyListeners();

      if (kDebugMode) {
        debugPrint('MapProvider: Current location updated to $location');
      }
    } catch (e) {
      _handleError('Failed to set current location: $e');
    }
  }

  // Set pickup location
  void setPickUpLocation(LatLng location) {
    try {
      if (location.latitude == 0 && location.longitude == 0) {
        if (kDebugMode) {
          debugPrint('MapProvider: Rejected invalid pickup location (0,0)');
        }
        return;
      }

      final previous = _pickupLocation;
      _pickupLocation = location;

      if (previous != null) {
        final bool changed = previous.latitude != location.latitude ||
            previous.longitude != location.longitude;
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

      notifyListeners();
    } catch (e) {
      _handleError('Failed to set pickup location: $e');
    }
  }

  // Set route ID - only updates ID without fetching data
  void setRouteID(int routeId) {
    try {
      if (routeId <= 0) {
        _handleError('Invalid route ID: $routeId');
        return;
      }

      final newRouteData = _routeData.copyWith(routeId: routeId);
      _setRouteData(newRouteData);
    } catch (e) {
      _handleError('Failed to set route ID: $e');
    }
  }

  // CORE DATA OPERATIONS

  // Fetch route coordinates from database
  Future<void> getRouteCoordinates(int routeId) async {
    if (routeId <= 0) {
      _handleError('Invalid route ID: $routeId');
      return;
    }

    try {
      // Set loading state
      _updateState(RouteState.loading, null);

      if (kDebugMode) {
        debugPrint('MapProvider: Fetching route data for ID $routeId');
      }

      // Check cache first
      if (_routeCache.containsKey(routeId)) {
        if (kDebugMode) {
          debugPrint('MapProvider: Using cached route data for ID $routeId');
        }

        _setRouteData(_routeCache[routeId]!);
        return;
      }

      // Fetch from database
      final response = await supabase
          .from('official_routes')
          .select(
              'origin_lat, origin_lng, destination_lat, destination_lng, intermediate_coordinates, route_name')
          .eq('officialroute_id', routeId)
          .maybeSingle();

      if (response == null) {
        throw Exception('No route found with ID: $routeId');
      }

      // Process the response into a RouteData object
      final routeData = _processRouteResponse(response, routeId);

      // Cache the route data
      _routeCache[routeId] = routeData;

      // Set the route data
      _setRouteData(routeData);

      if (kDebugMode) {
        debugPrint('MapProvider: Route data loaded and cached: $routeData');
      }
    } catch (e) {
      _handleError('Failed to fetch route data: $e');
    }
  }

  // Process route response into RouteData
  RouteData _processRouteResponse(Map<String, dynamic> response, int routeId) {
    try {
      // Parse origin coordinates
      final originLat = double.parse(response['origin_lat'].toString());
      final originLng = double.parse(response['origin_lng'].toString());
      final origin = LatLng(originLat, originLng);

      // Parse destination coordinates
      final destLat = double.parse(response['destination_lat'].toString());
      final destLng = double.parse(response['destination_lng'].toString());
      final destination = LatLng(destLat, destLng);

      // Parse intermediate points
      final List<LatLng> intermediatePoints = [];
      if (response['intermediate_coordinates'] != null) {
        final intermediate = response['intermediate_coordinates'];
        if (intermediate is List) {
          for (var point in intermediate) {
            if (point is Map &&
                point.containsKey('lat') &&
                point.containsKey('lng')) {
              final lat = double.parse(point['lat'].toString());
              final lng = double.parse(point['lng'].toString());
              intermediatePoints.add(LatLng(lat, lng));
            }
          }
        }
      }

      // Create route data
      return RouteData(
        origin: origin,
        destination: destination,
        intermediatePoints: intermediatePoints,
        routeName: response['route_name'],
        routeId: routeId,
      );
    } catch (e) {
      throw Exception('Failed to process route data: $e');
    }
  }

  // Route change with improved consistency
  Future<void> changeRouteLocation(BuildContext context) async {
    try {
      int currentRouteId = context.read<DriverProvider>().routeID;

      if (currentRouteId <= 0) {
        throw Exception('Invalid current route ID: $currentRouteId');
      }

      // Log the current route before changing
      if (kDebugMode) {
        debugPrint('===== CHANGING ROUTE =====');
        debugPrint('Current route: $_routeData');
      }

      // Determine new route ID
      final int newRouteId = _determineNewRouteID(currentRouteId);

      if (kDebugMode) {
        debugPrint(
            'MapProvider: Changing route from $currentRouteId to $newRouteId');
      }

      // Check if this is a route direction reversal
      final bool isReversal = _isReversedRoutePair(currentRouteId, newRouteId);

      if (kDebugMode) {
        debugPrint(
            'MapProvider: Route change is${isReversal ? '' : ' not'} a direction reversal');
      }

      // Update route ID in driver provider
      context.read<DriverProvider>().setRouteID(newRouteId);

      // Fetch new route data
      await getRouteCoordinates(newRouteId);

      // Update database
      await supabase
          .from('vehicleTable')
          .update({'route_id': newRouteId})
          .eq('vehicle_id', context.read<DriverProvider>().vehicleID)
          .select();

      // Clear pickup location when route changes
      _pickupLocation = null;
      notifyListeners();

      if (kDebugMode) {
        debugPrint('MapProvider: Route change completed');
        debugPrint('New route: $_routeData');
      }

      ShowMessage().showToast('Route changed successfully');
    } catch (e) {
      _handleError('Failed to change route: $e');
      ShowMessage().showToast('Failed to change route: $e');
    }
  }

  // HELPER METHODS

  // Update state with proper notification
  void _updateState(RouteState state, String? error) {
    _routeState = state;
    _errorMessage = error;
    notifyListeners();

    if (error != null && kDebugMode) {
      debugPrint('MapProvider ERROR: $error');
    }
  }

  // Handle errors consistently
  void _handleError(String message) {
    _updateState(RouteState.error, message);
  }

  // Set route data with consistency checks
  void _setRouteData(RouteData newData) {
    // Check if this appears to be a route direction flip
    if (_routeData.isValid &&
        newData.isValid &&
        _routeData.routeId == newData.routeId &&
        _routeData.isReverseOf(newData)) {
      if (kDebugMode) {
        debugPrint(
            'MapProvider: DETECTED POTENTIAL ROUTE FLIP - PRESERVING DIRECTION');
        debugPrint('Original: $_routeData');
        debugPrint('New (rejected): $newData');
      }

      // Maintain current direction but update other fields
      final preservedData = RouteData(
        origin: _routeData.origin,
        destination: _routeData.destination,
        intermediatePoints: newData.intermediatePoints,
        routeName: newData.routeName,
        routeId: newData.routeId,
      );

      _routeData = preservedData;
    } else {
      // Normal update
      _routeData = newData;
    }

    _updateState(RouteState.loaded, null);
  }

  // Helper for determining new route ID
  int _determineNewRouteID(int currentRouteId) {
    switch (currentRouteId) {
      case 1:
        return 2; // Malinta to Novaliches
      case 2:
        return 1; // Novaliches to Malinta
      case 3:
        return 4; // Home to STI
      case 4:
        return 3; // STI to Home
      default:
        throw Exception('Invalid route ID for change: $currentRouteId');
    }
  }

  // Helper to check if two route IDs form a reversed pair
  bool _isReversedRoutePair(int route1, int route2) {
    return (route1 == 1 && route2 == 2) ||
        (route1 == 2 && route2 == 1) ||
        (route1 == 3 && route2 == 4) ||
        (route1 == 4 && route2 == 3);
  }

  // Clear cached data
  void clearCache() {
    _routeCache.clear();
    if (kDebugMode) {
      debugPrint('MapProvider: Cache cleared');
    }
  }
}
