import 'package:flutter_test/flutter_test.dart';
import 'package:pasada_driver_side/presentation/pages/start/utils/start_constants.dart';

void main() {
  test('StartConstants values remain consistent', () {
    // expect(StartConstants.welcomeLogoTopFraction, 0.15);
    // expect(StartConstants.welcomeLogoSizeFraction, 0.4);
    expect(StartConstants.indicatorActiveWidth, 22);
    expect(StartConstants.indicatorInactiveSize, 8);
  });
}
