import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pasada_driver_side/common/geo/location_service.dart';

/// Service to calculate fare based on distance in kilometers
class FareService {
  static const double baseFare = 15.0;
  static const double ratePerKm = 2.2;
  static const double discountPercentage = 0.20; // 20% discount

  /// Calculates fare for the given distance (in km)
  static double calculateFare(double distanceInKm) {
    if (distanceInKm <= 4.0) {
      return baseFare;
    }
    return baseFare + (distanceInKm - 4.0) * ratePerKm;
  }

  /// Applies the standard discount (20%) to a fare
  static double applyDiscount(double originalFare) {
    return originalFare * (1 - discountPercentage);
  }

  /// Gets the discount amount for display purposes
  static double getDiscountAmount(double originalFare) {
    return originalFare * discountPercentage;
  }

  /// Calculates fare between two coordinates by computing distance (in km) via map_utils
  static double calculateFareBetween(LatLng start, LatLng end) {
    final meters = LocationService.calculateDistance(start, end);
    final distance = meters.isFinite ? meters / 1000.0 : double.infinity;
    return calculateFare(distance);
  }

  /// Calculates fare for a full polyline by summing segment distances
  static double calculateFareForPolyline(List<LatLng> polyline) {
    double totalDistance = 0.0;
    for (int i = 0; i < polyline.length - 1; i++) {
      final meters =
          LocationService.calculateDistance(polyline[i], polyline[i + 1]);
      totalDistance += meters.isFinite ? meters / 1000.0 : 0.0;
    }
    return calculateFare(totalDistance);
  }
}
