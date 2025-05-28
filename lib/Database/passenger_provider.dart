import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pasada_driver_side/Database/map_provider.dart';
import 'dart:async'; // Add this for StreamController and StreamSubscription
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'driver_provider.dart';
import 'package:pasada_driver_side/Config/app_config.dart';

// Import newly created files
import 'booking_logger.dart';
import 'booking_model.dart';
import 'booking_repository.dart';
import 'booking_exception.dart';
import 'location_service.dart';
import 'booking_filter_service.dart';
import 'booking_constants.dart';

/// Provider to manage passenger booking state
class PassengerProvider with ChangeNotifier {
  final BookingRepository _repository;

  // State
  int _passengerCapacity = 0;
  int _completedBooking = 0;
  List<Booking> _bookings = [];
  bool _isProcessingBookings = false;
  DateTime? _lastFetchTime;
  String? _error;
  String? _errorType;

  // Stream controller for real-time booking updates
  final _bookingsStreamController = StreamController<List<Booking>>.broadcast();
  StreamSubscription? _bookingsSubscription;
  String? _currentDriverId;
  Timer? _streamReconnectTimer;

  // Flag for dispose state
  bool _isDisposed = false;

  // Getters
  int get passengerCapacity => _passengerCapacity;
  int get completedBooking => _completedBooking;
  List<Booking> get bookings =>
      List.unmodifiable(_bookings); // Return immutable copy
  List<String> get bookingIDs => _bookings.map((b) => b.id).toList();
  bool get isProcessingBookings => _isProcessingBookings;
  DateTime? get lastFetchTime => _lastFetchTime;
  Stream<List<Booking>> get bookingsStream => _bookingsStreamController.stream;
  String? get error => _error;
  String? get errorType => _errorType;

  // Constructor
  PassengerProvider({BookingRepository? repository})
      : _repository = repository ?? BookingRepository() {
    // Initialize the logger
    BookingLogger.init();
  }

  @override
  void dispose() {
    BookingLogger.log('PassengerProvider disposed', type: 'LIFECYCLE');
    _isDisposed = true;
    _cleanupResources();
    super.dispose();
  }

  /// Clean up all resources to prevent memory leaks
  void _cleanupResources() {
    _streamReconnectTimer?.cancel();
    _streamReconnectTimer = null;

    _bookingsSubscription?.cancel();
    _bookingsSubscription = null;

    _bookingsStreamController.close();
  }

  /// Start listening to real-time booking updates for a driver
  void startBookingStream(String driverId) {
    // Cleanup any existing resources first
    _bookingsSubscription?.cancel();
    _streamReconnectTimer?.cancel();

    if (_isDisposed) return;

    // Store the current driver ID
    _currentDriverId = driverId;

    BookingLogger.log('Starting booking stream for driver: $driverId',
        type: 'STREAM');

    try {
      // Subscribe to the real-time booking updates
      _bookingsSubscription =
          _repository.activeBookingsStream(driverId).listen((updatedBookings) {
        if (_isDisposed) return;

        _bookings = updatedBookings;
        _error = null;
        _errorType = null;

        // Only push to stream if controller is still open
        if (!_bookingsStreamController.isClosed) {
          _bookingsStreamController.add(updatedBookings);
        }

        notifyListeners();

        if (kDebugMode) {
          debugPrint(
              'Received ${updatedBookings.length} bookings from real-time stream');
        }

        BookingLogger.log(
            'Updated ${updatedBookings.length} bookings from stream',
            type: 'STREAM');
      }, onError: (error) {
        if (_isDisposed) return;

        // Store error details
        if (error is BookingException) {
          _error = error.message;
          _errorType = error.type;
        } else {
          _error = error.toString();
          _errorType = BookingConstants.errorTypeUnknown;
        }

        if (kDebugMode) {
          debugPrint('Error in booking stream: $error');
        }

        notifyListeners();

        BookingLogger.log('Error in booking stream: $error', type: 'ERROR');

        // Attempt to restart the stream after delay
        _streamReconnectTimer?.cancel();
        _streamReconnectTimer = Timer(const Duration(seconds: 5), () {
          if (_currentDriverId != null && !_isDisposed) {
            startBookingStream(_currentDriverId!);
          }
        });
      }, cancelOnError: false);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error starting booking stream: $e');
      }

      // Store error and notify listeners
      _error = e.toString();
      _errorType = BookingConstants.errorTypeUnknown;
      notifyListeners();

      BookingLogger.log('Failed to start booking stream: $e', type: 'ERROR');

      // Schedule reconnect
      _streamReconnectTimer = Timer(const Duration(seconds: 5), () {
        if (_currentDriverId != null && !_isDisposed) {
          startBookingStream(_currentDriverId!);
        }
      });
    }
  }

  /// Stop listening to real-time booking updates
  void stopBookingStream() {
    _streamReconnectTimer?.cancel();
    _streamReconnectTimer = null;

    _bookingsSubscription?.cancel();
    _bookingsSubscription = null;

    _currentDriverId = null;
  }

  // Setters with safety checks
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

  void setBookings(List<Booking> bookings) {
    if (_isDisposed) return;
    _bookings = bookings;

    // Only push to stream if controller is still open
    if (!_bookingsStreamController.isClosed) {
      _bookingsStreamController.add(bookings);
    }

    notifyListeners();
  }

  /// Clear error state
  void clearError() {
    if (_isDisposed) return;
    _error = null;
    _errorType = null;
    notifyListeners();
  }

  /// Method to get all booking details from the DB and update state
  Future<void> getBookingRequestsID(BuildContext? providedContext) async {
    // Use context safely
    final bool hasValidContext =
        providedContext != null && providedContext.mounted;

    // Use a lock to prevent concurrent fetching
    bool shouldContinue = false;
    DateTime now = DateTime.now();

    // Critical section with lock
    if (_isProcessingBookings) {
      if (kDebugMode) {
        debugPrint(
            'Booking processing already in progress, skipping duplicate call');
      }
      return;
    }

    // Add debounce: don't fetch again if we fetched recently
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

    _isProcessingBookings = true;
    shouldContinue = true;

    if (!shouldContinue || _isDisposed) {
      return;
    }

    // Notify UI that we're processing
    notifyListeners();

    try {
      // Safely capture provider values or use stored values
      String? driverStatus;
      String? driverId = _currentDriverId;
      LatLng? endingLocation;

      if (hasValidContext) {
        try {
          // Capture these before async operations to avoid disposed widget issues
          driverStatus = providedContext.read<DriverProvider>().driverStatus;
          driverId = providedContext.read<DriverProvider>().driverID;
          endingLocation = providedContext.read<MapProvider>().endingLocation;
        } catch (e) {
          if (kDebugMode) {
            debugPrint('Error reading provider values: $e');
          }
          // We'll continue with the stored values if available
        }
      }

      // If driver is not in Driving mode OR we don't have a driver ID, abort
      if (driverStatus != 'Driving' || driverId == null || driverId.isEmpty) {
        if (kDebugMode) {
          debugPrint(
              'No active driver or not in driving mode, skipping booking fetch');
        }
        _isProcessingBookings = false;
        notifyListeners();
        return;
      }

      if (kDebugMode) {
        debugPrint('Getting bookings for driver ID: $driverId');
      }

      // Get current location - try with context first, then fall back to direct Geolocator
      LatLng? currentLocation;
      if (hasValidContext) {
        currentLocation = await _getCurrentLocation(providedContext);
      }

      // If we couldn't get location with context, try direct geolocation
      if (currentLocation == null) {
        try {
          final position = await Geolocator.getCurrentPosition(
            locationSettings:
                const LocationSettings(accuracy: LocationAccuracy.high),
          ).timeout(Duration(seconds: AppConfig.locationFetchTimeout),
              onTimeout: () {
            throw TimeoutException('Location fetch timed out');
          });
          currentLocation = LatLng(position.latitude, position.longitude);
          if (kDebugMode) {
            debugPrint(
                'Got direct GPS location: ${position.latitude}, ${position.longitude}');
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('Failed to get direct GPS location: $e');
          }
          // Store error for UI feedback
          _error =
              'Failed to get location: ${e is TimeoutException ? 'Timed out' : e}';
          _errorType = e is TimeoutException
              ? BookingConstants.errorTypeTimeout
              : BookingConstants.errorTypeUnknown;
        }
      }

      // Clear booking data if there is no current location or ending location
      if (currentLocation == null) {
        _clearBookingData();
        if (kDebugMode) {
          debugPrint('Error: Missing location data, cannot fetch bookings');
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

      // Process the bookings without requiring context
      final processedBookings = await _processBookingsWithoutContext(
        activeBookings: activeBookings,
        driverLocation: currentLocation,
        endingLocation:
            endingLocation ?? currentLocation, // Fall back to current location
        driverId: driverId ?? '',
      );

      // Check if provider is still active before updating state
      if (_isDisposed) return;

      // Update state with processed bookings
      if (processedBookings.isNotEmpty) {
        setBookings(processedBookings);
      } else {
        _clearBookingData();
      }

      // Record fetch time for debouncing
      _lastFetchTime = now;
      _error = null;
      _errorType = null;
    } catch (e) {
      if (_isDisposed) return;

      if (kDebugMode) {
        debugPrint('Error fetching booking details: $e');
      }

      // Store error for UI feedback
      if (e is BookingException) {
        _error = e.message;
        _errorType = e.type;
      } else {
        _error = e.toString();
        _errorType = BookingConstants.errorTypeUnknown;
      }

      _clearBookingData();
    } finally {
      // Always reset processing flag and notify if not disposed
      if (!_isDisposed) {
        _isProcessingBookings = false;
        notifyListeners();
      }
    }
  }

  /// Process bookings without requiring context
  Future<List<Booking>> _processBookingsWithoutContext({
    required List<Booking> activeBookings,
    required LatLng driverLocation,
    required LatLng endingLocation,
    required String driverId,
  }) async {
    try {
      // Split requested and accepted/ongoing bookings
      final bookingsByStatus = _categorizeBookingsByStatus(activeBookings);
      final requestedBookings = bookingsByStatus['requested'] ?? [];
      final acceptedOngoingBookings = bookingsByStatus['acceptedOngoing'] ?? [];

      if (kDebugMode) {
        debugPrint(
            'BOOKINGS: Requested: ${requestedBookings.length}, Accepted/Ongoing: ${acceptedOngoingBookings.length}');
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

      // Update booking statuses in the database - use transaction if more than one
      if (requestedBookings.isNotEmpty) {
        await _updateBookingStatuses(requestedBookings, validRequestedBookings);
      }

      // Refresh bookings after status updates to get newly accepted bookings
      final updatedActiveBookings =
          await _repository.fetchActiveBookings(driverId);

      // Log all active bookings with their statuses for debugging
      _logBookingDetails("Active bookings after update", updatedActiveBookings);

      // Calculate distances and separate by status
      final List<Booking> pickupBookings =
          []; // Accepted bookings awaiting pickup
      final List<Booking> dropoffBookings =
          []; // Ongoing bookings awaiting dropoff

      for (final booking in updatedActiveBookings) {
        double distanceToDriver;

        if (booking.rideStatus == BookingConstants.statusAccepted) {
          // For accepted bookings, calculate distance to pickup
          distanceToDriver = LocationService.calculateDistance(
              driverLocation, booking.pickupLocation);
          pickupBookings
              .add(booking.copyWith(distanceToDriver: distanceToDriver));

          if (kDebugMode) {
            debugPrint(
                'PICKUP booking ${booking.id}: Distance to pickup = ${distanceToDriver.toStringAsFixed(2)}m');
          }
        } else if (booking.rideStatus == BookingConstants.statusOngoing) {
          // For ongoing bookings, calculate distance to dropoff
          distanceToDriver = LocationService.calculateDistance(
              driverLocation, booking.dropoffLocation);
          dropoffBookings
              .add(booking.copyWith(distanceToDriver: distanceToDriver));

          if (kDebugMode) {
            debugPrint(
                'DROPOFF booking ${booking.id}: Distance to dropoff = ${distanceToDriver.toStringAsFixed(2)}m');
          }
        }
      }

      // Sort each category by distance
      pickupBookings.sort((a, b) => (a.distanceToDriver ?? double.infinity)
          .compareTo(b.distanceToDriver ?? double.infinity));

      dropoffBookings.sort((a, b) => (a.distanceToDriver ?? double.infinity)
          .compareTo(b.distanceToDriver ?? double.infinity));

      // Combine lists with pickups first, then dropoffs (priority sorting)
      final prioritizedBookings = [...pickupBookings, ...dropoffBookings];

      // Log the final prioritized list
      _logBookingPriority("Final prioritized bookings", prioritizedBookings);

      return prioritizedBookings;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error processing bookings without context: $e');
      }
      // Propagate the exception for proper handling by caller
      rethrow;
    }
  }

  /// Log detailed booking information for debugging
  void _logBookingDetails(String title, List<Booking> bookings) {
    if (!kDebugMode) return;

    debugPrint('=== $title (${bookings.length} bookings) ===');
    for (final booking in bookings) {
      debugPrint('Booking ID: ${booking.id}');
      debugPrint('  Status: ${booking.rideStatus}');
      debugPrint(
          '  Pickup: (${booking.pickupLocation.latitude}, ${booking.pickupLocation.longitude})');
      debugPrint(
          '  Dropoff: (${booking.dropoffLocation.latitude}, ${booking.dropoffLocation.longitude})');
      debugPrint('  ---');
    }
  }

  /// Log the priority order of bookings
  void _logBookingPriority(String title, List<Booking> prioritizedBookings) {
    if (!kDebugMode) return;

    debugPrint('=== $title ===');
    for (int i = 0; i < prioritizedBookings.length; i++) {
      final booking = prioritizedBookings[i];
      final distance =
          booking.distanceToDriver?.toStringAsFixed(2) ?? 'unknown';
      final action = booking.rideStatus == BookingConstants.statusAccepted
          ? 'PICKUP'
          : 'DROPOFF';

      debugPrint(
          'Priority #${i + 1}: $action booking ${booking.id} - Distance: ${distance}m');
    }
  }

  /// Categorize bookings by status into requested and accepted/ongoing
  Map<String, List<Booking>> _categorizeBookingsByStatus(
      List<Booking> bookings) {
    final requestedBookings = bookings
        .where((b) => b.rideStatus == BookingConstants.statusRequested)
        .toList();

    final acceptedOngoingBookings = bookings
        .where((b) =>
            b.rideStatus == BookingConstants.statusAccepted ||
            b.rideStatus == BookingConstants.statusOngoing)
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

  /// Update booking statuses in the database
  Future<void> _updateBookingStatuses(List<Booking> requestedBookings,
      List<Booking> validRequestedBookings) async {
    List<Future<void>> updates = [];

    for (final booking in requestedBookings) {
      // Check if this is a valid booking (passenger ahead on route)
      final isValid =
          validRequestedBookings.any((valid) => valid.id == booking.id);

      try {
        final updateFuture = _repository.updateBookingStatus(
            booking.id,
            isValid
                ? BookingConstants.statusAccepted
                : BookingConstants.statusCancelled);

        updates.add(updateFuture.then((_) {
          if (kDebugMode) {
            debugPrint(
                'Updated booking ${booking.id} to ${isValid ? 'accepted' : 'cancelled'}');
          }
        }).catchError((e) {
          if (kDebugMode) {
            debugPrint('Error updating booking ${booking.id} status: $e');
          }
          // We catch the error here so other updates can continue
        }));
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Error setting up update for booking ${booking.id}: $e');
        }
      }
    }

    // Wait for all updates to complete
    await Future.wait(updates);
  }

  /// Gets the current GPS location and updates the MapProvider if context is available
  Future<LatLng?> _getCurrentLocation(BuildContext context) async {
    LatLng? location;
    try {
      // Check if context is still valid
      if (!context.mounted) {
        if (kDebugMode) {
          debugPrint(
              'Context not mounted when getting location in _getCurrentLocation');
        }
        return null;
      }

      // Get current GPS position with timeout
      final Position position = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      ).timeout(Duration(seconds: AppConfig.locationFetchTimeout),
          onTimeout: () {
        throw TimeoutException('Location fetch timed out');
      });
      location = LatLng(position.latitude, position.longitude);
      if (kDebugMode) {
        debugPrint(
            'Got GPS location: ${position.latitude}, ${position.longitude}');
      }

      // Also update the MapProvider for consistency, but check mounted again
      // since awaiting Geolocator could have taken time
      if (context.mounted) {
        try {
          context.read<MapProvider>().setCurrentLocation(location);
        } catch (e) {
          if (kDebugMode) {
            debugPrint('Error updating MapProvider with location: $e');
          }
          // Continue with the obtained location even if MapProvider update fails
        }
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
    if (_isDisposed) return;
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
    BookingLogger.log('Attempting to mark booking $bookingId as ongoing',
        type: 'ACTION');

    try {
      // Find the booking in our local state for logging
      final booking = _bookings.firstWhere(
        (b) => b.id == bookingId,
        orElse: () => throw BookingException(
          message: 'Booking not found in local state',
          type: BookingConstants.errorTypeUnknown,
          operation: 'markBookingAsOngoing',
        ),
      );

      // Log distance information if available
      if (booking.distanceToDriver != null) {
        BookingLogger.log(
            'Distance to pickup location: ${booking.distanceToDriver!.toStringAsFixed(2)}m',
            type: 'DISTANCE');
      }

      final success = await _repository.updateBookingStatus(
          bookingId, BookingConstants.statusOngoing);

      if (success && !_isDisposed) {
        // Update local state to reflect the change
        final updatedBookings = _bookings.map((booking) {
          if (booking.id == bookingId) {
            return booking.copyWith(rideStatus: BookingConstants.statusOngoing);
          }
          return booking;
        }).toList();

        setBookings(updatedBookings);

        BookingLogger.log('Successfully marked booking $bookingId as ongoing',
            type: 'SUCCESS');
        return true;
      }

      if (!success) {
        BookingLogger.log(
            'Failed to mark booking $bookingId as ongoing: Database update failed',
            type: 'FAILURE');
      }

      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error marking booking as ongoing: $e');
      }

      BookingLogger.log('Error marking booking $bookingId as ongoing: $e',
          type: 'ERROR');

      // Store error for UI feedback if needed
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
    }
  }

  /// Mark a booking as completed when passenger reaches destination
  Future<bool> markBookingAsCompleted(String bookingId) async {
    BookingLogger.log('Attempting to mark booking $bookingId as completed',
        type: 'ACTION');

    try {
      // Find the booking in our local state for logging
      final booking = _bookings.firstWhere(
        (b) => b.id == bookingId,
        orElse: () => throw BookingException(
          message: 'Booking not found in local state',
          type: BookingConstants.errorTypeUnknown,
          operation: 'markBookingAsCompleted',
        ),
      );

      // Log distance information if available
      if (booking.distanceToDriver != null) {
        BookingLogger.log(
            'Distance to dropoff location: ${booking.distanceToDriver!.toStringAsFixed(2)}m',
            type: 'DISTANCE');
      }

      final success = await _repository.updateBookingStatus(
          bookingId, BookingConstants.statusCompleted);

      if (success && !_isDisposed) {
        // Remove the completed booking from local state
        final updatedBookings =
            _bookings.where((booking) => booking.id != bookingId).toList();

        setBookings(updatedBookings);

        // Increment completed bookings counter
        setCompletedBooking(_completedBooking + 1);

        BookingLogger.log('Successfully marked booking $bookingId as completed',
            type: 'SUCCESS');
        return true;
      }

      if (!success) {
        BookingLogger.log(
            'Failed to mark booking $bookingId as completed: Database update failed',
            type: 'FAILURE');
      }

      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error marking booking as completed: $e');
      }

      BookingLogger.log('Error marking booking $bookingId as completed: $e',
          type: 'ERROR');

      // Store error for UI feedback if needed
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
    }
  }

  /// Fetch completed bookings count
  Future<void> getCompletedBookings(BuildContext context) async {
    try {
      if (!context.mounted) {
        return;
      }

      final driverID = context.read<DriverProvider>().driverID;

      if (driverID.isEmpty || driverID == 'N/A') {
        if (kDebugMode) {
          debugPrint('Invalid driver ID: $driverID');
        }
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

      // Store error for UI feedback if needed
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
