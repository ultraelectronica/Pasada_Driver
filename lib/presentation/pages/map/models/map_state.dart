import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Enum to track the map initialization state
enum MapInitState {
  uninitialized,
  loadingLocation,
  locationLoaded,
  loadingRouteData,
  routeDataLoaded,
  loadingPickupData,
  initialized,
  error
}

/// Model representing the complete map state
class MapState {
  final MapInitState initState;
  final String? errorMessage;
  final LatLng? currentLocation;
  final LatLng? pickupLocation;
  final LatLng? startingLocation;
  final LatLng? intermediateLocation1;
  final LatLng? intermediateLocation2;
  final LatLng? endingLocation;
  final bool isAnimatingLocation;
  final bool routeCoordinatesLoaded;

  const MapState({
    this.initState = MapInitState.uninitialized,
    this.errorMessage,
    this.currentLocation,
    this.pickupLocation,
    this.startingLocation,
    this.intermediateLocation1,
    this.intermediateLocation2,
    this.endingLocation,
    this.isAnimatingLocation = false,
    this.routeCoordinatesLoaded = false,
  });

  MapState copyWith({
    MapInitState? initState,
    String? errorMessage,
    LatLng? currentLocation,
    LatLng? pickupLocation,
    LatLng? startingLocation,
    LatLng? intermediateLocation1,
    LatLng? intermediateLocation2,
    LatLng? endingLocation,
    bool? isAnimatingLocation,
    bool? routeCoordinatesLoaded,
  }) {
    return MapState(
      initState: initState ?? this.initState,
      errorMessage: errorMessage ?? this.errorMessage,
      currentLocation: currentLocation ?? this.currentLocation,
      pickupLocation: pickupLocation ?? this.pickupLocation,
      startingLocation: startingLocation ?? this.startingLocation,
      intermediateLocation1:
          intermediateLocation1 ?? this.intermediateLocation1,
      intermediateLocation2:
          intermediateLocation2 ?? this.intermediateLocation2,
      endingLocation: endingLocation ?? this.endingLocation,
      isAnimatingLocation: isAnimatingLocation ?? this.isAnimatingLocation,
      routeCoordinatesLoaded:
          routeCoordinatesLoaded ?? this.routeCoordinatesLoaded,
    );
  }

  /// Check if the map has all required location data
  bool get hasRequiredLocationData =>
      startingLocation != null && endingLocation != null;

  /// Check if the map is fully initialized
  bool get isInitialized => initState == MapInitState.initialized;

  /// Check if there's an error state
  bool get hasError => initState == MapInitState.error;

  /// Get available waypoints for route calculation
  List<LatLng> get waypoints {
    final List<LatLng> points = [];
    if (intermediateLocation1 != null) {
      points.add(intermediateLocation1!);
    }
    if (intermediateLocation2 != null) {
      points.add(intermediateLocation2!);
    }
    return points;
  }
}

/// Model for polyline configuration
class PolylineConfig {
  final String id;
  final List<LatLng> points;
  final Color color;
  final int width;

  const PolylineConfig({
    required this.id,
    required this.points,
    this.color = const Color.fromARGB(255, 255, 35, 35),
    this.width = 8,
  });

  Polyline toPolyline() {
    return Polyline(
      polylineId: PolylineId(id),
      points: points,
      color: color,
      width: width,
    );
  }
}
