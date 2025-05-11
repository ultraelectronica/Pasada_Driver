import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pasada_driver_side/Database/map_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import 'driver_provider.dart';

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

  /// Determines if a pickup location is ahead of the driver by the required distance
  static bool isPickupAheadOfDriver({
    required LatLng pickupLocation,
    required LatLng driverLocation,
    required LatLng destinationLocation,
    required double minRequiredDistance,
  }) {
    // Calculate distances to destination
    final driverDistanceToDestination =
        calculateDistance(driverLocation, destinationLocation);

    final pickupDistanceToDestination =
        calculateDistance(pickupLocation, destinationLocation);

    // Passenger is ahead if their distance to destination is less than driver's
    if (pickupDistanceToDestination < driverDistanceToDestination) {
      final double metersAhead =
          driverDistanceToDestination - pickupDistanceToDestination;
      return metersAhead > minRequiredDistance;
    }

    return false;
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

    for (final booking in requestedBookings) {
      // Check if passenger is ahead of driver by required distance
      if (LocationService.isPickupAheadOfDriver(
        pickupLocation: booking.pickupLocation,
        driverLocation: driverLocation,
        destinationLocation: destinationLocation,
        minRequiredDistance: minPassengerAheadDistance,
      )) {
        // Calculate distance to driver
        final distanceToDriver = LocationService.calculateDistance(
          driverLocation,
          booking.pickupLocation,
        );

        // Add to valid bookings with distance calculated
        validBookings.add(booking.copyWith(distanceToDriver: distanceToDriver));
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
  Future<void> getBookingRequestsID(BuildContext context) async {
    try {
      // Store the context in a local variable
      final currentContext = context;

      // Get driver ID and locations
      final driverID = currentContext.read<DriverProvider>().driverID;
      debugPrint('Driver ID from provider: $driverID');
      final LatLng? currentLocation =
          currentContext.read<MapProvider>().currentLocation;
      final LatLng? endingLocation =
          currentContext.read<MapProvider>().endingLocation;

      // Validate locations
      if (!currentContext.mounted) {
        debugPrint('Context no longer mounted, aborting operation');
        return;
      }

      // if there is no current location or ending location, clear the booking data
      if (currentLocation == null || endingLocation == null) {
        _clearBookingData();
        if (kDebugMode) {
          debugPrint(
              'Missing location data: currentLocation=$currentLocation, endingLocation=$endingLocation');
        }
        return;
      }

      // Fetch bookings
      final List<Booking> activeBookings =
          await _repository.fetchActiveBookings(driverID);

      // if there are no active bookings, clear the booking data
      if (activeBookings.isEmpty) {
        _clearBookingData();
        return;
      }

      // Categorize bookings by status
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
            'Requested: ${requestedBookings.length}, Accepted/Ongoing: ${acceptedOngoingBookings.length}');
      }

      // Filter valid requested bookings
      final validRequestedBookings =
          BookingFilterService.filterValidRequestedBookings(
        bookings: requestedBookings,
        driverLocation: currentLocation,
        destinationLocation: endingLocation,
      );

      // Find nearest booking and set pickup location
      if (validRequestedBookings.isNotEmpty) {
        final nearestBooking =
            BookingFilterService.findNearestBooking(validRequestedBookings);
        if (nearestBooking != null) {
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
      final allRelevantBookings = [
        ...validRequestedBookings,
        ...acceptedOngoingBookings
      ];
      setBookings(allRelevantBookings);
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
