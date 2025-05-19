import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pasada_driver_side/Database/auth_service.dart';
import 'package:pasada_driver_side/Database/passenger_capacity.dart';
import 'package:pasada_driver_side/Database/map_provider.dart';
import 'package:pasada_driver_side/UI/message.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async'; // Add this for StreamController and StreamSubscription
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'driver_provider.dart';
import 'dart:math';
import 'package:pasada_driver_side/Config/app_config.dart';

// ==================== PROVIDER ====================

/// Provider to manage passenger booking state
class PassengerProvider with ChangeNotifier {
  final BookingRepository _repository;

  // State
  int _passengerCapacity = 0;
  int _completedBooking = 0;
  List<Booking> _bookings = [];
  bool _isProcessingBookings = false;
  DateTime? _lastFetchTime;

  // Stream controller for real-time booking updates
  final _bookingsStreamController = StreamController<List<Booking>>.broadcast();
  StreamSubscription? _bookingsSubscription;
  String? _currentDriverId;

  // Getters
  int get passengerCapacity => _passengerCapacity;
  int get completedBooking => _completedBooking;
  List<Booking> get bookings => _bookings;
  List<String> get bookingIDs => _bookings.map((b) => b.id).toList();
  bool get isProcessingBookings => _isProcessingBookings;
  DateTime? get lastFetchTime => _lastFetchTime;
  Stream<List<Booking>> get bookingsStream => _bookingsStreamController.stream;

  // Constructor
  PassengerProvider({BookingRepository? repository})
      : _repository = repository ?? BookingRepository();

  @override
  void dispose() {
    _bookingsStreamController.close();
    _bookingsSubscription?.cancel();
    super.dispose();
  }

  /// Start listening to real-time booking updates for a driver
  void startBookingStream(String driverId) {
    // Cancel any existing subscription
    _bookingsSubscription?.cancel();

    // Store the current driver ID
    _currentDriverId = driverId;

    // Subscribe to the real-time booking updates
    _bookingsSubscription =
        _repository.activeBookingsStream(driverId).listen((updatedBookings) {
      _bookings = updatedBookings;
      _bookingsStreamController.add(updatedBookings);
      notifyListeners();

      if (kDebugMode) {
        debugPrint(
            'Received ${updatedBookings.length} bookings from real-time stream');
      }
    }, onError: (error) {
      if (kDebugMode) {
        debugPrint('Error in booking stream: $error');
      }
      // Attempt to restart the stream after delay
      Future.delayed(const Duration(seconds: 5), () {
        if (_currentDriverId != null) {
          startBookingStream(_currentDriverId!);
        }
      });
    });
  }

  /// Stop listening to real-time booking updates
  void stopBookingStream() {
    _bookingsSubscription?.cancel();
    _bookingsSubscription = null;
    _currentDriverId = null;
  }

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
    _bookingsStreamController.add(bookings);
    notifyListeners();
  }

  /// Method to get all booking details from the DB and update state
  Future<void> getBookingRequestsID(BuildContext context) async {
    // Prevent multiple simultaneous calls
    if (_isProcessingBookings) {
      if (kDebugMode) {
        debugPrint(
            'Booking processing already in progress, skipping duplicate call');
      }
      return;
    }

    // Verify context is still valid
    if (!context.mounted) {
      if (kDebugMode) {
        debugPrint('Context not mounted, skipping booking fetch');
      }
      return;
    }

    // Add debounce: don't fetch again if we fetched recently (within 5 seconds)
    final now = DateTime.now();
    if (_lastFetchTime != null) {
      final timeSinceLastFetch = now.difference(_lastFetchTime!).inSeconds;
      if (timeSinceLastFetch < AppConfig.fetchDebounceTime) {
        if (kDebugMode) {
          debugPrint(
              'Skipping fetch - last fetch was $timeSinceLastFetch seconds ago');
        }
        return;
      }
    }

    // Safely capture provider values before async operations
    String? driverStatus;
    String? driverId;
    LatLng? endingLocation;

    try {
      // Capture these before async operations to avoid disposed widget issues
      driverStatus = context.read<DriverProvider>().driverStatus;
      driverId = context.read<DriverProvider>().driverID;
      endingLocation = context.read<MapProvider>().endingLocation;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error reading provider values: $e');
      }
      return;
    }

    // Check if it's "Driving"
    if (driverStatus != 'Driving') {
      if (kDebugMode) {
        debugPrint('Driver status is $driverStatus - not fetching bookings');
      }
      return;
    }

    _isProcessingBookings = true;
    notifyListeners();

    try {
      if (kDebugMode) {
        debugPrint('Driver ID from provider: $driverId');
      }

      LatLng? currentLocation = await _getCurrentLocation(context);

      // Validate locations
      if (!context.mounted) {
        if (kDebugMode) {
          debugPrint('Error: Context no longer mounted, aborting operation');
        }
        _isProcessingBookings = false;
        notifyListeners();
        return;
      }

      // Clear booking data if there is no current location or ending location
      if (currentLocation == null || endingLocation == null) {
        _clearBookingData();
        if (kDebugMode) {
          debugPrint(
              'Error: Missing location data: currentLocation=$currentLocation, endingLocation=$endingLocation');
        }
        _isProcessingBookings = false;
        notifyListeners();
        return;
      }

      // Fetch all bookings from the DB
      final List<Booking> activeBookings =
          await _repository.fetchActiveBookings(driverId ?? '');

      // if there are no active bookings, clear the booking data
      if (activeBookings.isEmpty) {
        _clearBookingData();
        _isProcessingBookings = false;
        notifyListeners();
        return;
      }

      // Verify context is still mounted before processing
      if (!context.mounted) {
        if (kDebugMode) {
          debugPrint('Context no longer mounted before processing, aborting');
        }
        _isProcessingBookings = false;
        notifyListeners();
        return;
      }

      await _processBookings(
        context: context,
        activeBookings: activeBookings,
        driverLocation: currentLocation,
        endingLocation: endingLocation,
      );

      // Record fetch time for debouncing
      _lastFetchTime = now;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('Error fetching booking details: $e');
        debugPrint('Stack Trace: $stackTrace');
      }
      _clearBookingData();
    } finally {
      _isProcessingBookings = false;
      notifyListeners();
    }
  }

  /// Process bookings - separated for better readability and testability
  Future<void> _processBookings({
    required BuildContext context,
    required List<Booking> activeBookings,
    required LatLng driverLocation,
    required LatLng endingLocation,
  }) async {
    try {
      // Split requested and accepted/ongoing bookings
      final bookingsByStatus = _categorizeBookingsByStatus(activeBookings);
      final requestedBookings = bookingsByStatus['requested'] ?? [];
      final acceptedOngoingBookings = bookingsByStatus['acceptedOngoing'] ?? [];

      if (kDebugMode) {
        debugPrint(
            'BOOKINGS:Requested: ${requestedBookings.length}, Accepted/Ongoing: ${acceptedOngoingBookings.length}');
      }

      // Filter and validate requested bookings
      final validRequestedBookings = _validateRequestedBookings(
        requestedBookings: requestedBookings,
        driverLocation: driverLocation,
        endingLocation: endingLocation,
      );

      // Debug section: Logs validation results for all requested bookings
      if (kDebugMode) {
        _logValidationResults(validRequestedBookings, requestedBookings);
      }

      // Update booking statuses in the database
      await _updateBookingStatuses(requestedBookings, validRequestedBookings);

      // Refresh bookings after status updates to get newly accepted bookings
      final updatedActiveBookings = await _refreshActiveBookings(context);

      // Find and set nearest pickup location
      await _findAndSetNearestPickup(
          context, updatedActiveBookings, driverLocation);

      // Update state with all relevant bookings
      setBookings(updatedActiveBookings);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error processing bookings: $e');
      }
      rethrow;
    }
  }

  /// Categorize bookings by status into requested and accepted/ongoing
  Map<String, List<Booking>> _categorizeBookingsByStatus(
      List<Booking> bookings) {
    final requestedBookings = bookings
        .where((b) => b.rideStatus == BookingRepository.statusRequested)
        .toList();

    final acceptedOngoingBookings = bookings
        .where((b) =>
            b.rideStatus == BookingRepository.statusAccepted ||
            b.rideStatus == BookingRepository.statusOngoing)
        .toList();

    return {
      'requested': requestedBookings,
      'acceptedOngoing': acceptedOngoingBookings,
    };
  }

  /// Validate requested bookings to find ones that are ahead of the driver
  List<Booking> _validateRequestedBookings({
    required List<Booking> requestedBookings,
    required LatLng driverLocation,
    required LatLng endingLocation,
  }) {
    return BookingFilterService.filterValidRequestedBookings(
      bookings: requestedBookings,
      driverLocation: driverLocation,
      destinationLocation: endingLocation,
    );
  }

  /// Refresh the list of active bookings after status updates
  Future<List<Booking>> _refreshActiveBookings(BuildContext context) async {
    if (!context.mounted) return [];

    final driverId = context.read<DriverProvider>().driverID;
    return await _repository.fetchActiveBookings(driverId);
  }

  /// Update booking statuses in the database
  Future<void> _updateBookingStatuses(List<Booking> requestedBookings,
      List<Booking> validRequestedBookings) async {
    for (final booking in requestedBookings) {
      // Check if this is a valid booking (passenger ahead on route)
      final isValid =
          validRequestedBookings.any((valid) => valid.id == booking.id);

      try {
        if (isValid) {
          // If valid, set the booking request to 'accepted'
          await _repository.updateBookingStatus(
              booking.id, BookingRepository.statusAccepted);
        } else {
          // If not valid, set the booking request to 'cancelled'
          await _repository.updateBookingStatus(
              booking.id, BookingRepository.statusCancelled);
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Error updating booking ${booking.id} status: $e');
        }
        // Continue processing other bookings even if one fails
      }
    }
  }

  /// Find the nearest pickup location from accepted bookings and set it in MapProvider
  Future<void> _findAndSetNearestPickup(BuildContext context,
      List<Booking> activeBookings, LatLng driverLocation) async {
    if (!context.mounted) return;

    // Get only accepted/ongoing bookings
    final acceptedOngoingBookings = activeBookings
        .where((b) =>
            b.rideStatus == BookingRepository.statusAccepted ||
            b.rideStatus == BookingRepository.statusOngoing)
        .toList();

    if (acceptedOngoingBookings.isEmpty) {
      if (kDebugMode) {
        debugPrint('No accepted/ongoing bookings found');
      }
      return;
    }

    if (kDebugMode) {
      debugPrint(
          'After processing: Found ${acceptedOngoingBookings.length} accepted/ongoing bookings');
    }

    // Calculate distance to driver for all accepted bookings to find nearest
    final acceptedBookingsWithDistance = acceptedOngoingBookings.map((booking) {
      // Choose the right location to measure distance to based on booking status
      final targetLocation =
          booking.rideStatus == BookingRepository.statusAccepted
              ? booking.pickupLocation
              : booking.dropoffLocation;

      final distanceToDriver =
          LocationService.calculateDistance(driverLocation, targetLocation);

      return booking.copyWith(distanceToDriver: distanceToDriver);
    }).toList();

    // Find nearest booking by sorting by distance
    if (acceptedBookingsWithDistance.isNotEmpty) {
      // Sort by distance to driver
      acceptedBookingsWithDistance.sort((a, b) =>
          (a.distanceToDriver ?? double.infinity)
              .compareTo(b.distanceToDriver ?? double.infinity));

      final nearestBooking = acceptedBookingsWithDistance.first;

      // Determine if we should use pickup or dropoff location based on booking status
      final isAccepted =
          nearestBooking.rideStatus == BookingRepository.statusAccepted;
      final targetLocation = isAccepted
          ? nearestBooking.pickupLocation
          : nearestBooking.dropoffLocation;

      if (isAccepted) {
        // Set the nearest booking's pickup location in MapProvider
        if (kDebugMode) {
          debugPrint(
              'Setting pickup location in MapProvider for nearest ACCEPTED booking: $targetLocation');
        }

        if (context.mounted) {
          context.read<MapProvider>().setPickUpLocation(targetLocation);

          // Immediately verify if the pickup location was set correctly
          final verifiedPickupLocation =
              context.read<MapProvider>().pickupLocation;
          if (kDebugMode) {
            debugPrint(
                'Verified pickup location in MapProvider: $verifiedPickupLocation');
          }
        }
      } else {
        // For ongoing bookings, we might want to set the dropoff location instead
        if (kDebugMode) {
          debugPrint(
              'Booking is ONGOING - using dropoff location: $targetLocation');
        }

        // You could update the MapProvider with dropoff location if needed
      }

      if (kDebugMode) {
        debugPrint('Set nearest passenger: ID: ${nearestBooking.id}, '
            'Status: ${nearestBooking.rideStatus}, '
            'Distance: ${(nearestBooking.distanceToDriver ?? 0).toStringAsFixed(2)} meters');
      }
    } else {
      if (kDebugMode) {
        debugPrint('No bookings found to set as nearest location');
      }
    }
  }

  /// Fetch completed bookings count
  Future<void> getCompletedBookings(BuildContext context) async {
    try {
      final driverID = context.read<DriverProvider>().driverID;

      if (driverID.isEmpty || driverID == 'N/A') {
        if (kDebugMode) {
          debugPrint('Invalid driver ID: $driverID');
        }
        setCompletedBooking(0);
        return;
      }

      final count = await _repository.fetchCompletedBookingsCount(driverID);
      notifyListeners();
      setCompletedBooking(count);
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('Error fetching completed bookings: $e');
        debugPrint('Stack Trace: $stackTrace');
      }
      setCompletedBooking(0);
    }
  }

  /// Gets the current GPS location and updates the MapProvider
  Future<LatLng?> _getCurrentLocation(BuildContext context) async {
    LatLng? location;
    try {
      // Check if context is still valid
      if (!context.mounted) {
        if (kDebugMode) {
          debugPrint(
              'Context not mounted when getting location, returning null');
        }
        return null;
      }

      // Get current GPS position
      final Position position = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      location = LatLng(position.latitude, position.longitude);
      if (kDebugMode) {
        debugPrint(
            'Got GPS location: ${position.latitude}, ${position.longitude}');
      }

      // Also update the MapProvider for consistency, but check mounted again
      // since awaiting Geolocator could have taken time
      if (context.mounted) {
        context.read<MapProvider>().setCurrentLocation(location);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting GPS location: $e');
      }
      // Fall back to MapProvider location if GPS fails, but check mounted first
      if (context.mounted) {
        try {
          location = context.read<MapProvider>().currentLocation;
          if (kDebugMode) {
            debugPrint('Using fallback location from MapProvider: $location');
          }
        } catch (_) {
          // If even this fails, just return null
          return null;
        }
      }
    }
    return location;
  }

  /// Logs the validation results for all requested bookings
  void _logValidationResults(
      List<Booking> validRequestedBookings, List<Booking> requestedBookings) {
    debugPrint(
        'BOOKINGS: Found ${validRequestedBookings.length} valid bookings out of ${requestedBookings.length} requested');
    for (final booking in requestedBookings) {
      final isValid =
          validRequestedBookings.any((valid) => valid.id == booking.id);
      debugPrint(
          'Booking ID: ${booking.id} - ${isValid ? 'VALID' : 'INVALID'} - '
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
      if (kDebugMode) {
        debugPrint('========== TESTING BOOKING FILTERS ==========');
      }
      await getBookingRequestsID(context);
      if (kDebugMode) {
        debugPrint('========== TEST COMPLETED ==========');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Test error: $e');
      }
    }
  }

  /// Mark a booking as ongoing when driver is near pickup location
  Future<bool> markBookingAsOngoing(String bookingId) async {
    try {
      final success = await _repository.updateBookingStatus(
          bookingId, BookingRepository.statusOngoing);

      if (success) {
        // Update local state to reflect the change
        final updatedBookings = _bookings.map((booking) {
          if (booking.id == bookingId) {
            return booking.copyWith(
                rideStatus: BookingRepository.statusOngoing);
          }
          return booking;
        }).toList();

        setBookings(updatedBookings);
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error marking booking as ongoing: $e');
      }
      return false;
    }
  }

  /// Mark a booking as completed when passenger reaches destination
  Future<bool> markBookingAsCompleted(String bookingId) async {
    try {
      final success = await _repository.updateBookingStatus(
          bookingId, BookingRepository.statusCompleted);

      if (success) {
        // Remove the completed booking from local state
        final updatedBookings =
            _bookings.where((booking) => booking.id != bookingId).toList();

        setBookings(updatedBookings);

        // Increment completed bookings counter
        setCompletedBooking(_completedBooking + 1);

        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error marking booking as completed: $e');
      }
      return false;
    }
  }
}

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
  /// with auto-retry on failure
  Future<List<Booking>> fetchActiveBookings(String driverId) async {
    return _withRetry<List<Booking>>(
      () => _fetchActiveBookingsInternal(driverId),
      'fetchActiveBookings',
      maxRetries: 2,
    );
  }

  /// Internal implementation of fetchActiveBookings
  Future<List<Booking>> _fetchActiveBookingsInternal(String driverId) async {
    if (kDebugMode) {
      debugPrint('Fetching bookings for driver: $driverId');
    }

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
  }

  /// Fetches completed bookings count for a driver with auto-retry
  Future<int> fetchCompletedBookingsCount(String driverId) async {
    return _withRetry<int>(
      () => _fetchCompletedBookingsCountInternal(driverId),
      'fetchCompletedBookingsCount',
      maxRetries: 2,
    );
  }

  /// Internal implementation of fetchCompletedBookingsCount
  Future<int> _fetchCompletedBookingsCountInternal(String driverId) async {
    final response = await _supabase
        .from('bookings')
        .select('booking_id')
        .eq('driver_id', driverId)
        .eq('ride_status', statusCompleted);

    return response.length;
  }

  /// Updates the status of a booking in the database with auto-retry
  Future<bool> updateBookingStatus(String bookingId, String newStatus) async {
    return _withRetry<bool>(
      () => _updateBookingStatusInternal(bookingId, newStatus),
      'updateBookingStatus',
      maxRetries: 2,
    );
  }

  /// Internal implementation of updateBookingStatus
  Future<bool> _updateBookingStatusInternal(
      String bookingId, String newStatus) async {
    await _supabase
        .from('bookings')
        .update({'ride_status': newStatus}).eq('booking_id', bookingId);

    if (kDebugMode) {
      debugPrint('Updated booking $bookingId status to $newStatus');
    }
    return true;
  }

  /// Generic retry mechanism for repository methods
  Future<T> _withRetry<T>(Future<T> Function() operation, String operationName,
      {int maxRetries = 2,
      Duration delayBetweenRetries = const Duration(seconds: 1)}) async {
    int attempts = 0;

    while (true) {
      try {
        attempts++;
        return await operation();
      } catch (e, stackTrace) {
        if (attempts > maxRetries) {
          // If we've maxed out retries, rethrow the error
          if (kDebugMode) {
            debugPrint('Error in $operationName after $attempts attempts: $e');
            debugPrint('Stack trace: $stackTrace');
          }
          rethrow;
        }

        if (kDebugMode) {
          debugPrint(
              'Attempt $attempts failed for $operationName: $e. Retrying...');
        }

        // Wait before retrying
        await Future.delayed(delayBetweenRetries);
      }
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

  /// Calculate bearing (direction/heading in degrees) between two geographic points
  /// Returns a value between 0-360 degrees, where:
  /// - 0° = North
  /// - 90° = East
  /// - 180° = South
  /// - 270° = West
  static double calculateBearing(LatLng start, LatLng end) {
    // Convert latitude/longitude from degrees to radians
    // This is necessary because the math functions expect radians
    final startLat = start.latitude * (pi / 180); // Convert degrees to radians
    final startLng = start.longitude * (pi / 180);
    final endLat = end.latitude * (pi / 180);
    final endLng = end.longitude * (pi / 180);

    // Calculate the y component using the spherical law of cosines formula
    // This represents the east-west component of the bearing
    final y = sin(endLng - startLng) * cos(endLat);

    // Calculate the x component
    // This represents the north-south component of the bearing
    final x = cos(startLat) * sin(endLat) -
        sin(startLat) * cos(endLat) * cos(endLng - startLng);

    // Calculate the angle using arctangent of y/x (atan2 handles quadrant correctly)
    // and convert back from radians to degrees
    final bearing = atan2(y, x) * (180 / pi);

    // Normalize to 0-360 degrees (atan2 returns -180 to +180)
    return (bearing + 360) % 360;
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
        minRequiredDistance: AppConfig.minPassengerAheadDistance,
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
          'Found ${validBookings.length} valid bookings (passengers ahead by >${AppConfig.minPassengerAheadDistance} m)');
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
