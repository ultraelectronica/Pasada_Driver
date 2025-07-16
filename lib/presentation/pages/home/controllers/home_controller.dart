import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:pasada_driver_side/common/config/app_config.dart';
import 'package:pasada_driver_side/presentation/pages/home/models/passenger_status.dart';
import 'package:pasada_driver_side/common/constants/booking_constants.dart';
import 'package:pasada_driver_side/presentation/pages/home/utils/home_constants.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pasada_driver_side/presentation/providers/driver/driver_provider.dart';
import 'package:pasada_driver_side/presentation/providers/map_provider.dart';
import 'package:pasada_driver_side/presentation/providers/passenger/passenger_provider.dart';
import 'package:pasada_driver_side/Map/google_map.dart';
import 'package:flutter/material.dart';

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
  final GlobalKey<MapScreenState> mapScreenKey;

  //--------------------------------------------------------------------------
  // Public reactive fields (read-only outside)
  //--------------------------------------------------------------------------
  List<PassengerStatus> get nearbyPassengers =>
      List.unmodifiable(_nearbyPassengers);
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
  DateTime? _lastProximityNotificationTime;
  Timer? _proximityCheckTimer;
  Timer? _bookingFetchTimer;
  bool _bookingStreamStarted = false;

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
  }

  //--------------------------------------------------------------------------
  // Booking fetch
  //--------------------------------------------------------------------------
  Future<void> fetchBookings() async {
    if (_isLoadingBookings) return;
    _isLoadingBookings = true;
    notifyListeners();

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
      notifyListeners();
    }
  }

  //--------------------------------------------------------------------------
  // Proximity logic
  //--------------------------------------------------------------------------
  void _checkProximity() {
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

      if (booking.rideStatus == BookingConstants.statusAccepted) {
        distance = Geolocator.distanceBetween(
          currentLocation.latitude,
          currentLocation.longitude,
          booking.pickupLocation.latitude,
          booking.pickupLocation.longitude,
        );
        isNearPickup = distance < AppConfig.activePickupProximityThreshold;
        isApproachingPickup =
            distance >= AppConfig.activePickupProximityThreshold &&
                distance < AppConfig.activePickupApproachThreshold;
      } else {
        // Ongoing – measure to drop-off.
        distance = Geolocator.distanceBetween(
          currentLocation.latitude,
          currentLocation.longitude,
          booking.dropoffLocation.latitude,
          booking.dropoffLocation.longitude,
        );
        isNearDropoff = distance < AppConfig.activeDropoffProximityThreshold;
        isApproachingDropoff =
            distance >= AppConfig.activeDropoffProximityThreshold &&
                distance < AppConfig.activeDropoffApproachThreshold;
      }

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
      } else {
        _isNearPickupLocation = false;
        _isNearDropoffLocation = closest.isNearDropoff;
        nearestBookingId = null;
        ongoingBookingId = _isNearDropoffLocation ? closest.booking.id : null;
      }
    } else {
      selectedPassengerId = null;
      _isNearPickupLocation = false;
      _isNearDropoffLocation = false;
      nearestBookingId = null;
      ongoingBookingId = null;
    }

    _updateMapMarkers();
    notifyListeners();
  }

  //--------------------------------------------------------------------------
  // Helpers
  //--------------------------------------------------------------------------
  void _resetState() {
    _nearbyPassengers = [];
    selectedPassengerId = null;
    _isNearPickupLocation = false;
    nearestBookingId = null;
    _isNearDropoffLocation = false;
    ongoingBookingId = null;
    notifyListeners();
    _updateMapMarkers(clearOnly: true);
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
            ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen)
            : BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
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
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose),
          title: 'Future Dropoff',
          zIndex: 2.0,
          alpha: 0.7,
        );
      } else {
        // Ongoing – drop-off markers.
        final dropoffIcon = passenger.isNearDropoff
            ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange)
            : BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
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
  void selectPassenger(String passengerId) {
    selectedPassengerId = passengerId;
    notifyListeners();
  }

  //--------------------------------------------------------------------------
  @override
  void dispose() {
    _proximityCheckTimer?.cancel();
    _bookingFetchTimer?.cancel();
    super.dispose();
  }
}
