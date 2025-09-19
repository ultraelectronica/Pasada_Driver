import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pasada_driver_side/common/utils/network/network_utility.dart';
import 'package:pasada_driver_side/common/constants/message.dart';

/// Domain service responsible for polyline generation and route processing
/// Handles all business logic related to map routes and polylines
class PolylineService {
  static const String _fieldMask = 'routes.polyline.encodedPolyline';
  static const String _routesApiUrl =
      'https://routes.googleapis.com/directions/v2:computeRoutes';

  final PolylinePoints _polylinePoints = PolylinePoints();

  /// Generate polyline between two points with optional waypoints
  /// This method consolidates all polyline generation logic
  Future<List<LatLng>?> generatePolyline({
    required LatLng start,
    required LatLng end,
    List<LatLng>? waypoints,
    LatLng? currentLocation,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint(
            'PolylineService: Generating polyline from ${start.latitude},${start.longitude} to ${end.latitude},${end.longitude}');
        if (waypoints != null && waypoints.isNotEmpty) {
          debugPrint('PolylineService: With ${waypoints.length} waypoints');
        }
        if (currentLocation != null) {
          debugPrint(
              'PolylineService: Current location: ${currentLocation.latitude},${currentLocation.longitude}');
        }
      }

      final apiKey = dotenv.env['ANDROID_MAPS_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        if (kDebugMode) {
          debugPrint('ERROR: API key is empty');
        }
        return null;
      }

      final uri = Uri.parse(_routesApiUrl);
      final headers = {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': apiKey,
        'X-Goog-FieldMask': _fieldMask,
      };

      final requestBody = _buildRouteRequest(
        start: start,
        end: end,
        waypoints: waypoints,
        currentLocation: currentLocation,
      );

      final response = await NetworkUtility.postUrl(
        uri,
        headers: headers,
        body: jsonEncode(requestBody),
      );

      if (response == null) {
        ShowMessage().showToast('Could not get route');
        return null;
      }

      return _processRouteResponse(response);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('PolylineService: Error generating polyline: $e');
      }
      ShowMessage().showToast('Error generating route');
      return null;
    }
  }

  /// Generate polyline with multiple intermediate points
  Future<List<LatLng>?> generatePolylineBetween({
    required LatLng start,
    required LatLng destination,
    required List<LatLng> intermediatePoints,
  }) async {
    try {
      return await generatePolyline(
        start: start,
        end: destination,
        waypoints: intermediatePoints,
      );
    } catch (e) {
      ShowMessage().showToast('Error: ${e.toString()}');
      if (kDebugMode) {
        debugPrint(
            'PolylineService: Error generating polyline between points: $e');
      }
      return null;
    }
  }

  /// Build the request body for Google Routes API
  Map<String, dynamic> _buildRouteRequest({
    required LatLng start,
    required LatLng end,
    List<LatLng>? waypoints,
    LatLng? currentLocation,
  }) {
    final Map<String, dynamic> requestBody = {
      'origin': {
        'location': {
          'latLng': {
            'latitude': start.latitude,
            'longitude': start.longitude,
          },
        },
      },
      'destination': {
        'location': {
          'latLng': {
            'latitude': end.latitude,
            'longitude': end.longitude,
          },
        },
      },
      'travelMode': 'DRIVE',
      'polylineEncoding': 'ENCODED_POLYLINE',
      'computeAlternativeRoutes': true,
      'routingPreference': 'TRAFFIC_AWARE_OPTIMAL',
    };

    // Add waypoints if provided
    List<Map<String, dynamic>> intermediates = [];

    // First add the current location as a via point if provided
    if (currentLocation != null) {
      intermediates.add({
        'location': {
          'latLng': {
            'latitude': currentLocation.latitude,
            'longitude': currentLocation.longitude,
          }
        },
        'routeModifiers': {'avoidTurnsByHighwayClass': true}
      });
    }

    // Then add the route waypoints
    if (waypoints != null && waypoints.isNotEmpty) {
      for (var point in waypoints) {
        intermediates.add({
          'location': {
            'latLng': {
              'latitude': point.latitude,
              'longitude': point.longitude,
            }
          }
        });
      }
    }

    // Only add intermediates if we have any
    if (intermediates.isNotEmpty) {
      requestBody['intermediates'] = intermediates;
    }

    return requestBody;
  }

  /// Process the route response from Google Routes API
  List<LatLng>? _processRouteResponse(String response) {
    try {
      final data = json.decode(response);

      // Check for routes
      if (data['routes'] == null || data['routes'].isEmpty) {
        ShowMessage().showToast('No route found');
        return null;
      }

      // Get polyline
      final polyline = data['routes'][0]['polyline']?['encodedPolyline'];
      if (polyline == null) {
        ShowMessage().showToast('No route data found');
        return null;
      }

      // Decode polyline
      List<PointLatLng> decodedPolyline =
          _polylinePoints.decodePolyline(polyline);
      List<LatLng> polylineCoordinates = decodedPolyline
          .map((point) => LatLng(point.latitude, point.longitude))
          .toList();

      return polylineCoordinates;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('PolylineService: Error processing route response: $e');
      }
      ShowMessage().showToast('Error processing route');
      return null;
    }
  }

  /// Create a polyline object with standard styling
  Polyline createPolyline({
    required String id,
    required List<LatLng> points,
    Color color = const Color.fromARGB(255, 255, 35, 35),
    int width = 8,
  }) {
    return Polyline(
      polylineId: PolylineId(id),
      points: points,
      color: color,
      width: width,
    );
  }
}
