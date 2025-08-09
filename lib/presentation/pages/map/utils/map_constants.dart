import 'dart:math';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pasada_driver_side/presentation/pages/map/models/map_state.dart';

// Re-export MapInitState from models to avoid circular imports
export 'package:pasada_driver_side/presentation/pages/map/models/map_state.dart'
    show MapInitState;

/// Constants used throughout the map feature
class MapConstants {
  // Map configuration
  static const double defaultZoom = 15.0;
  static const double trackingZoom = 17.5;
  static const double defaultTilt = 45.0;

  // Location tracking thresholds
  static const double minDistanceForPolylineUpdate = 10.0; // meters
  static const double minDistanceForUIUpdate = 2.0; // meters
  static const double destinationReachedThreshold = 40.0; // meters

  // UI positioning
  static const double bottomPaddingDefault = 0.13;
  static const double locationButtonBottomFraction = 0.025;
  static const double locationButtonRightFraction = 0.05;
  static const double locationButtonSize = 50.0;

  // Status indicator positioning
  static const double statusIndicatorTop = 60.0;
  static const double statusIndicatorPadding = 16.0;
  static const double statusIndicatorVerticalPadding = 8.0;
  static const double statusIndicatorBorderRadius = 20.0;

  // Colors
  static const int statusBackgroundAlpha = 179;

  // Map style asset path
  static const String darkMapStylePath = 'assets/map_style/map_style.json';

  // Status messages
  static const String loadingLocationMessage = "Getting your location...";
  static const String loadingRouteMessage = "Loading route...";
  static const String loadingPickupMessage = "Checking for passengers...";
  static const String defaultLoadingMessage = "Loading...";
  static const String mapLoadingMessage = "Loading map...";
  static const String retryButtonText = "Retry";

  // Error messages
  static const String locationErrorPrefix =
      "Error: Failed to get current location: ";
  static const String routeDataErrorPrefix = "Failed to load route data: ";
  static const String initializationErrorPrefix = "Error loading map: ";
}

/// Helper class for map utility functions
class MapUtils {
  /// Get user-friendly status message based on initialization state
  static String getStatusMessage(MapInitState state) {
    switch (state) {
      case MapInitState.loadingLocation:
        return MapConstants.loadingLocationMessage;
      case MapInitState.loadingRouteData:
        return MapConstants.loadingRouteMessage;
      case MapInitState.loadingPickupData:
        return MapConstants.loadingPickupMessage;
      default:
        return MapConstants.defaultLoadingMessage;
    }
  }

  /// Calculate if a location update should trigger UI changes
  static bool shouldUpdateUI(LatLng? currentLocation, LatLng newLocation) {
    if (currentLocation == null) return true;

    // Using a simple distance calculation for UI updates
    double distanceMoved = _calculateDistance(
      currentLocation.latitude,
      currentLocation.longitude,
      newLocation.latitude,
      newLocation.longitude,
    );

    return distanceMoved > MapConstants.minDistanceForUIUpdate;
  }

  /// Calculate if a location update should trigger polyline updates
  static bool shouldUpdatePolyline(
      LatLng? lastPolylineUpdateLocation, LatLng newLocation) {
    if (lastPolylineUpdateLocation == null) return true;

    double distanceMoved = _calculateDistance(
      lastPolylineUpdateLocation.latitude,
      lastPolylineUpdateLocation.longitude,
      newLocation.latitude,
      newLocation.longitude,
    );

    return distanceMoved > MapConstants.minDistanceForPolylineUpdate;
  }

  /// Check if the user has reached the destination
  static bool hasReachedDestination(
      LatLng currentLocation, LatLng destination) {
    double distance = _calculateDistance(
      currentLocation.latitude,
      currentLocation.longitude,
      destination.latitude,
      destination.longitude,
    );

    return distance < MapConstants.destinationReachedThreshold;
  }

  /// Simple distance calculation using Haversine formula approximation
  static double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // meters

    double dLat = (lat2 - lat1) * (3.14159 / 180);
    double dLon = (lon2 - lon1) * (3.14159 / 180);

    double a = (dLat / 2).abs() * (dLat / 2).abs() +
        cos(lat1 * 3.14159 / 180) *
            cos(lat2 * 3.14159 / 180) *
            (dLon / 2).abs() *
            (dLon / 2).abs();

    double c = 2 * asin(sqrt(a));

    return earthRadius * c;
  }
}
