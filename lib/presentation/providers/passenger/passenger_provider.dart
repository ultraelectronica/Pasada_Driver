// export 'package:pasada_driver_side/Database/passenger_provider.dart';

// PassengerProvider moved from lib/Database/passenger_provider.dart
// Coordinates booking-related driver UI state

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import 'package:pasada_driver_side/common/config/app_config.dart';
import 'package:pasada_driver_side/common/constants/booking_constants.dart';
import 'package:pasada_driver_side/common/exceptions/booking_exception.dart';
import 'package:pasada_driver_side/common/logging/booking_logger.dart';
import 'package:pasada_driver_side/data/repositories/booking_repository.dart';
import 'package:pasada_driver_side/data/repositories/supabase_booking_repository.dart';
import 'package:pasada_driver_side/data/models/booking_model.dart';
import 'package:pasada_driver_side/presentation/providers/driver/driver_provider.dart';
import 'package:pasada_driver_side/presentation/providers/map_provider.dart';
import 'booking_processor.dart';
import 'booking_stream_service.dart';

/// Provider to manage passenger booking state and expose it to Flutter UI.
class PassengerProvider with ChangeNotifier {
  // ───────────────────────── Dependencies ─────────────────────────
  final BookingRepository _repository;
  late final BookingStreamService _streamService;
  late final BookingProcessor _bookingProcessor;

  // ───────────────────────── State ─────────────────────────
  int _passengerCapacity = 0;
  int _completedBooking = 0;
  List<Booking> _bookings = [];
  bool _isProcessingBookings = false;
  DateTime? _lastFetchTime;

  String? _error;
  String? _errorType;

  final StreamController<List<Booking>> _bookingsStreamController =
      StreamController<List<Booking>>.broadcast();
  StreamSubscription<List<Booking>>? _bookingsSubscription;

  bool _isDisposed = false;

  // ───────────────────────── Getters ─────────────────────────
  int get passengerCapacity => _passengerCapacity;
  int get completedBooking => _completedBooking;
  List<Booking> get bookings => List.unmodifiable(_bookings);
  bool get isProcessingBookings => _isProcessingBookings;
  bool _isMutatingBooking = false;
  bool get isMutatingBooking => _isMutatingBooking;
  DateTime? get lastFetchTime => _lastFetchTime;
  Stream<List<Booking>> get bookingsStream => _bookingsStreamController.stream;
  String? get error => _error;
  String? get errorType => _errorType;

  // 3-state loading alias
  bool get isLoading => _isProcessingBookings;

  // ───────────────────────── ctor / dispose ─────────────────────────
  PassengerProvider({BookingRepository? repository})
      : _repository = repository ?? SupabaseBookingRepository() {
    BookingLogger.init();
    _streamService = BookingStreamService(repository: _repository);
    _bookingProcessor = BookingProcessor(repository: _repository);
  }

  @override
  void dispose() {
    BookingLogger.log('PassengerProvider disposed', type: 'LIFECYCLE');
    _isDisposed = true;
    _bookingsSubscription?.cancel();
    _bookingsStreamController.close();
    _streamService.dispose();
    super.dispose();
  }

  // ───────────────────────── Stream control ─────────────────────────
  void startBookingStream(String driverId) {
    if (_isDisposed) return;
    _bookingsSubscription?.cancel();
    _streamService.start(driverId);
    _bookingsSubscription = _streamService.stream.listen((list) {
      if (_isDisposed) return;
      _bookings = list;
      _error = _streamService.error;
      _errorType = _streamService.errorType;
      if (!_bookingsStreamController.isClosed)
        _bookingsStreamController.add(list);
      notifyListeners();
    });
  }

  void stopBookingStream() {
    _bookingsSubscription?.cancel();
    _bookingsSubscription = null;
    _streamService.stop();
  }

  // ───────────────────────── Mutators ─────────────────────────
  void setPassengerCapacity(int value) {
    if (_isDisposed) return;
    _passengerCapacity = value;
    notifyListeners();
  }

  void setCompletedBooking(int value) {
    if (_isDisposed) return;
    _completedBooking = value;
    notifyListeners();
  }

  void setBookings(List<Booking> list) {
    if (_isDisposed) return;
    _bookings = list;
    if (!_bookingsStreamController.isClosed)
      _bookingsStreamController.add(list);
    notifyListeners();
  }

  void clearError() {
    if (_isDisposed) return;
    _error = null;
    _errorType = null;
    notifyListeners();
  }

  // ───────────────────────── Public API ─────────────────────────
  Future<void> getBookingRequestsID(BuildContext? ctx) async {
    final mountedCtx = ctx?.mounted == true;
    if (_isProcessingBookings || _isDisposed) return;

    // debounce
    final now = DateTime.now();
    if (_lastFetchTime != null &&
        now.difference(_lastFetchTime!).inSeconds < AppConfig.fetchDebounceTime)
      return;

    _isProcessingBookings = true;
    notifyListeners();

    try {
      // read providers if we can
      String? driverStatus;
      String? driverId = _streamService.currentDriverId;
      LatLng? endingLocation;
      if (mountedCtx) {
        try {
          driverStatus = ctx!.read<DriverProvider>().driverStatus;
          driverId = ctx.read<DriverProvider>().driverID;
          endingLocation = ctx.read<MapProvider>().endingLocation;
        } catch (_) {}
      }

      if (driverStatus != 'Driving' || driverId == null || driverId.isEmpty) {
        _isProcessingBookings = false;
        notifyListeners();
        return;
      }

      // get current location
      LatLng? currentLocation;
      if (mountedCtx) {
        currentLocation = await _getCurrentLocation(ctx!);
      }
      if (currentLocation == null) {
        final pos = await Geolocator.getCurrentPosition(
                locationSettings:
                    const LocationSettings(accuracy: LocationAccuracy.high))
            .timeout(const Duration(seconds: AppConfig.locationFetchTimeout));
        currentLocation = LatLng(pos.latitude, pos.longitude);
      }

      final active = await _repository.fetchActiveBookings(driverId);
      if (active.isEmpty) {
        _clearBookingData();
        _isProcessingBookings = false;
        notifyListeners();
        return;
      }

      final processed = await _bookingProcessor.process(
        activeBookings: active,
        driverLocation: currentLocation,
        endingLocation: endingLocation ?? currentLocation,
        driverId: driverId,
      );

      if (!_isDisposed) {
        if (processed.isNotEmpty) {
          setBookings(processed);
        } else {
          _clearBookingData();
        }
        _lastFetchTime = now;
      }
    } catch (e) {
      if (_isDisposed) return;
      if (e is BookingException) {
        _error = e.message;
        _errorType = e.type;
      } else {
        _error = e.toString();
        _errorType = BookingConstants.errorTypeUnknown;
      }
      _clearBookingData();
    } finally {
      if (!_isDisposed) {
        _isProcessingBookings = false;
        notifyListeners();
      }
    }
  }

  // ───────────────────────── Helpers ─────────────────────────
  Future<LatLng?> _getCurrentLocation(BuildContext context) async {
    try {
      final pos = await Geolocator.getCurrentPosition(
              locationSettings:
                  const LocationSettings(accuracy: LocationAccuracy.high))
          .timeout(const Duration(seconds: AppConfig.locationFetchTimeout));
      final loc = LatLng(pos.latitude, pos.longitude);
      if (context.mounted) {
        context.read<MapProvider>().setCurrentLocation(loc);
      }
      return loc;
    } catch (_) {
      return null;
    }
  }

  void _clearBookingData() {
    if (_isDisposed) return;
    setBookings([]);
  }

  Future<bool> _setBookingStatus({
    required String bookingId,
    required String newStatus,
    bool removeOnSuccess = false,
    bool optimistic = true,
  }) async {
    try {
      _isMutatingBooking = true;
      notifyListeners();
      final int existingIndex = _bookings.indexWhere((b) => b.id == bookingId);
      final Booking? booking =
          existingIndex >= 0 ? _bookings[existingIndex] : null;

      if (booking != null && booking.distanceToDriver != null) {
        BookingLogger.log(
            'Distance metric available: \\${booking.distanceToDriver!.toStringAsFixed(2)}m',
            type: 'DISTANCE');
      }

      final previous = List<Booking>.from(_bookings);

      if (optimistic && !_isDisposed && booking != null) {
        if (removeOnSuccess) {
          final optimisticList =
              _bookings.where((b) => b.id != bookingId).toList();
          setBookings(optimisticList);
        } else {
          final optimisticList = _bookings.map((b) {
            if (b.id == bookingId) return b.copyWith(rideStatus: newStatus);
            return b;
          }).toList();
          setBookings(optimisticList);
        }
      }

      final success =
          await _repository.updateBookingStatus(bookingId, newStatus);

      if (success) {
        if (!optimistic && !_isDisposed) {
          if (removeOnSuccess) {
            final updated = _bookings.where((b) => b.id != bookingId).toList();
            setBookings(updated);
          } else {
            final updated = _bookings.map((b) {
              if (b.id == bookingId) return b.copyWith(rideStatus: newStatus);
              return b;
            }).toList();
            setBookings(updated);
          }
        }
        // If we didn't have the booking locally (e.g., after optimistic removal),
        // refresh the list to reflect the backend state.
        if (booking == null && !_isDisposed) {
          await getBookingRequestsID(null);
        }
        return true;
      } else {
        if (optimistic && !_isDisposed) {
          setBookings(previous);
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error setting booking status: $e');
      }
      if (!_isDisposed) {
        if (e is BookingException) {
          _error = e.message;
          _errorType = e.type;
        } else {
          _error = e.toString();
          _errorType = BookingConstants.errorTypeUnknown;
        }
        notifyListeners();
      }
      return false;
    } finally {
      if (!_isDisposed) {
        _isMutatingBooking = false;
        notifyListeners();
      }
    }
  }

  /// Mark a booking as ongoing when driver is near pickup location
  Future<bool> markBookingAsOngoing(String bookingId) async {
    BookingLogger.log('Attempting to mark booking $bookingId as ongoing',
        type: 'ACTION');
    final ok = await _setBookingStatus(
        bookingId: bookingId,
        newStatus: BookingConstants.statusOngoing,
        optimistic: true);
    if (ok) {
      BookingLogger.log('Successfully marked booking $bookingId as ongoing',
          type: 'SUCCESS');
    } else {
      BookingLogger.log(
          'Failed to mark booking $bookingId as ongoing: Database update failed',
          type: 'FAILURE');
    }
    return ok;
  }

  /// Revert or set a booking to accepted status
  Future<bool> markBookingAsAccepted(String bookingId) async {
    BookingLogger.log('Setting booking $bookingId as accepted', type: 'ACTION');
    final ok = await _setBookingStatus(
        bookingId: bookingId, newStatus: BookingConstants.statusAccepted);
    if (ok) {
      BookingLogger.log('Successfully set booking $bookingId as accepted',
          type: 'SUCCESS');
    }
    return ok;
  }

  /// Mark a booking as completed when passenger reaches destination
  Future<bool> markBookingAsCompleted(String bookingId) async {
    BookingLogger.log('Attempting to mark booking $bookingId as completed',
        type: 'ACTION');
    final ok = await _setBookingStatus(
      bookingId: bookingId,
      newStatus: BookingConstants.statusCompleted,
      removeOnSuccess: true,
      optimistic: true,
    );
    if (ok && !_isDisposed) {
      setCompletedBooking(_completedBooking + 1);
      BookingLogger.log('Successfully marked booking $bookingId as completed',
          type: 'SUCCESS');
    } else if (!ok) {
      BookingLogger.log(
          'Failed to mark booking $bookingId as completed: Database update failed',
          type: 'FAILURE');
    }
    return ok;
  }

  /// Fetch completed bookings count
  Future<void> getCompletedBookings(BuildContext context) async {
    try {
      if (!context.mounted) {
        return;
      }

      final driverID = context.read<DriverProvider>().driverID;

      if (driverID.isEmpty || driverID == 'N/A') {
        setCompletedBooking(0);
        return;
      }

      final count = await _repository.fetchCompletedBookingsCount(driverID);
      setCompletedBooking(count);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error fetching completed bookings: $e');
      }
      setCompletedBooking(0);

      if (!_isDisposed) {
        if (e is BookingException) {
          _error = e.message;
          _errorType = e.type;
        } else {
          _error = e.toString();
          _errorType = BookingConstants.errorTypeUnknown;
        }
        notifyListeners();
      }
    }
  }
}
