import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pasada_driver_side/Database/map_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import 'driver_provider.dart';
import 'dart:math';

// ==================== MODELS ====================

/// Model representing a booking with all necessary details
class Booking {
  final String id;
  final String passengerId;
  final String rideStatus;
  final LatLng pickupLocation;
  final LatLng dropoffLocation;

  // Optional calculated fields
  final double? distanceToDriver;

  const Booking({
    required this.id,
    required this.passengerId,
    required this.rideStatus,
    required this.pickupLocation,
    required this.dropoffLocation,
    this.distanceToDriver,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      id: json['booking_id'].toString(),
      passengerId: json['passenger_id'].toString(),
      rideStatus: json['ride_status'] as String,
      pickupLocation: LatLng(
        (json['pickup_lat'] as num).toDouble(),
        (json['pickup_lng'] as num).toDouble(),
      ),
      dropoffLocation: LatLng(
        (json['dropoff_lat'] as num).toDouble(),
        (json['dropoff_lng'] as num).toDouble(),
      ),
    );
  }

  Booking copyWith({
    String? id,
    String? passengerId,
    String? rideStatus,
    LatLng? pickupLocation,
    LatLng? dropoffLocation,
    double? distanceToDriver,
  }) {
    return Booking(
      id: id ?? this.id,
      passengerId: passengerId ?? this.passengerId,
      rideStatus: rideStatus ?? this.rideStatus,
      pickupLocation: pickupLocation ?? this.pickupLocation,
      dropoffLocation: dropoffLocation ?? this.dropoffLocation,
      distanceToDriver: distanceToDriver ?? this.distanceToDriver,
    );
  }
}

// ==================== REPOSITORIES ====================

/// Repository to handle all database operations related to bookings
class BookingRepository {
  final SupabaseClient _supabase;

  // Status constants
  static const String statusRequested = 'requested';
  static const String statusAccepted = 'accepted';
  static const String statusOngoing = 'ongoing';
  static const String statusCompleted = 'completed';
  static const String statusCancelled = 'cancelled';

  BookingRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  /// Fetches all active bookings (requested, accepted, ongoing) for a driver
  Future<List<Booking>> fetchActiveBookings(String driverId) async {
    if (kDebugMode) {
      debugPrint('Fetching bookings for driver: $driverId');
    }

    try {
      final response = await _supabase
          .from('bookings')
          .select(
              'booking_id, passenger_id, ride_status, pickup_lat, pickup_lng, dropoff_lat, dropoff_lng')
          .eq('driver_id', driverId)
          .or('ride_status.eq.$statusRequested,ride_status.eq.$statusAccepted,ride_status.eq.$statusOngoing');

      if (kDebugMode) {
        debugPrint('Retrieved ${response.length} active bookings');
      }

      return List<Map<String, dynamic>>.from(response)
          .map((json) => Booking.fromJson(json))
          .toList();
    } catch (e, stackTrace) {
      debugPrint('Error fetching active bookings: $e');
      debugPrint('Stack trace: $stackTrace');
      return [];
    }
  }

  /// Fetches completed bookings count for a driver
  Future<int> fetchCompletedBookingsCount(String driverId) async {
    try {
      final response = await _supabase
          .from('bookings')
          .select('booking_id')
          .eq('driver_id', driverId)
          .eq('ride_status', statusCompleted);

      return response.length;
    } catch (e, stackTrace) {
      debugPrint('Error fetching completed bookings: $e');
      debugPrint('Stack trace: $stackTrace');
      return 0;
    }
  }

  /// Updates the status of a booking in the database
  Future<bool> updateBookingStatus(String bookingId, String newStatus) async {
    try {
      await _supabase
          .from('bookings')
          .update({'ride_status': newStatus}).eq('booking_id', bookingId);

      if (kDebugMode) {
        debugPrint('Updated booking $bookingId status to $newStatus');
      }
      return true;
    } catch (e, stackTrace) {
      debugPrint('Error updating booking status: $e');
      debugPrint('Stack trace: $stackTrace');
      return false;
    }
  }

  /// Stream of active bookings for a driver for real-time updates
  Stream<List<Booking>> activeBookingsStream(String driverId) {
    return _supabase
        .from('bookings')
        .stream(primaryKey: ['booking_id'])
        .eq('driver_id', driverId)
        .map((response) {
          // Filter the response here since we can't use .or() in stream queries
          final data = List<Map<String, dynamic>>.from(response);
          final filteredData = data.where((booking) {
            final status = booking['ride_status'] as String;
            return status == statusRequested ||
                status == statusAccepted ||
                status == statusOngoing;
          }).toList();

          return filteredData.map((json) => Booking.fromJson(json)).toList();
        });
  }
}

// ==================== SERVICES ====================

/// Service to handle all location-related calculations
class LocationService {
  /// Calculate distance between two LatLng points in meters
  static double calculateDistance(LatLng point1, LatLng point2) {
    return Geolocator.distanceBetween(
        point1.latitude, point1.longitude, point2.latitude, point2.longitude);
  }

  /// Calculate bearing between two points in degrees
  static double calculateBearing(LatLng start, LatLng end) {
    final startLat = start.latitude * (pi / 180);
    final startLng = start.longitude * (pi / 180);
    final endLat = end.latitude * (pi / 180);
    final endLng = end.longitude * (pi / 180);

    final y = sin(endLng - startLng) * cos(endLat);
    final x = cos(startLat) * sin(endLat) -
        sin(startLat) * cos(endLat) * cos(endLng - startLng);

    final bearing = atan2(y, x) * (180 / pi);
    return (bearing + 360) % 360; // Normalize to 0-360
  }

  /// Determines if a point is ahead of another point given a reference direction
  static bool isPointAhead(LatLng point, LatLng reference, double bearing) {
    // Calculate bearing from reference to the point
    final bearingToPoint = calculateBearing(reference, point);

    // Calculate angular difference (ensures shortest path, handles 359° vs 1° case)
    final diff = (((bearingToPoint - bearing + 180) % 360) - 180).abs();

    // If the point is within ±60° of the direction of travel, consider it "ahead"
    return diff <= 60;
  }

  /// Determines if a pickup location is ahead of the driver by the required distance
  static bool isPickupAheadOfDriver({
    required LatLng pickupLocation,
    required LatLng driverLocation,
    required LatLng destinationLocation,
    required double minRequiredDistance,
  }) {
    // Calculate direct distance between driver and pickup
    final driverToPickupDistance =
        calculateDistance(driverLocation, pickupLocation);

    // Calculate driver's bearing toward destination
    final driverBearing = calculateBearing(driverLocation, destinationLocation);

    // Check if pickup is ahead based on bearing
    final isAheadByBearing =
        isPointAhead(pickupLocation, driverLocation, driverBearing);

    // Calculate distances to destination
    final driverDistanceToDestination =
        calculateDistance(driverLocation, destinationLocation);
    final pickupDistanceToDestination =
        calculateDistance(pickupLocation, destinationLocation);

    // Traditional method (legacy approach) - useful as secondary check
    final metersAhead =
        driverDistanceToDestination - pickupDistanceToDestination;

    if (kDebugMode) {
      debugPrint('VALIDATION CHECK:');
      debugPrint(
          'Driver to destination: ${driverDistanceToDestination.toStringAsFixed(2)}m');
      debugPrint(
          'Pickup to destination: ${pickupDistanceToDestination.toStringAsFixed(2)}m');
      debugPrint(
          'Direct driver to pickup: ${driverToPickupDistance.toStringAsFixed(2)}m');
      debugPrint(
          'Driver bearing to destination: ${driverBearing.toStringAsFixed(2)}°');
      debugPrint('Is pickup ahead by bearing: $isAheadByBearing');
      debugPrint('Distance difference: ${metersAhead.toStringAsFixed(2)}m');
    }

    // PRIMARY CHECK: Is pickup ahead by bearing AND reasonably close?
    final isPrimaryValid = isAheadByBearing && driverToPickupDistance < 3000;

    // SECONDARY CHECK: Is pickup significantly ahead by distance?
    // This helps in straight-line cases and provides backwards compatibility
    final isSecondaryValid =
        metersAhead > minRequiredDistance && driverToPickupDistance < 5000;

    // Final decision combines both checks
    final isValid = isPrimaryValid || isSecondaryValid;

    if (kDebugMode) {
      debugPrint('Is ahead by bearing and close enough: $isPrimaryValid');
      debugPrint(
          'Is significantly ahead by distance: $isSecondaryValid (min: ${minRequiredDistance}m)');
      debugPrint('Final validation result: $isValid');
    }

    return isValid;
  }
}

/// Service to filter bookings based on various criteria
class BookingFilterService {
  static const double minPassengerAheadDistance = 20.0; // meters

  /// Filters requested bookings to find valid ones where passenger is ahead by required distance
  static List<Booking> filterValidRequestedBookings({
    required List<Booking> bookings,
    required LatLng driverLocation,
    required LatLng destinationLocation,
    String requiredStatus = 'requested',
  }) {
    // Get only bookings with requested status
    final requestedBookings = bookings
        .where((booking) => booking.rideStatus == requiredStatus)
        .toList();

    if (requestedBookings.isEmpty) return [];

    final List<Booking> validBookings = [];

    if (kDebugMode) {
      debugPrint(
          'Driver location: ${driverLocation.latitude}, ${driverLocation.longitude}');
      debugPrint(
          'Destination: ${destinationLocation.latitude}, ${destinationLocation.longitude}');
    }

    for (final booking in requestedBookings) {
      if (kDebugMode) {
        debugPrint('===== ANALYZING BOOKING ${booking.id} =====');
        debugPrint(
            'Pickup: ${booking.pickupLocation.latitude}, ${booking.pickupLocation.longitude}');
        debugPrint(
            'Dropoff: ${booking.dropoffLocation.latitude}, ${booking.dropoffLocation.longitude}');
      }

      // Check if passenger is ahead of driver by required distance
      bool isValid = LocationService.isPickupAheadOfDriver(
        pickupLocation: booking.pickupLocation,
        driverLocation: driverLocation,
        destinationLocation: destinationLocation,
        minRequiredDistance: minPassengerAheadDistance,
      );

      if (isValid) {
        // Calculate distance to driver
        final distanceToDriver = LocationService.calculateDistance(
          driverLocation,
          booking.pickupLocation,
        );

        if (kDebugMode) {
          debugPrint(
              'Booking ${booking.id} is VALID - Distance to driver: ${distanceToDriver.toStringAsFixed(2)}m');
        }

        // Add to valid bookings with distance calculated
        validBookings.add(booking.copyWith(distanceToDriver: distanceToDriver));
      } else {
        if (kDebugMode) {
          debugPrint(
              'Booking ${booking.id} is INVALID - Failed validation checks');
        }
      }
    }

    if (kDebugMode) {
      debugPrint(
          'Found ${validBookings.length} valid bookings (passengers ahead by >$minPassengerAheadDistance m)');
    }

    return validBookings;
  }

  /// Find the nearest booking from a list of bookings based on distance to driver
  static Booking? findNearestBooking(List<Booking> bookings) {
    if (bookings.isEmpty) return null;

    // Sort by distance to driver (ascending)
    final sortedBookings = List<Booking>.from(bookings);
    sortedBookings.sort((a, b) {
      final aDistance = a.distanceToDriver ?? double.infinity;
      final bDistance = b.distanceToDriver ?? double.infinity;
      return aDistance.compareTo(bDistance);
    });

    return sortedBookings.first;
  }
}

// ==================== PROVIDER ====================

/// Provider to manage passenger booking state
class PassengerProvider with ChangeNotifier {
  final BookingRepository _repository;

  // State
  int _passengerCapacity = 0;
  int _completedBooking = 0;
  List<Booking> _bookings = [];

  // Getters
  int get passengerCapacity => _passengerCapacity;
  int get completedBooking => _completedBooking;
  List<Booking> get bookings => _bookings;
  List<String> get bookingIDs => _bookings.map((b) => b.id).toList();

  // Constructor
  PassengerProvider({BookingRepository? repository})
      : _repository = repository ?? BookingRepository();

  // Setters
  void setPassengerCapacity(int value) {
    _passengerCapacity = value;
    notifyListeners();
  }

  void setCompletedBooking(int value) {
    _completedBooking = value;
    notifyListeners();
  }

  void setBookings(List<Booking> bookings) {
    _bookings = bookings;
    notifyListeners();
  }

  /// Method to get all booking details from the DB and update state
  /// TODO: fetch all bookings from the DB == DONE
  /// TODO: filter the bookings based on the status == DONE
  ///
  /// VALIDATION CHECKS:
  /// TODO: check if the requested bookings are valid == DONE
  /// TODO: if valid, set the booking request to 'accepted' == DONE
  /// TODO: if not valid, set the booking request to 'cancelled' == DONE
  ///
  /// NEAREST BOOKING:
  /// TODO: once the booking request is accepted, get the nearest booking from the filtered bookings
  /// TODO: set the nearest booking as the pickup location
  /// TODO: update the state with the all relevant bookings
  ///
  /// DRIVER LOCATION CHECK:
  /// TODO: once the booking request is accepted, check the location of the driver and pick up location
  /// TODO: if the driver is closer to the pick up location, set the booking status to 'ongoing'
  /// TODO: if the driver is not closer to the pick up location, do nothing
  Future<void> getBookingRequestsID(BuildContext context) async {
    try {
      // Store the context in a local variable
      final currentContext = context;

      // Get driver ID and locations
      final driverID = currentContext.read<DriverProvider>().driverID;
      debugPrint('Driver ID from provider: $driverID');

      LatLng? currentLocation = await _getCurrentLocation(currentContext);

      // Get the ending location from the MapProvider
      final LatLng? endingLocation =
          currentContext.read<MapProvider>().endingLocation;

      // Validate locations
      if (!currentContext.mounted) {
        debugPrint('Error: Context no longer mounted, aborting operation');
        return;
      }

      // Clear booking data if there is no current location or ending location
      if (currentLocation == null || endingLocation == null) {
        _clearBookingData();
        if (kDebugMode) {
          debugPrint(
              'Error: Missing location data: currentLocation=$currentLocation, endingLocation=$endingLocation');
        }
        return;
      }

      // Fetch all bookings from the DB
      final List<Booking> activeBookings =
          await _repository.fetchActiveBookings(driverID);

      // if there are no active bookings, clear the booking data
      if (activeBookings.isEmpty) {
        _clearBookingData();
        return;
      }

      // Filter the bookings based on the status
      final requestedBookings = activeBookings
          .where((b) => b.rideStatus == BookingRepository.statusRequested)
          .toList();
      final acceptedOngoingBookings = activeBookings
          .where((b) =>
              b.rideStatus == BookingRepository.statusAccepted ||
              b.rideStatus == BookingRepository.statusOngoing)
          .toList();

      if (kDebugMode) {
        debugPrint(
            'BOOKINGS:Requested: ${requestedBookings.length}, Accepted/Ongoing: ${acceptedOngoingBookings.length}');
      }

      // BOOKING VALIDATION CHECK:Check if the requested bookings are valid
      final validRequestedBookings =
          BookingFilterService.filterValidRequestedBookings(
        bookings: requestedBookings,
        driverLocation: currentLocation,
        destinationLocation: endingLocation,
      );

      // Debug section: Logs validation results for all requested bookings
      if (kDebugMode) {
        _logValidationResults(validRequestedBookings, requestedBookings);
      }

      // PROCESS BOOKINGS: Process requested bookings - update status based on validity
      for (final booking in requestedBookings) {
        // Check if this is a valid booking (passenger ahead on route)
        final isValid =
            validRequestedBookings.any((valid) => valid.id == booking.id);

        if (isValid) {
          // If valid, set the booking request to 'accepted'
          await _repository.updateBookingStatus(
              booking.id, BookingRepository.statusAccepted);
        } else {
          // If not valid, set the booking request to 'cancelled'
          await _repository.updateBookingStatus(
              booking.id, BookingRepository.statusCancelled);
        }
      }

      // Get the nearest booking from the filtered bookings
      if (validRequestedBookings.isNotEmpty) {
        final nearestBooking =
            BookingFilterService.findNearestBooking(validRequestedBookings);
        if (nearestBooking != null) {
          // Set the nearest booking as the pickup location
          currentContext
              .read<MapProvider>()
              .setPickUpLocation(nearestBooking.pickupLocation);

          if (kDebugMode) {
            debugPrint('Set nearest passenger: ID: ${nearestBooking.id}, ' +
                'Distance: ${(nearestBooking.distanceToDriver ?? 0).toStringAsFixed(2)} meters');
          }
        }
      }

      // Update state with all relevant bookings
      // This includes newly accepted bookings and ongoing ones
      // Refresh bookings after status updates
      final updatedActiveBookings =
          await _repository.fetchActiveBookings(driverID);
      setBookings(updatedActiveBookings);
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('Error fetching booking details: $e');
        print('Stack Trace: $stackTrace');
      }
      _clearBookingData();
    }
  }

  /// Fetch completed bookings count
  Future<void> getCompletedBookings(BuildContext context) async {
    try {
      final driverID = context.read<DriverProvider>().driverID;

      if (driverID.isEmpty || driverID == 'N/A') {
        debugPrint('Invalid driver ID: $driverID');
        setCompletedBooking(0);
        return;
      }

      final count = await _repository.fetchCompletedBookingsCount(driverID);
      notifyListeners();
      setCompletedBooking(count);
    } catch (e, stackTrace) {
      debugPrint('Error fetching completed bookings: $e');
      debugPrint('Stack Trace: $stackTrace');
      setCompletedBooking(0);
    }
  }

  /// Gets the current GPS location and updates the MapProvider
  Future<LatLng?> _getCurrentLocation(BuildContext context) async {
    LatLng? location;
    try {
      // Get current GPS position
      final Position position = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      location = LatLng(position.latitude, position.longitude);
      debugPrint(
          'Got GPS location: ${position.latitude}, ${position.longitude}');

      // Also update the MapProvider for consistency
      if (context.mounted) {
        context.read<MapProvider>().setCurrentLocation(location);
      }
    } catch (e) {
      debugPrint('Error getting GPS location: $e');
      // Fall back to MapProvider location if GPS fails
      location = context.read<MapProvider>().currentLocation;
      debugPrint('Using fallback location from MapProvider: $location');
    }
    return location;
  }

  /// Logs the validation results for all requested bookings
  void _logValidationResults(List<Booking> validRequestedBookings, List<Booking> requestedBookings) {
    debugPrint('BOOKINGS: Found ${validRequestedBookings.length} valid bookings out of ${requestedBookings.length} requested');
    for (final booking in requestedBookings) {
      final isValid = validRequestedBookings.any((valid) => valid.id == booking.id);
      debugPrint('Booking ID: ${booking.id} - ${isValid ? 'VALID' : 'INVALID'} - ' +
          'pickup at: ${booking.pickupLocation.latitude}, ${booking.pickupLocation.longitude}');
    }
  }

  /// Clears all booking data
  void _clearBookingData() {
    setBookings([]);
    if (kDebugMode) {
      debugPrint('No valid or active bookings to store');
    }
  }

  /// Test method to verify the booking filter logic
  Future<void> testBookingFilters(BuildContext context) async {
    try {
      debugPrint('========== TESTING BOOKING FILTERS ==========');
      await getBookingRequestsID(context);
      debugPrint('========== TEST COMPLETED ==========');
    } catch (e) {
      debugPrint('Test error: $e');
    }
  }
}
