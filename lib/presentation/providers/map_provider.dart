import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pasada_driver_side/presentation/providers/driver/driver_provider.dart';
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

  bool get isValid => origin != null && destination != null && routeId > 0;

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

  bool _isLocationSimilar(LatLng a, LatLng b, {double threshold = 0.001}) =>
      (a.latitude - b.latitude).abs() < threshold &&
      (a.longitude - b.longitude).abs() < threshold;

  @override
  String toString() =>
      'RouteData(origin: $origin, destination: $destination, id: $routeId, points: ${intermediatePoints.length})';
}

class MapProvider with ChangeNotifier {
  RouteState _routeState = RouteState.initial;
  String? _errorMessage;

  RouteData _routeData = const RouteData();
  LatLng? _currentLocation;
  LatLng? _pickupLocation;

  final Map<int, RouteData> _routeCache = {};
  final SupabaseClient supabase = Supabase.instance.client;

  RouteState get routeState => _routeState;
  String? get errorMessage => _errorMessage;

  // Route getters
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

  LatLng? get currentLocation => _currentLocation;
  LatLng? get pickupLocation => _pickupLocation;

  // ───────────────────────── setters ─────────────────────────
  void setCurrentLocation(LatLng loc) {
    if (loc.latitude == 0 && loc.longitude == 0) return;
    _currentLocation = loc;
    notifyListeners();
  }

  void setPickUpLocation(LatLng loc) {
    if (loc.latitude == 0 && loc.longitude == 0) return;
    _pickupLocation = loc;
    notifyListeners();
  }

  void setRouteID(int id) {
    if (id <= 0) return;
    _routeData = _routeData.copyWith(routeId: id);
    notifyListeners();
  }

  // ───────────────────────── data ops ─────────────────────────
  Future<void> getRouteCoordinates(int routeId) async {
    if (routeId <= 0) {
      _handleError('Invalid route ID: $routeId');
      return;
    }
    _updateState(RouteState.loading, null);
    try {
      if (_routeCache.containsKey(routeId)) {
        _setRouteData(_routeCache[routeId]!);
        return;
      }
      final resp = await supabase
          .from('official_routes')
          .select(
              'origin_lat, origin_lng, destination_lat, destination_lng, intermediate_coordinates, route_name')
          .eq('officialroute_id', routeId)
          .maybeSingle();
      if (resp == null) throw Exception('No route found for id $routeId');
      final rd = _processRouteResponse(resp, routeId);
      _routeCache[routeId] = rd;
      _setRouteData(rd);
    } catch (e) {
      _handleError('Failed to fetch route data: $e');
    }
  }

  RouteData _processRouteResponse(Map<String, dynamic> json, int routeId) {
    LatLng parsePoint(dynamic lat, dynamic lng) =>
        LatLng(double.parse(lat.toString()), double.parse(lng.toString()));
    final origin = parsePoint(json['origin_lat'], json['origin_lng']);
    final dest = parsePoint(json['destination_lat'], json['destination_lng']);
    final List<LatLng> inter = [];
    if (json['intermediate_coordinates'] != null) {
      final data = json['intermediate_coordinates'];
      if (data is List) {
        for (final p in data) {
          if (p is Map && p['lat'] != null && p['lng'] != null) {
            inter.add(parsePoint(p['lat'], p['lng']));
          }
        }
      }
    }
    return RouteData(
      origin: origin,
      destination: dest,
      intermediatePoints: inter,
      routeName: json['route_name'],
      routeId: routeId,
    );
  }

  Future<void> changeRouteLocation(BuildContext context) async {
    try {
      final driverProv = context.read<DriverProvider>();
      final curId = driverProv.routeID;
      if (curId <= 0) throw Exception('Invalid current route id');
      final newId = _determineNewRouteID(curId);
      driverProv.setRouteID(newId);
      await getRouteCoordinates(newId);
      await supabase
          .from('vehicleTable')
          .update({'route_id': newId}).eq('vehicle_id', driverProv.vehicleID);
      await supabase
          .from('driverTable')
          .update({'route_id': newId}).eq('driver_id', driverProv.driverID);
      _pickupLocation = null;
      notifyListeners();
      ShowMessage().showToast('Route changed successfully');
    } catch (e) {
      _handleError('Failed to change route: $e');
      ShowMessage().showToast('Failed to change route: $e');
    }
  }

  // ───────────────────────── helpers ─────────────────────────
  void _updateState(RouteState s, String? err) {
    _routeState = s;
    _errorMessage = err;
    notifyListeners();
  }

  void _handleError(String msg) => _updateState(RouteState.error, msg);

  void _setRouteData(RouteData d) {
    if (_routeData.isValid &&
        d.isValid &&
        _routeData.routeId == d.routeId &&
        _routeData.isReverseOf(d)) {
      // keep direction
      _routeData = RouteData(
        origin: _routeData.origin,
        destination: _routeData.destination,
        intermediatePoints: d.intermediatePoints,
        routeName: d.routeName,
        routeId: d.routeId,
      );
    } else {
      _routeData = d;
    }
    _updateState(RouteState.loaded, null);
  }

  int _determineNewRouteID(int id) {
    switch (id) {
      case 1:
        return 2;
      case 2:
        return 1;
      case 3:
        return 4;
      case 4:
        return 3;
      case 5:
        return 6;
      case 6:
        return 5;
      default:
        throw Exception('Invalid route id');
    }
  }

  // bool _isReversedRoutePair(int a, int b) =>
  //     (a == 1 && b == 2) ||
  //     (a == 2 && b == 1) ||
  //     (a == 3 && b == 4) ||
  //     (a == 4 && b == 3) ||
  //     (a == 5 && b == 6) ||
  //     (a == 6 && b == 5);

  void clearCache() {
    _routeCache.clear();
  }
}
