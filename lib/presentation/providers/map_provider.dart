import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pasada_driver_side/presentation/providers/driver/driver_provider.dart';
import 'package:location/location.dart';
import 'package:pasada_driver_side/presentation/providers/passenger/passenger_provider.dart';
import 'package:pasada_driver_side/UI/message.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:pasada_driver_side/domain/services/route_service.dart';
import 'package:pasada_driver_side/domain/services/polyline_service.dart';

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

  // ───────────────────────── marker state ─────────────────────────
  Set<Marker> _markers = {};
  final Set<String> _passengerMarkerIds = {}; // track passenger-related markers

  Set<Marker> get markers => _markers;

  // ───────────────────────── polyline state ─────────────────────────
  bool _polylineLoading = false;
  String? _polylineError;
  List<LatLng> _polylineCoords = [];

  bool get isPolylineLoading => _polylineLoading;
  String? get polylineError => _polylineError;
  List<LatLng> get polylineCoords => _polylineCoords;

  final Map<int, RouteData> _routeCache = {};
  final SupabaseClient supabase = Supabase.instance.client;

  RouteState get routeState => _routeState;
  String? get errorMessage => _errorMessage;

  // Convenience getters for 3-state UI pattern
  bool get isLoading => _routeState == RouteState.loading;
  String? get error => _errorMessage;

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
    _refreshMarkers();
    notifyListeners();
  }

  void setPickUpLocation(LatLng loc) {
    if (loc.latitude == 0 && loc.longitude == 0) return;
    _pickupLocation = loc;
    _refreshMarkers();
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

  @visibleForTesting
  void setRouteDataDebug(RouteData d) => _setRouteData(d);

  void _setRouteData(RouteData d) {
    // update and then refresh markers

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
    _refreshMarkers();
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

  // ───────────────────────── initialization ─────────────────────────
  Future<void> initialize(BuildContext context) async {
    try {
      final location = Location();
      final locData = await location.getLocation();
      if (locData.latitude != null && locData.longitude != null) {
        setCurrentLocation(LatLng(locData.latitude!, locData.longitude!));
      }

      // Route
      final driverProv = context.read<DriverProvider>();
      await getRouteCoordinates(driverProv.routeID);

      // Generate initial polyline
      if (_currentLocation != null && endingLocation != null) {
        final waypoints = <LatLng>[];
        if (intermediateLoc1 != null) waypoints.add(intermediateLoc1!);
        if (intermediateLoc2 != null) waypoints.add(intermediateLoc2!);
        await generatePolyline(
            start: _currentLocation!,
            end: endingLocation!,
            waypoints: waypoints.isEmpty ? null : waypoints);
      }

      // Pickup data – relies on PassengerProvider to load and then MapProvider.setPickUpLocation is called elsewhere.
      await context.read<PassengerProvider>().getBookingRequestsID(context);
    } catch (e) {
      _handleError('Initialization error: $e');
    }
  }

  // ───────────────────────── polyline generation ─────────────────────────
  Future<void> generatePolyline({
    required LatLng start,
    required LatLng end,
    List<LatLng>? waypoints,
  }) async {
    _setPolylineState(loading: true);
    try {
      // Use the new PolylineService for route generation
      final polylineService = PolylineService();
      final coords = await polylineService.generatePolyline(
        start: start,
        end: end,
        waypoints: waypoints,
      );
      _polylineCoords = coords ?? [];
      _setPolylineState(loading: false);
    } catch (e) {
      _setPolylineState(loading: false, error: e.toString());
    }
  }

  void _setPolylineState({required bool loading, String? error}) {
    _polylineLoading = loading;
    _polylineError = error;
    notifyListeners();
  }

  /// Update polyline coordinates directly (used by refactored MapPage)
  void updatePolylineCoords(List<LatLng> coords) {
    _polylineCoords = coords;
    _setPolylineState(loading: false);
  }

  // ───────────────────────── marker helpers ─────────────────────────
  Marker _createMarker(
          {required String id,
          required LatLng pos,
          required BitmapDescriptor icon,
          required String title,
          double zIndex = 1,
          double alpha = 1}) =>
      Marker(
        markerId: MarkerId(id),
        position: pos,
        icon: icon,
        infoWindow: InfoWindow(title: title),
        zIndex: zIndex,
        alpha: alpha,
      );

  // Force rebuild of marker set (call when external data changes)
  void rebuildMarkers() {
    _refreshMarkers();
    notifyListeners();
  }

  void _refreshMarkers() {
    final m = <Marker>{};

    // Current location
    if (_currentLocation != null) {
      m.add(_createMarker(
        id: 'CurrentLocation',
        pos: _currentLocation!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
        title: 'Current Location',
        zIndex: 2,
      ));
    }

    // Route markers
    if (originLocation != null) {
      m.add(_createMarker(
          id: 'StartingLocation',
          pos: originLocation!,
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
          title: 'Starting Point'));
    }
    if (endingLocation != null) {
      m.add(_createMarker(
          id: 'EndingLocation',
          pos: endingLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          title: 'Destination'));
    }
    if (intermediateLoc1 != null) {
      m.add(_createMarker(
          id: 'Intermediate1',
          pos: intermediateLoc1!,
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
          title: 'Waypoint 1'));
    }
    if (intermediateLoc2 != null) {
      m.add(_createMarker(
          id: 'Intermediate2',
          pos: intermediateLoc2!,
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
          title: 'Waypoint 2'));
    }

    // Pickup
    if (_pickupLocation != null) {
      m.add(_createMarker(
          id: 'Pickup',
          pos: _pickupLocation!,
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
          title: 'Pickup Location',
          zIndex: 3));
    }

    // keep passenger markers
    for (final marker in _markers) {
      if (_passengerMarkerIds.contains(marker.markerId.value)) {
        m.add(marker);
      }
    }

    _markers = m;
  }

  void addPassengerMarker(
      {required String id,
      required LatLng pos,
      required BitmapDescriptor icon,
      String title = 'Passenger',
      double zIndex = 1,
      double alpha = 1}) {
    _passengerMarkerIds.add(id);
    _markers.add(_createMarker(
        id: id,
        pos: pos,
        icon: icon,
        title: title,
        zIndex: zIndex,
        alpha: alpha));
    notifyListeners();
  }

  void clearPassengerMarkers() {
    _markers.removeWhere((m) => _passengerMarkerIds.contains(m.markerId.value));
    _passengerMarkerIds.clear();
    notifyListeners();
  }

  void clearCache() {
    _routeCache.clear();
  }
}
