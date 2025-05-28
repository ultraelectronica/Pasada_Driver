import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pasada_driver_side/Config/app_config.dart';
import 'package:flutter/foundation.dart';
import 'booking_constants.dart';

// ==================== SERVICES ====================

/// Service to handle all location-related calculations
class LocationService {
  // Private constructor to prevent instantiation
  LocationService._();

  /// Calculate distance between two LatLng points in meters
  static double calculateDistance(LatLng point1, LatLng point2) {
    try {
      return Geolocator.distanceBetween(
          point1.latitude, point1.longitude, point2.latitude, point2.longitude);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error calculating distance: $e');
      }
      return double.infinity;
    }
  }

  /// Calculate bearing (direction/heading in degrees) between two geographic points
  /// Returns a value between 0-360 degrees, where:
  /// - 0° = North
  /// - 90° = East
  /// - 180° = South
  /// - 270° = West
  static double calculateBearing(LatLng start, LatLng end) {
    try {
      // Convert latitude/longitude from degrees to radians
      // This is necessary because the math functions expect radians
      final startLat =
          start.latitude * (pi / 180); // Convert degrees to radians
      final startLng = start.longitude * (pi / 180);
      final endLat = end.latitude * (pi / 180);
      final endLng = end.longitude * (pi / 180);

      // Calculate the y component using the spherical law of cosines formula
      // This represents the east-west component of the bearing
      final y = sin(endLng - startLng) * cos(endLat);

      // Calculate the x component
      // This represents the north-south component of the bearing
      final x = cos(startLat) * sin(endLat) -
          sin(startLat) * cos(endLat) * cos(endLng - startLng);

      // Calculate the angle using arctangent of y/x (atan2 handles quadrant correctly)
      // and convert back from radians to degrees
      final bearing = atan2(y, x) * (180 / pi);

      // Normalize to 0-360 degrees (atan2 returns -180 to +180)
      return (bearing + 360) % 360;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error calculating bearing: $e');
      }
      return 0.0; // Default to North
    }
  }

  /// Determines if a point is ahead of another point given a reference direction
  static bool isPointAhead(LatLng point, LatLng reference, double bearing) {
    try {
      // Calculate bearing from reference to the point
      final bearingToPoint = calculateBearing(reference, point);

      // Calculate angular difference (ensures shortest path, handles 359° vs 1° case)
      final diff = (((bearingToPoint - bearing + 180) % 360) - 180).abs();

      // If the point is within ±threshold of the direction of travel, consider it "ahead"
      return diff <= AppConfig.bearingAngleThreshold;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error checking if point is ahead: $e');
      }
      return false;
    }
  }

  /// Validates if coordinates are within valid ranges
  static bool isValidLocation(LatLng location) {
    return location.latitude >= -90 &&
        location.latitude <= 90 &&
        location.longitude >= -180 &&
        location.longitude <= 180;
  }

  /// Determines if a pickup location is ahead of the driver by the required distance
  static bool isPickupAheadOfDriver({
    required LatLng pickupLocation,
    required LatLng driverLocation,
    required LatLng destinationLocation,
    required double minRequiredDistance,
  }) {
    try {
      // Validate input locations
      if (!isValidLocation(pickupLocation) ||
          !isValidLocation(driverLocation) ||
          !isValidLocation(destinationLocation)) {
        if (kDebugMode) {
          debugPrint('Invalid location coordinates provided');
        }
        return false;
      }

      // Calculate direct distance between driver and pickup
      final driverToPickupDistance =
          calculateDistance(driverLocation, pickupLocation);

      // Calculate distance between driver and destination
      final driverToDestinationDistance =
          calculateDistance(driverLocation, destinationLocation);

      // Check if pickup is too far away for either validation method
      if (driverToPickupDistance > AppConfig.maxDistanceSecondaryCheck) {
        if (kDebugMode) {
          debugPrint(
              'Pickup is too far away (${driverToPickupDistance.toStringAsFixed(2)}m)');
        }
        return false;
      }

      // Special case: If driver and destination are essentially at the same point
      if (driverToDestinationDistance <
          BookingConstants.nearDestinationThreshold) {
        if (kDebugMode) {
          debugPrint(
              'SPECIAL CASE: Driver at/near destination, using alternative validation');
        }

        return _validatePickupNearDestination(
          driverLocation: driverLocation,
          pickupLocation: pickupLocation,
          driverToPickupDistance: driverToPickupDistance,
        );
      }

      return _validatePickupOnRoute(
        driverLocation: driverLocation,
        pickupLocation: pickupLocation,
        destinationLocation: destinationLocation,
        driverToPickupDistance: driverToPickupDistance,
        minRequiredDistance: minRequiredDistance,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error in isPickupAheadOfDriver: $e');
      }
      return false;
    }
  }

  /// Validate pickup when driver is near destination
  static bool _validatePickupNearDestination({
    required LatLng driverLocation,
    required LatLng pickupLocation,
    required double driverToPickupDistance,
  }) {
    // When driver is near destination, we need different criteria
    final bearingToPickup = calculateBearing(driverLocation, pickupLocation);

    // Check if the pickup is in a direction generally considered "behind" the driver
    // This is based on accumulated knowledge from previous valid/invalid bookings
    final isLikelyBehindDriver =
        (bearingToPickup > AppConfig.behindDriverMinBearing &&
            bearingToPickup < AppConfig.behindDriverMaxBearing);

    if (isLikelyBehindDriver) {
      if (kDebugMode) {
        debugPrint(
            'SPECIAL CASE: Rejecting booking likely behind driver (bearing: ${bearingToPickup.toStringAsFixed(2)}°)');
      }
      return false;
    }

    // If not behind and within reasonable distance, consider it valid
    return driverToPickupDistance < AppConfig.maxPickupDistanceThreshold;
  }

  /// Validate pickup when driver is on route to destination
  static bool _validatePickupOnRoute({
    required LatLng driverLocation,
    required LatLng pickupLocation,
    required LatLng destinationLocation,
    required double driverToPickupDistance,
    required double minRequiredDistance,
  }) {
    // Calculate driver's bearing toward destination
    final driverBearing = calculateBearing(driverLocation, destinationLocation);

    // Check if pickup is ahead based on bearing
    final isAheadByBearing =
        isPointAhead(pickupLocation, driverLocation, driverBearing);

    // Calculate distances to destination
    final driverDistanceToDestination =
        calculateDistance(driverLocation, destinationLocation);
    final pickupDistanceToDestination =
        calculateDistance(pickupLocation, destinationLocation);

    // Traditional method (legacy approach) - useful as secondary check
    final metersAhead =
        driverDistanceToDestination - pickupDistanceToDestination;

    if (kDebugMode) {
      _logValidationDetails(
        driverDistanceToDestination: driverDistanceToDestination,
        pickupDistanceToDestination: pickupDistanceToDestination,
        driverToPickupDistance: driverToPickupDistance,
        driverBearing: driverBearing,
        isAheadByBearing: isAheadByBearing,
        metersAhead: metersAhead,
      );
    }

    // PRIMARY CHECK: Is pickup ahead by bearing AND reasonably close?
    final isPrimaryValid = isAheadByBearing &&
        driverToPickupDistance < AppConfig.maxPickupDistanceThreshold;

    // SECONDARY CHECK: Is pickup significantly ahead by distance?
    // This helps in straight-line cases and provides backwards compatibility
    final isSecondaryValid = metersAhead > minRequiredDistance &&
        driverToPickupDistance < AppConfig.maxDistanceSecondaryCheck;

    // Final decision combines both checks
    final isValid = isPrimaryValid || isSecondaryValid;

    if (kDebugMode) {
      debugPrint('Is ahead by bearing and close enough: $isPrimaryValid');
      debugPrint(
          'Is significantly ahead by distance: $isSecondaryValid (min: ${minRequiredDistance}m)');
      debugPrint('Final validation result: $isValid');
    }

    return isValid;
  }

  /// Log validation details for debugging
  static void _logValidationDetails({
    required double driverDistanceToDestination,
    required double pickupDistanceToDestination,
    required double driverToPickupDistance,
    required double driverBearing,
    required bool isAheadByBearing,
    required double metersAhead,
  }) {
    debugPrint('VALIDATION CHECK:');
    debugPrint(
        'Driver to destination: ${driverDistanceToDestination.toStringAsFixed(2)}m');
    debugPrint(
        'Pickup to destination: ${pickupDistanceToDestination.toStringAsFixed(2)}m');
    debugPrint(
        'Direct driver to pickup: ${driverToPickupDistance.toStringAsFixed(2)}m');
    debugPrint(
        'Driver bearing to destination: ${driverBearing.toStringAsFixed(2)}°');
    debugPrint('Is pickup ahead by bearing: $isAheadByBearing');
    debugPrint('Distance difference: ${metersAhead.toStringAsFixed(2)}m');
  }
}
