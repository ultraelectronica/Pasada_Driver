import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:pasada_driver_side/common/config/app_config.dart';
import 'package:pasada_driver_side/presentation/pages/home/models/passenger_status.dart';
import 'package:pasada_driver_side/common/constants/booking_constants.dart';
import 'package:pasada_driver_side/presentation/pages/home/utils/home_constants.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pasada_driver_side/presentation/providers/driver/driver_provider.dart';
import 'package:pasada_driver_side/presentation/providers/map_provider.dart';
import 'package:pasada_driver_side/presentation/providers/passenger/passenger_provider.dart';
import 'package:pasada_driver_side/presentation/pages/map/map_page.dart';
import 'package:flutter/material.dart';
import 'package:pasada_driver_side/presentation/pages/map/utils/marker_icons.dart';
import 'package:pasada_driver_side/Services/notification_service.dart';

/// Encapsulates **non-UI** logic for the Home page: proximity checks, periodic
/// booking fetches, and map-marker updates.
///
/// This class is **change-notifier** driven so the UI can subscribe only to the
/// fields it cares about instead of re-building the entire page on every state
/// change.
class HomeController extends ChangeNotifier {
  HomeController({
    required this.driverProvider,
    required this.mapProvider,
    required this.passengerProvider,
    required this.mapScreenKey,
  }) {
    _init();
  }

  //--------------------------------------------------------------------------
  // Dependencies
  //--------------------------------------------------------------------------
  final DriverProvider driverProvider;
  final MapProvider mapProvider;
  final PassengerProvider passengerProvider;
  final GlobalKey<MapPageState> mapScreenKey;

  //--------------------------------------------------------------------------
  // Public reactive fields (read-only outside)
  //--------------------------------------------------------------------------
  List<PassengerStatus> get nearbyPassengers =>
      List.unmodifiable(_nearbyPassengers);

  // list of nearby passengers with their status
  List<PassengerStatus> _nearbyPassengers = [];

  String? selectedPassengerId;

  bool get isNearPickupLocation => _isNearPickupLocation;
  bool _isNearPickupLocation = false;

  String? nearestBookingId;

  bool get isNearDropoffLocation => _isNearDropoffLocation;
  bool _isNearDropoffLocation = false;

  String? ongoingBookingId;

  bool get isLoadingBookings => _isLoadingBookings;
  bool _isLoadingBookings = false;

  //--------------------------------------------------------------------------
  // Private
  //--------------------------------------------------------------------------
  // DateTime? _lastProximityNotificationTime;
  Timer? _proximityCheckTimer;
  Timer? _bookingFetchTimer;
  bool _bookingStreamStarted = false;
  Timer? _recalcDebounceTimer;
  bool _isDisposed = false;

  // Track previous state for one-time notifications
  bool _previousIsNearPickupLocation = false;
  bool _previousIsNearDropoffLocation = false;
  String? _lastNotifiedPickupBookingId;
  String? _lastNotifiedDropoffBookingId;
  String? _lastFocusedTargetKey;

  void _init() {
    // Start timers.
    _proximityCheckTimer = Timer.periodic(
      const Duration(seconds: AppConfig.proximityCheckInterval),
      (_) => _checkProximity(),
    );

    _bookingFetchTimer = Timer.periodic(
      const Duration(seconds: AppConfig.periodicFetchInterval),
      (_) {
        if (driverProvider.driverStatus == 'Driving' && !_isLoadingBookings) {
          fetchBookings();
        }
      },
    );

    // Immediate first run.
    _checkProximity();
    fetchBookings();

    // React immediately to booking list changes to avoid UI lag
    passengerProvider.addListener(_onBookingsChanged);
  }

  //--------------------------------------------------------------------------
  // Booking fetch
  //--------------------------------------------------------------------------
  Future<void> fetchBookings() async {
    if (_isDisposed) return;
    if (_isLoadingBookings) return;
    _isLoadingBookings = true;
    if (!_isDisposed) notifyListeners();

    try {
      // Ensure driver is in driving mode before attempting fetch.
      if (driverProvider.driverStatus != 'Driving') return;

      final driverId = driverProvider.driverID;
      if (driverId.isEmpty) return;

      // Start real-time booking stream once.
      if (!_bookingStreamStarted) {
        passengerProvider.startBookingStream(driverId);
        _bookingStreamStarted = true;
      }

      // Pull latest bookings (null build context – non-UI layer).
      await passengerProvider.getBookingRequestsID(null);
    } finally {
      _isLoadingBookings = false;
      if (!_isDisposed) notifyListeners();
    }
  }

  //--------------------------------------------------------------------------
  // Proximity logic
  //--------------------------------------------------------------------------
  void _checkProximity() {
    if (_isDisposed) return;
    // Bail if not in driving mode.
    if (driverProvider.driverStatus != 'Driving') {
      _resetState();
      return;
    }

    final currentLocation = mapProvider.currentLocation;
    if (currentLocation == null) {
      _resetState();
      return;
    }

    final accepted = passengerProvider.bookings
        .where((b) => b.rideStatus == BookingConstants.statusAccepted)
        .toList();
    final ongoing = passengerProvider.bookings
        .where((b) => b.rideStatus == BookingConstants.statusOngoing)
        .toList();
    final allActive = [...accepted, ...ongoing];
    if (allActive.isEmpty) {
      _resetState();
      return;
    }

    // Calculate distances.
    final List<PassengerStatus> statuses = [];
    for (final booking in allActive) {
      double distance;
      bool isNearPickup = false;
      bool isApproachingPickup = false;
      bool isNearDropoff = false;
      bool isApproachingDropoff = false;

      // check if the booking is accepted
      if (booking.rideStatus == BookingConstants.statusAccepted) {
        distance = Geolocator.distanceBetween(
          currentLocation.latitude,
          currentLocation.longitude,
          booking.pickupLocation.latitude,
          booking.pickupLocation.longitude,
        );

        debugPrint('Pickup distance: ${distance.toStringAsFixed(0)} meters');
        // check if the pickup is approaching the driver
        isApproachingPickup =
            distance >= AppConfig.activePickupProximityThreshold &&
                distance < AppConfig.activePickupApproachThreshold;

        // check if the driver is at the pickup location
        isNearPickup = distance < AppConfig.activePickupProximityThreshold;
      } else {
        // check ongoing bookings
        // measure to drop-off distance
        distance = Geolocator.distanceBetween(
          currentLocation.latitude,
          currentLocation.longitude,
          booking.dropoffLocation.latitude,
          booking.dropoffLocation.longitude,
        );
        debugPrint('Dropoff distance: ${distance.toStringAsFixed(0)} meters');
        // check if the dropoff is approaching the driver
        isApproachingDropoff =
            distance >= AppConfig.activeDropoffProximityThreshold &&
                distance < AppConfig.activeDropoffApproachThreshold;

        // check if the driver is at the dropoff location
        isNearDropoff = distance < AppConfig.activeDropoffProximityThreshold;
      }

      // add the passenger based on its trip status to the list
      statuses.add(PassengerStatus(
        booking: booking,
        distance: distance,
        isNearPickup: isNearPickup,
        isApproachingPickup: isApproachingPickup,
        isNearDropoff: isNearDropoff,
        isApproachingDropoff: isApproachingDropoff,
      ));
    }

    statuses.sort((a, b) => a.distance.compareTo(b.distance));
    if (statuses.length > HomeConstants.maxNearbyPassengers) {
      _nearbyPassengers =
          statuses.sublist(0, HomeConstants.maxNearbyPassengers);
    } else {
      _nearbyPassengers = statuses;
    }

    // Update selection / flags.
    if (_nearbyPassengers.isNotEmpty) {
      final closest = _nearbyPassengers.first;
      selectedPassengerId = closest.booking.id;

      if (closest.booking.rideStatus == BookingConstants.statusAccepted) {
        _isNearPickupLocation = closest.isNearPickup;
        _isNearDropoffLocation = false;
        nearestBookingId = _isNearPickupLocation ? closest.booking.id : null;
        ongoingBookingId = null;
        // Auto-focus camera to include driver and next pickup if target changed
        final key = '${closest.booking.id}_pickup';
        if (key != _lastFocusedTargetKey) {
          final mapState = mapScreenKey.currentState;
          mapState?.fitToDriverAnd(closest.booking.pickupLocation);
          _lastFocusedTargetKey = key;
        }
      } else {
        _isNearPickupLocation = false;
        _isNearDropoffLocation = closest.isNearDropoff;
        nearestBookingId = null;
        ongoingBookingId = _isNearDropoffLocation ? closest.booking.id : null;
        // Auto-focus camera to include driver and next dropoff if target changed
        final key = '${closest.booking.id}_dropoff';
        if (key != _lastFocusedTargetKey) {
          final mapState = mapScreenKey.currentState;
          mapState?.fitToDriverAnd(closest.booking.dropoffLocation);
          _lastFocusedTargetKey = key;
        }
      }
    } else {
      selectedPassengerId = null;
      _isNearPickupLocation = false;
      _isNearDropoffLocation = false;
      nearestBookingId = null;
      ongoingBookingId = null;
      _lastFocusedTargetKey = null;
    }

    // Check for state changes and trigger one-time notifications\
    _checkAndTriggerNotifications();

    _updateMapMarkers();
    if (!_isDisposed) notifyListeners();
  }

  //--------------------------------------------------------------------------
  // Helpers
  //--------------------------------------------------------------------------
  void _resetState() {
    if (_isDisposed) return;
    _nearbyPassengers = [];
    selectedPassengerId = null;
    _isNearPickupLocation = false;
    nearestBookingId = null;
    _isNearDropoffLocation = false;
    ongoingBookingId = null;
    // Reset notification tracking when state is reset
    _previousIsNearPickupLocation = false;
    _previousIsNearDropoffLocation = false;
    _lastNotifiedPickupBookingId = null;
    _lastNotifiedDropoffBookingId = null;
    if (!_isDisposed) {
      notifyListeners();
      _updateMapMarkers(clearOnly: true);
    }
  }

  /// Checks for state transitions and triggers notifications only once
  /// when the driver first becomes near a pickup or dropoff location.
  void _checkAndTriggerNotifications() {
    debugPrint('========== Checking notifications ==========');
    debugPrint('  Nearby passengers: ${_nearbyPassengers.length}');
    debugPrint(
        '   PICKUP - isNear: $_isNearPickupLocation, previous: $_previousIsNearPickupLocation');
    debugPrint(
        '      bookingId: $nearestBookingId, lastNotified: $_lastNotifiedPickupBookingId');
    debugPrint(
        '   DROPOFF - isNear: $_isNearDropoffLocation, previous: $_previousIsNearDropoffLocation');
    debugPrint(
        '      bookingId: $ongoingBookingId, lastNotified: $_lastNotifiedDropoffBookingId');

    // Check pickup location proximity change
    checkPickupProximity();

    // Check dropoff location proximity change
    checkDropoffProximity();

    // Update previous state for next check
    _previousIsNearPickupLocation = _isNearPickupLocation;
    _previousIsNearDropoffLocation = _isNearDropoffLocation;
  }

  void checkDropoffProximity() {
    if (_isNearDropoffLocation && !_previousIsNearDropoffLocation) {
      // State changed from false to true - trigger notification
      if (ongoingBookingId != null &&
          ongoingBookingId != _lastNotifiedDropoffBookingId &&
          _nearbyPassengers.isNotEmpty) {
        // Find the passenger details for richer notification
        final passenger = _nearbyPassengers
            .where((p) => p.booking.id == ongoingBookingId)
            .firstOrNull;

        if (passenger != null) {
          final distanceText =
              passenger.distance < AppConfig.activeDropoffProximityThreshold
                  ? 'less than ${passenger.distance.toStringAsFixed(0)}m'
                  : '${passenger.distance.toStringAsFixed(0)}m';

          debugPrint(
              '[Notification]Showing notification for dropoff: $ongoingBookingId');
          NotificationService.instance.showBasicNotification(
            passenger.distance > AppConfig.activeDropoffApproachThreshold
                ? 'You\'re near the dropoff location!'
                : 'You\'re approaching the dropoff location!',
            'You\'re $distanceText away. You can drop off the passenger now.',
            bookingId: 'Dropoff: $ongoingBookingId',
          );
          _lastNotifiedDropoffBookingId = ongoingBookingId;
        }
      }
    } else if (!_isNearDropoffLocation && _previousIsNearDropoffLocation) {
      // State changed from true to false - reset tracking
      _lastNotifiedDropoffBookingId = null;
    }
  }

  void checkPickupProximity() {
    if (_isNearPickupLocation && !_previousIsNearPickupLocation) {
      // State changed from false to true - trigger notification
      if (nearestBookingId != null &&
          nearestBookingId != _lastNotifiedPickupBookingId &&
          _nearbyPassengers.isNotEmpty) {
        // Find the passenger details for notification
        final passenger = _nearbyPassengers
            .where((p) => p.booking.id == nearestBookingId)
            .firstOrNull;

        if (passenger != null) {
          final distanceText =
              passenger.distance < AppConfig.activePickupProximityThreshold
                  ? 'less than ${passenger.distance.toStringAsFixed(0)}m'
                  : '${passenger.distance.toStringAsFixed(0)}m';

          debugPrint(
              '[Notification] Showing notification for pickup: $nearestBookingId');
          NotificationService.instance.showBasicNotification(
            passenger.distance > AppConfig.activePickupApproachThreshold
                ? 'You\'re near the pickup location!'
                : 'You\'re approaching the pickup location!',
            'You\'re $distanceText away. You can confirm pickup now.',
            bookingId: 'Pickup: $nearestBookingId',
          );
          _lastNotifiedPickupBookingId = nearestBookingId;
        }
      }
    } else if (!_isNearPickupLocation && _previousIsNearPickupLocation) {
      // State changed from true to false - reset tracking
      _lastNotifiedPickupBookingId = null;
    }
  }

  void _updateMapMarkers({bool clearOnly = false}) {
    final mapState = mapScreenKey.currentState;
    if (mapState == null) return;

    // Clear existing passenger markers.
    mapState.clearPassengerMarkers();
    if (clearOnly) return;

    for (final passenger in _nearbyPassengers) {
      final isSelected = passenger.booking.id == selectedPassengerId;
      double zIndex = isSelected ? 5.0 : 3.0;
      if (passenger.booking.rideStatus == BookingConstants.statusAccepted) {
        // Show pickup and future drop-off markers.
        final pickupIcon = passenger.isNearPickup
            ? (MarkerIcons.pinGreen ??
                BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueGreen))
            : (MarkerIcons.pinOrange ??
                BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueAzure));
        mapState.addCustomMarker(
          id: 'pickup_${passenger.booking.id}',
          position: passenger.booking.pickupLocation,
          icon: pickupIcon,
          title: isSelected ? 'Selected Pickup' : 'Pickup',
          zIndex: zIndex,
        );
        mapState.addCustomMarker(
          id: 'dropoff_future_${passenger.booking.id}',
          position: passenger.booking.dropoffLocation,
          icon: MarkerIcons.pinOrange ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose),
          title: 'Future Dropoff',
          zIndex: 2.0,
          alpha: 0.7,
        );
      } else {
        // Ongoing – drop-off markers.
        final dropoffIcon = passenger.isNearDropoff
            ? (MarkerIcons.pinOrange ??
                BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueOrange))
            : (MarkerIcons.pinRed ??
                BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed));
        mapState.addCustomMarker(
          id: 'dropoff_${passenger.booking.id}',
          position: passenger.booking.dropoffLocation,
          icon: dropoffIcon,
          title: isSelected ? 'Selected Dropoff' : 'Dropoff',
          zIndex: zIndex,
        );
      }
    }
  }

  //--------------------------------------------------------------------------
  // Public API used by UI layer
  //--------------------------------------------------------------------------
  /// Handle selection from UI: updates internal selection state, toggles
  /// proximity flags, focuses the map on the appropriate location, and
  /// refreshes passenger markers.
  void handlePassengerSelected(String passengerId) {
    if (_isDisposed) return;
    selectedPassengerId = passengerId;

    final PassengerStatus? selected = _nearbyPassengers
        .where((p) => p.booking.id == passengerId)
        .cast<PassengerStatus?>()
        .firstOrNull;

    if (selected != null) {
      if (selected.booking.rideStatus == BookingConstants.statusAccepted) {
        _isNearPickupLocation = selected.isNearPickup;
        _isNearDropoffLocation = false;
        nearestBookingId = selected.booking.id;
        ongoingBookingId = null;

        // Focus map to include driver and pickup location
        final mapState = mapScreenKey.currentState;
        mapState?.fitToDriverAnd(selected.booking.pickupLocation);

        // Reflect pickup location into MapProvider
        mapProvider.setPickUpLocation(selected.booking.pickupLocation);
      } else {
        _isNearPickupLocation = false;
        _isNearDropoffLocation = selected.isNearDropoff;
        nearestBookingId = null;
        ongoingBookingId = selected.booking.id;

        // Focus map to include driver and dropoff location
        final mapState = mapScreenKey.currentState;
        mapState?.fitToDriverAnd(selected.booking.dropoffLocation);
      }
    }

    _updateMapMarkers();
    if (!_isDisposed) notifyListeners();
  }

  void selectPassenger(String passengerId) {
    if (_isDisposed) return;
    selectedPassengerId = passengerId;
    if (!_isDisposed) notifyListeners();
  }

  //--------------------------------------------------------------------------
  @override
  void dispose() {
    _isDisposed = true;
    _proximityCheckTimer?.cancel();
    _bookingFetchTimer?.cancel();
    _recalcDebounceTimer?.cancel();
    passengerProvider.removeListener(_onBookingsChanged);
    super.dispose();
  }
}

extension _HomeControllerReactivity on HomeController {
  void _onBookingsChanged() {
    // Debounce rapid successive updates
    _recalcDebounceTimer?.cancel();
    if (_isDisposed) return;
    _recalcDebounceTimer = Timer(const Duration(milliseconds: 60), () {
      if (_isDisposed) return;
      _checkProximity();
    });
  }
}
