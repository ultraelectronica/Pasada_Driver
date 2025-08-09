// ignore_for_file: invalid_use_of_protected_member

import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pasada_driver_side/domain/services/route_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RouteService', () {
    setUp(() {
      RouteService.apiKeyOverride = 'dummy';
      RouteService.postUrlOverride = (uri, {headers, body}) async {
        // minimal encoded polyline that decodes to two points
        const encoded = '_p~iF~ps|U_ulLnnqC';
        return '{"routes":[{"polyline":{"encodedPolyline":"$encoded"}}]}';
      };
    });

    tearDown(() {
      RouteService.apiKeyOverride = null;
      RouteService.postUrlOverride = null;
    });

    test('fetchRoute decodes polyline list', () async {
      final result = await RouteService.fetchRoute(
        origin: const LatLng(0, 0),
        destination: const LatLng(1, 1),
      );
      expect(result.length, greaterThan(1));
      expect(result.first, isA<LatLng>());
    });
  });
}
