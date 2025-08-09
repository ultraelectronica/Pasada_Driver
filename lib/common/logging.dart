import 'package:flutter/foundation.dart';

/// Prints [message] only in debug mode. Use this instead of sprinkling
/// `if (kDebugMode) debugPrint(...)` throughout the code to keep call sites
/// concise and consistent.
void logDebug(Object? message) {
  if (kDebugMode) {
    debugPrint(message.toString());
  }
}
