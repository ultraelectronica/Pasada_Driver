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
  static const double cameraBoundsPadding =
      100.0; // pixels padding when fitting bounds

  // Location tracking thresholds
  static const double minDistanceForPolylineUpdate = 20.0; // meters
  static const double minDistanceForUIUpdate = 2.0; // meters
  static const double destinationReachedThreshold = 40.0; // meters

  // Throttling intervals
  static const Duration polylineUpdateMinInterval = Duration(seconds: 15);
  static const Duration dbLocationUpdateMinInterval = Duration(seconds: 5);

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

  /// Simple distance calculation using the Haversine formula
  static double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // meters

    final double toRad = 3.1415926535897932 / 180.0;
    final double dLat = (lat2 - lat1) * toRad;
    final double dLon = (lon2 - lon1) * toRad;
    final double rLat1 = lat1 * toRad;
    final double rLat2 = lat2 * toRad;

    final double sinDLat = sin(dLat / 2);
    final double sinDLon = sin(dLon / 2);
    final double a =
        sinDLat * sinDLat + cos(rLat1) * cos(rLat2) * sinDLon * sinDLon;
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }
}
