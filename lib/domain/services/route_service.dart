import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:meta/meta.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:pasada_driver_side/common/utils/network/network_utility.dart';

class RouteService {
  RouteService._();

  static final _polylinePoints = PolylinePoints();
  static final String _apiKey = dotenv.env['ANDROID_MAPS_API_KEY'] ?? '';

  // ---- test overrides ----
  @protected
  static String? apiKeyOverride;

  @protected
  static Future<String?> Function(Uri uri,
      {Map<String, String>? headers, Object? body})? postUrlOverride;

  /// Returns the full list of coordinates (including intermediates) for a route
  /// between [origin] and [destination].  If [waypoints] are supplied they are
  /// sent as "intermediates" to the API.
  static Future<List<LatLng>> fetchRoute({
    required LatLng origin,
    required LatLng destination,
    List<LatLng>? waypoints,
  }) async {
    final key = apiKeyOverride ?? _apiKey;
    if (key.isEmpty) {
      throw StateError('Google Maps API key not configured');
    }

    final uri =
        Uri.parse('https://routes.googleapis.com/directions/v2:computeRoutes');
    final headers = {
      'Content-Type': 'application/json',
      'X-Goog-Api-Key': key,
      'X-Goog-FieldMask': 'routes.polyline.encodedPolyline',
    };

    final body = _buildRequestBody(origin, destination, waypoints);

    final resp = postUrlOverride != null
        ? await postUrlOverride!(uri, headers: headers, body: jsonEncode(body))
        : await NetworkUtility.postUrl(uri,
            headers: headers, body: jsonEncode(body));

    if (resp == null) {
      throw Exception('RouteService: empty response from Routes API');
    }

    return _decodePolylineCoordinates(resp);
  }

  /// Build the API JSON payload.
  static Map<String, dynamic> _buildRequestBody(
      LatLng origin, LatLng dest, List<LatLng>? waypoints) {
    final Map<String, dynamic> body = {
      'origin': {
        'location': {
          'latLng': {
            'latitude': origin.latitude,
            'longitude': origin.longitude,
          },
        },
      },
      'destination': {
        'location': {
          'latLng': {
            'latitude': dest.latitude,
            'longitude': dest.longitude,
          },
        },
      },
      'travelMode': 'DRIVE',
      'polylineEncoding': 'ENCODED_POLYLINE',
      'computeAlternativeRoutes': true,
      'routingPreference': 'TRAFFIC_AWARE_OPTIMAL',
    };

    if (waypoints != null && waypoints.isNotEmpty) {
      body['intermediates'] = waypoints
          .map((p) => {
                'location': {
                  'latLng': {
                    'latitude': p.latitude,
                    'longitude': p.longitude,
                  }
                }
              })
          .toList();
    }
    return body;
  }

  /// Extract encoded polyline from API json and decode it.
  static List<LatLng> _decodePolylineCoordinates(String responseBody) {
    final data = json.decode(responseBody);
    if (data['routes'] == null || data['routes'].isEmpty) {
      throw Exception('RouteService: no routes found');
    }
    final polyline = data['routes'][0]['polyline']?['encodedPolyline'];
    if (polyline == null) {
      throw Exception('RouteService: no polyline in response');
    }

    final List<PointLatLng> decoded = _polylinePoints.decodePolyline(polyline);
    return decoded.map((p) => LatLng(p.latitude, p.longitude)).toList();
  }
}
