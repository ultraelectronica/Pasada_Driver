import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pasada_driver_side/presentation/providers/map_provider.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Initialize Supabase with dummy credentials to satisfy assertion
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
        url: 'https://dummy.supabase.co', anonKey: 'dummy');
  });

  group('MapProvider markers', () {
    test('creates route + current + pickup markers', () {
      final provider = MapProvider();
      provider.setCurrentLocation(const LatLng(10, 10));
      provider.setPickUpLocation(const LatLng(11, 11));
      provider.setRouteID(1);
      provider.setRouteDataDebug(const RouteData(
        origin: LatLng(10, 10),
        destination: LatLng(12, 12),
        intermediatePoints: [],
        routeId: 1,
      ));

      // The provider should create markers for current, start, end, and pickup.
      expect(provider.markers.length, 4);
    });
  });
}
