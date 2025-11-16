import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:pasada_driver_side/Services/notification_service.dart';
import 'package:pasada_driver_side/presentation/providers/driver/driver_provider.dart';
import 'package:pasada_driver_side/presentation/providers/passenger/passenger_provider.dart';
import 'package:pasada_driver_side/common/constants/booking_constants.dart';

/// Keeps a lightweight listener running to detect new bookings while the app
/// is backgrounded (or foregrounded) when the driver is Driving.
///
/// This relies on the foreground service to keep the main isolate alive.
class BookingBackgroundService with WidgetsBindingObserver {
  BookingBackgroundService._();
  static final BookingBackgroundService instance = BookingBackgroundService._();

  StreamSubscription<List<dynamic>>?
      _bookingsSub; // dynamic to avoid import bleed
  VoidCallback? _driverListener;
  BuildContext? _context;
  bool _isStarted = false;
  final Set<String> _seenBookingIds = <String>{};
  DateTime? _lastNotifyAt;

  bool get isStarted => _isStarted;

  /// Start watching driver status and booking updates.
  /// Safe to call multiple times; it'll no-op if already started.
  void start(BuildContext context) {
    if (_isStarted) return;
    _isStarted = true;
    _context = context;

    // Track app lifecycle to handle stream resiliency across background/foreground
    WidgetsBinding.instance.addObserver(this);

    // Attach driver status listener to start/stop booking stream reactively.
    final driverProv = context.read<DriverProvider>();
    _driverListener = () => _handleDriverStateChanged(context);
    driverProv.addListener(_driverListener!);

    // Perform initial evaluation.
    _handleDriverStateChanged(context);
  }

  /// Stop and clean up.
  void stop() {
    if (!_isStarted) return;
    _isStarted = false;

    try {
      _bookingsSub?.cancel();
    } catch (_) {}
    _bookingsSub = null;

    try {
      WidgetsBinding.instance.removeObserver(this);
    } catch (_) {}

    if (_context != null && _driverListener != null) {
      try {
        _context!.read<DriverProvider>().removeListener(_driverListener!);
      } catch (_) {}
    }
    _driverListener = null;
    _context = null;
    _seenBookingIds.clear();
    _lastNotifyAt = null;
  }

  void _handleDriverStateChanged(BuildContext context) {
    final driverProv = context.read<DriverProvider>();
    final passengerProv = context.read<PassengerProvider>();

    final bool isLoggedIn = driverProv.driverID.isNotEmpty;
    final bool isDriving = driverProv.driverStatus == 'Driving';

    if (!isLoggedIn || !isDriving) {
      // Stop stream if running
      passengerProv.stopBookingStream();
      _bookingsSub?.cancel();
      _bookingsSub = null;
      _seenBookingIds.clear();
      return;
    }

    // Ensure stream is started for this driver
    passengerProv.startBookingStream(driverProv.driverID);

    // (Re)subscribe to booking updates to detect new bookings
    _resubscribeToBookings(passengerProv);
  }

  void _resubscribeToBookings(PassengerProvider passengerProv) {
    try {
      _bookingsSub?.cancel();
    } catch (_) {}
    _bookingsSub = passengerProv.bookingsStream.listen((list) {
      _onBookingsUpdated(list);
    }, onError: (err) {
      if (kDebugMode) {
        debugPrint('BookingBackgroundService stream error: $err');
      }
    });
  }

  void _onBookingsUpdated(List<dynamic> list) {
    // If list is empty, clear cache and cancel any lingering notifications
    if (list.isEmpty) {
      for (final id in _seenBookingIds.toList()) {
        NotificationService.instance.cancelNotificationByBookingId(id);
        _seenBookingIds.remove(id);
      }
      return;
    }

    // Build current snapshot maps
    final Set<String> currentIds = <String>{};
    final Map<String, String> currentStatus = <String, String>{};

    for (final b in list) {
      try {
        final String id = (b as dynamic).id as String;
        final String status = (b as dynamic).rideStatus as String;
        currentIds.add(id);
        currentStatus[id] = status;
      } catch (_) {}
    }

    // Cancel notifications for bookings that are no longer active or moved past accepted/requested
    for (final id in _seenBookingIds.toList()) {
      final String? status = currentStatus[id];
      final bool stillVisible = currentIds.contains(id);
      final bool stillNotifyEligible =
          status == BookingConstants.statusRequested ||
              status == BookingConstants.statusAccepted;
      if (!stillVisible || !stillNotifyEligible) {
        NotificationService.instance.cancelNotificationByBookingId(id);
        _seenBookingIds.remove(id);
      }
    }

    // Detect new/previously unseen IDs in requested/accepted
    final now = DateTime.now();
    for (final entry in currentStatus.entries) {
      final String id = entry.key;
      final String status = entry.value;
      if (!_seenBookingIds.contains(id) &&
          (status == BookingConstants.statusRequested ||
              status == BookingConstants.statusAccepted)) {
        _seenBookingIds.add(id);
        if (_shouldNotify(now)) {
          NotificationService.instance.showBasicNotification(
            status == BookingConstants.statusRequested
                ? 'New Booking Request'
                : 'May nag book sa\'yo manong!',
            status == BookingConstants.statusRequested
                ? 'A passenger requested a ride.'
                : 'Return to the app to accept the booking.',
            bookingId: id,
          );
          _lastNotifyAt = now;
        }
      }
    }
  }

  bool _shouldNotify(DateTime now) {
    if (_lastNotifyAt == null) return true;
    return now.difference(_lastNotifyAt!).inSeconds >= 5;
  }

  // Lifecycle resilience: when app resumes or pauses, refresh the stream binding.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isStarted || _context == null) return;
    final ctx = _context!;
    // Only attempt to refresh stream bindings when authenticated and in Driving
    final driverProv = ctx.read<DriverProvider>();
    final passengerProv = ctx.read<PassengerProvider>();
    final bool isLoggedIn = driverProv.driverID.isNotEmpty;
    final bool isDriving = driverProv.driverStatus == 'Driving';
    if (!isLoggedIn || !isDriving) return;

    switch (state) {
      case AppLifecycleState.resumed:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        // Restart the booking stream and reattach listener to handle platform transport changes
        passengerProv.startBookingStream(driverProv.driverID);
        _resubscribeToBookings(passengerProv);
        break;
      case AppLifecycleState.detached:
      case AppLifecycleState.inactive:
        // No action
        break;
    }
  }
}
