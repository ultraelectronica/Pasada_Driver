import 'package:location/location.dart';

/// Singleton wrapper around the `location` plugin that exposes a stream of
/// continuous [LocationData] updates.  This service lives in the **domain**
/// layer so it contains no Flutter imports and can be unit-tested.
class LocationTracker {
  LocationTracker._internal();
  static final LocationTracker instance = LocationTracker._internal();

  final Location _location = Location();

  /// Returns the live location stream.  Consumers should handle permission
  /// checks before listening.
  Stream<LocationData> get locationStream => _location.onLocationChanged;

  /// One-shot current position retrieval.
  Future<LocationData> current() => _location.getLocation();
}
