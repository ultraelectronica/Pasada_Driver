import 'package:google_maps_flutter/google_maps_flutter.dart';

class RouteLocation {
  final String address;
  final LatLng coordinates;

  RouteLocation({
    required this.address,
    required this.coordinates,
  });
}