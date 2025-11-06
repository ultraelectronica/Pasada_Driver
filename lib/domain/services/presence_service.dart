import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:pasada_driver_side/presentation/providers/driver/driver_provider.dart';

/// Sends periodic presence heartbeats to the backend by updating `last_online`.
class PresenceService {
  PresenceService._();
  static final PresenceService instance = PresenceService._();

  Timer? _timer;
  bool _isRunning = false;

  bool get isRunning => _isRunning;

  /// Start presence heartbeat.
  /// The [context] must have access to [DriverProvider].
  void start(BuildContext context,
      {Duration interval = const Duration(seconds: 30)}) {
    if (_isRunning) return;

    // Immediate heartbeat on start
    _sendHeartbeat(context);

    _timer = Timer.periodic(interval, (_) => _sendHeartbeat(context));
    _isRunning = true;
    if (kDebugMode) {
      debugPrint('[PresenceService] started (interval=${interval.inSeconds}s)');
    }
  }

  /// Stop presence heartbeat.
  void stop() {
    _timer?.cancel();
    _timer = null;
    _isRunning = false;
    if (kDebugMode) {
      debugPrint('PresenceService: stopped');
    }
  }

  Future<void> _sendHeartbeat(BuildContext context) async {
    try {
      final driverProvider = context.read<DriverProvider>();
      await driverProvider.updateLastOnline(context);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('PresenceService: heartbeat failed: $e');
      }
    }
  }
}
