// ignore_for_file: depend_on_referenced_packages
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pasada_driver_side/common/config/app_config.dart';

import '../constants/booking_constants.dart';

/// Service to handle all location-related calculations
class LocationService {
  LocationService._();

  static double calculateDistance(LatLng p1, LatLng p2) {
    try {
      return Geolocator.distanceBetween(
        p1.latitude,
        p1.longitude,
        p2.latitude,
        p2.longitude,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Error calculating distance: $e');
      return double.infinity;
    }
  }

  static double calculateBearing(LatLng start, LatLng end) {
    try {
      final startLat = start.latitude * (pi / 180);
      final startLng = start.longitude * (pi / 180);
      final endLat = end.latitude * (pi / 180);
      final endLng = end.longitude * (pi / 180);
      final y = sin(endLng - startLng) * cos(endLat);
      final x = cos(startLat) * sin(endLat) -
          sin(startLat) * cos(endLat) * cos(endLng - startLng);
      final bearing = atan2(y, x) * (180 / pi);
      return (bearing + 360) % 360;
    } catch (e) {
      if (kDebugMode) debugPrint('Error calculating bearing: $e');
      return 0.0;
    }
  }

  static bool isPointAhead(LatLng point, LatLng reference, double bearing) {
    try {
      final bearingToPoint = calculateBearing(reference, point);
      final diff = (((bearingToPoint - bearing + 180) % 360) - 180).abs();
      return diff <= AppConfig.bearingAngleThreshold;
    } catch (e) {
      if (kDebugMode) debugPrint('Error checking ahead: $e');
      return false;
    }
  }

  static bool isValidLocation(LatLng l) =>
      l.latitude >= -90 &&
      l.latitude <= 90 &&
      l.longitude >= -180 &&
      l.longitude <= 180;

  static bool isPickupAheadOfDriver({
    required LatLng pickupLocation,
    required LatLng driverLocation,
    required LatLng destinationLocation,
    required double minRequiredDistance,
  }) {
    try {
      if (!isValidLocation(pickupLocation) ||
          !isValidLocation(driverLocation) ||
          !isValidLocation(destinationLocation)) {
        return false;
      }
      final driverToPickup = calculateDistance(driverLocation, pickupLocation);
      final driverToDest =
          calculateDistance(driverLocation, destinationLocation);
      if (driverToPickup > AppConfig.maxDistanceSecondaryCheck) return false;
      if (driverToDest < BookingConstants.nearDestinationThreshold) {
        return _validatePickupNearDestination(
          driverLocation: driverLocation,
          pickupLocation: pickupLocation,
          driverToPickupDistance: driverToPickup,
        );
      }
      return _validatePickupOnRoute(
        driverLocation: driverLocation,
        pickupLocation: pickupLocation,
        destinationLocation: destinationLocation,
        driverToPickupDistance: driverToPickup,
        minRequiredDistance: minRequiredDistance,
      );
    } catch (_) {
      return false;
    }
  }

  static bool _validatePickupNearDestination({
    required LatLng driverLocation,
    required LatLng pickupLocation,
    required double driverToPickupDistance,
  }) {
    final bearing = calculateBearing(driverLocation, pickupLocation);
    final isBehind = bearing > AppConfig.behindDriverMinBearing &&
        bearing < AppConfig.behindDriverMaxBearing;
    if (isBehind) return false;
    return driverToPickupDistance < AppConfig.maxPickupDistanceThreshold;
  }

  static bool _validatePickupOnRoute({
    required LatLng driverLocation,
    required LatLng pickupLocation,
    required LatLng destinationLocation,
    required double driverToPickupDistance,
    required double minRequiredDistance,
  }) {
    final driverBearing = calculateBearing(driverLocation, destinationLocation);
    final ahead = isPointAhead(pickupLocation, driverLocation, driverBearing);
    if (!ahead) return false;
    if (driverToPickupDistance < minRequiredDistance) return false;
    return true;
  }
}
