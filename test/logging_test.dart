import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pasada_driver_side/common/logging.dart';

void main() {
  test('logDebug prints only when in debug mode', () {
    String? captured;

    debugPrint = (String? message, {int? wrapWidth}) {
      captured = message;
    };

    logDebug('hello');
    // In debug mode (`flutter test`), we expect the message to be captured.
    expect(captured, 'hello');

    // restore debugPrint
    debugPrint = debugPrintThrottled;
  });
}
