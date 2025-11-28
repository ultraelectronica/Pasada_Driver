import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:pasada_driver_side/data/repositories/booking_repository.dart';
import 'package:pasada_driver_side/data/repositories/supabase_booking_repository.dart';
import 'package:pasada_driver_side/common/constants/booking_constants.dart';
import 'package:pasada_driver_side/common/logging/booking_logger.dart';
import 'package:pasada_driver_side/common/exceptions/booking_exception.dart';
import 'package:pasada_driver_side/data/models/booking_model.dart';

/// Service that encapsulates the real-time Supabase bookings stream and
/// exposes a broadcast [Stream] that UI/state-management layers can listen to
/// without worrying about reconnect/back-off logic.
class BookingStreamService {
  BookingStreamService({BookingRepository? repository})
      : _repository = repository ?? SupabaseBookingRepository();

  final BookingRepository _repository;

  // Internal broadcast controller so multiple listeners can attach.
  final StreamController<List<Booking>> _controller =
      StreamController<List<Booking>>.broadcast();

  StreamSubscription<List<Booking>>? _subscription;
  Timer? _reconnectTimer;
  String? _currentDriverId;
  bool _isDisposed = false;

  // Exposed immutable stream.
  Stream<List<Booking>> get stream => _controller.stream;

  // Convenience accessors for error state (optional for UI).
  String? error;
  String? errorType;

  /// The driver ID for which the stream is currently active (null if none).
  String? get currentDriverId => _currentDriverId;

  /// Start (or restart) listening to booking updates for the given [driverId].
  void start(String driverId) {
    if (_isDisposed) return;

    // Cancel any previous subscription/timer before starting a new one.
    _subscription?.cancel();
    _reconnectTimer?.cancel();

    _currentDriverId = driverId;

    BookingLogger.log('BookingStreamService: start stream for $driverId',
        type: 'STREAM');

    try {
      _subscription = _repository
          .activeBookingsStream(driverId)
          .listen(_onData, onError: _onError, cancelOnError: false);
    } catch (e) {
      _handleFatalError(e);
    }
  }

  /// Stop listening and clean up resources. You can call [start] again later.
  void stop() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    _subscription?.cancel();
    _subscription = null;

    _currentDriverId = null;
  }

  /// Dispose permanently. After calling this, the instance shouldn't be used.
  void dispose() {
    if (_isDisposed) return;
    stop();
    _controller.close();
    _isDisposed = true;
  }

  void _onData(List<Booking> data) {
    if (_isDisposed) return;
    error = null;
    errorType = null;
    if (!_controller.isClosed) {
      _controller.add(data);
    }
  }

  void _onError(Object err) {
    if (_isDisposed) return;

    if (err is BookingException) {
      error = err.message;
      errorType = err.type;
    } else {
      error = err.toString();
      errorType = BookingConstants.errorTypeUnknown;
    }

    if (kDebugMode) {
      debugPrint('BookingStreamService: stream error -> $err');
    }

    BookingLogger.log('BookingStreamService error: $err', type: 'ERROR');

    // Attempt to reconnect after short delay.
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (_currentDriverId != null && !_isDisposed) {
        start(_currentDriverId!);
      }
    });
  }

  void _handleFatalError(Object err) {
    if (_isDisposed) return;

    error = err.toString();
    errorType = BookingConstants.errorTypeUnknown;
    BookingLogger.log('BookingStreamService failed to start: $err',
        type: 'ERROR');

    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (_currentDriverId != null && !_isDisposed) {
        start(_currentDriverId!);
      }
    });
  }
}
