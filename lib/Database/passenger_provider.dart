import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pasada_driver_side/Database/map_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async'; // Add this for StreamController and StreamSubscription
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'driver_provider.dart';
import 'dart:math';
import 'package:pasada_driver_side/Config/app_config.dart';
import 'dart:io' show File, Directory, Platform, FileMode;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

// ==================== PROVIDER ====================

/// Class to handle comprehensive logging to both console and file
class BookingLogger {
  static const String _logFileName = 'pasada_bookings.log';
  static bool _isInitialized = false;
  static late Directory _logDirectory;
  static late File _logFile;

  /// Initialize the logger
  static Future<void> init() async {
    if (_isInitialized) return;
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        final appDir = await getApplicationDocumentsDirectory();
        _logDirectory = appDir;
      } else {
        // For desktop platforms
        _logDirectory = await getApplicationSupportDirectory();
      }

      _logFile = File('${_logDirectory.path}/$_logFileName');
      _isInitialized = true;

      // Add logger initialization log
      log('BookingLogger initialized. Log path: ${_logFile.path}');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to initialize BookingLogger: $e');
      }
    }
  }

  /// Log a message with timestamp to both console and file
  static Future<void> log(String message, {String? type}) async {
    // Format: [2023-05-29 14:30:45] [INFO] Message
    final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    final logType = type ?? 'INFO';
    final formattedMessage = '[$timestamp] [$logType] $message';

    // Always log to console in debug mode
    if (kDebugMode) {
      debugPrint(formattedMessage);
    }

    // Try to log to file if initialized
    if (_isInitialized) {
      try {
        await _logFile.writeAsString('$formattedMessage\n',
            mode: FileMode.append);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Failed to write to log file: $e');
        }
      }
    }
  }
}

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
          _errorType = BookingRepository.errorTypeUnknown;
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
      _errorType = BookingRepository.errorTypeUnknown;
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
              ? BookingRepository.errorTypeTimeout
              : BookingRepository.errorTypeUnknown;
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
        _errorType = BookingRepository.errorTypeUnknown;
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

        if (booking.rideStatus == BookingRepository.statusAccepted) {
          // For accepted bookings, calculate distance to pickup
          distanceToDriver = LocationService.calculateDistance(
              driverLocation, booking.pickupLocation);
          pickupBookings
              .add(booking.copyWith(distanceToDriver: distanceToDriver));

          if (kDebugMode) {
            debugPrint(
                'PICKUP booking ${booking.id}: Distance to pickup = ${distanceToDriver.toStringAsFixed(2)}m');
          }
        } else if (booking.rideStatus == BookingRepository.statusOngoing) {
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
      final action = booking.rideStatus == BookingRepository.statusAccepted
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
                ? BookingRepository.statusAccepted
                : BookingRepository.statusCancelled);

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
          type: BookingRepository.errorTypeUnknown,
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
          bookingId, BookingRepository.statusOngoing);

      if (success && !_isDisposed) {
        // Update local state to reflect the change
        final updatedBookings = _bookings.map((booking) {
          if (booking.id == bookingId) {
            return booking.copyWith(
                rideStatus: BookingRepository.statusOngoing);
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
          _errorType = BookingRepository.errorTypeUnknown;
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
          type: BookingRepository.errorTypeUnknown,
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
          bookingId, BookingRepository.statusCompleted);

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
          _errorType = BookingRepository.errorTypeUnknown;
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
          _errorType = BookingRepository.errorTypeUnknown;
        }
        notifyListeners();
      }
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
  final String seatType;

  // Optional calculated fields
  final double? distanceToDriver;

  const Booking({
    required this.id,
    required this.passengerId,
    required this.rideStatus,
    required this.pickupLocation,
    required this.dropoffLocation,
    required this.seatType,
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
      seatType: json['seat_type'] as String? ?? 'sitting',
    );
  }

  Booking copyWith({
    String? id,
    String? passengerId,
    String? rideStatus,
    LatLng? pickupLocation,
    LatLng? dropoffLocation,
    String? seatType,
    double? distanceToDriver,
  }) {
    return Booking(
      id: id ?? this.id,
      passengerId: passengerId ?? this.passengerId,
      rideStatus: rideStatus ?? this.rideStatus,
      pickupLocation: pickupLocation ?? this.pickupLocation,
      dropoffLocation: dropoffLocation ?? this.dropoffLocation,
      seatType: seatType ?? this.seatType,
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

  // Error types for better error handling
  static const String errorTypeNetwork = 'network_error';
  static const String errorTypeDatabase = 'database_error';
  static const String errorTypeTimeout = 'timeout_error';
  static const String errorTypeUnknown = 'unknown_error';

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

    try {
      // Add timeout to the database operation
      final response = await _supabase
          .from('bookings')
          .select(
              'booking_id, passenger_id, ride_status, pickup_lat, pickup_lng, dropoff_lat, dropoff_lng, seat_type')
          .eq('driver_id', driverId)
          .or(
              'ride_status.eq.$statusRequested,ride_status.eq.$statusAccepted,ride_status.eq.$statusOngoing')
          .timeout(Duration(seconds: AppConfig.databaseOperationTimeout),
              onTimeout: () {
        throw TimeoutException('Database operation timed out');
      });

      if (kDebugMode) {
        debugPrint('Retrieved ${response.length} active bookings');
      }

      return List<Map<String, dynamic>>.from(response)
          .map((json) => Booking.fromJson(json))
          .toList();
    } on TimeoutException {
      if (kDebugMode) {
        debugPrint('Timeout when fetching active bookings');
      }
      throw BookingException(
        message: 'Operation timed out',
        type: errorTypeTimeout,
        operation: 'fetchActiveBookings',
      );
    } on PostgrestException catch (e) {
      if (kDebugMode) {
        debugPrint('Database error fetching active bookings: ${e.message}');
      }
      throw BookingException(
        message: e.message,
        type: errorTypeDatabase,
        operation: 'fetchActiveBookings',
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Unknown error fetching active bookings: $e');
      }
      throw BookingException(
        message: e.toString(),
        type: errorTypeUnknown,
        operation: 'fetchActiveBookings',
      );
    }
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
    try {
      final response = await _supabase
          .from('bookings')
          .select('booking_id')
          .eq('driver_id', driverId)
          .eq('ride_status', statusCompleted)
          .timeout(Duration(seconds: AppConfig.databaseOperationTimeout),
              onTimeout: () {
        throw TimeoutException('Database operation timed out');
      });

      return response.length;
    } on TimeoutException {
      if (kDebugMode) {
        debugPrint('Timeout when fetching completed bookings count');
      }
      throw BookingException(
        message: 'Operation timed out',
        type: errorTypeTimeout,
        operation: 'fetchCompletedBookingsCount',
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error fetching completed bookings count: $e');
      }
      throw BookingException(
        message: e.toString(),
        type: e is PostgrestException ? errorTypeDatabase : errorTypeUnknown,
        operation: 'fetchCompletedBookingsCount',
      );
    }
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
    try {
      await _supabase
          .from('bookings')
          .update({'ride_status': newStatus})
          .eq('booking_id', bookingId)
          .timeout(Duration(seconds: AppConfig.databaseOperationTimeout),
              onTimeout: () {
            throw TimeoutException('Database operation timed out');
          });

      if (kDebugMode) {
        debugPrint('Updated booking $bookingId status to $newStatus');
      }
      return true;
    } on TimeoutException {
      if (kDebugMode) {
        debugPrint('Timeout when updating booking status');
      }
      throw BookingException(
        message: 'Operation timed out',
        type: errorTypeTimeout,
        operation: 'updateBookingStatus',
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error updating booking status: $e');
      }
      throw BookingException(
        message: e.toString(),
        type: e is PostgrestException ? errorTypeDatabase : errorTypeUnknown,
        operation: 'updateBookingStatus',
      );
    }
  }

  /// Generic retry mechanism for repository methods
  Future<T> _withRetry<T>(Future<T> Function() operation, String operationName,
      {int maxRetries = 2,
      Duration delayBetweenRetries = const Duration(seconds: 1)}) async {
    int attempts = 0;
    Exception? lastException;

    while (true) {
      try {
        attempts++;
        return await operation();
      } on BookingException catch (e) {
        lastException = e;

        // Don't retry certain types of errors
        if (e.type == errorTypeDatabase) {
          if (kDebugMode) {
            debugPrint(
                'Database error in $operationName, not retrying: ${e.message}');
          }
          rethrow;
        }

        if (attempts > maxRetries) {
          if (kDebugMode) {
            debugPrint('Max retries reached for $operationName');
          }
          rethrow;
        }

        if (kDebugMode) {
          debugPrint(
              'Attempt $attempts failed for $operationName: ${e.message}. Retrying...');
        }

        // Wait before retrying with progressive backoff
        await Future.delayed(delayBetweenRetries * attempts);
      } catch (e, stackTrace) {
        lastException = e is Exception ? e : Exception(e.toString());

        if (attempts > maxRetries) {
          // If we've maxed out retries, rethrow the error
          if (kDebugMode) {
            debugPrint('Error in $operationName after $attempts attempts: $e');
            debugPrint('Stack trace: $stackTrace');
          }

          throw BookingException(
            message: e.toString(),
            type: errorTypeUnknown,
            operation: operationName,
            originalException: lastException,
          );
        }

        if (kDebugMode) {
          debugPrint(
              'Attempt $attempts failed for $operationName: $e. Retrying...');
        }

        // Wait before retrying with progressive backoff
        await Future.delayed(delayBetweenRetries * attempts);
      }
    }
  }

  /// Stream of active bookings for a driver for real-time updates
  Stream<List<Booking>> activeBookingsStream(String driverId) {
    try {
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
          })
          .handleError((error) {
            if (kDebugMode) {
              debugPrint('Error in booking stream: $error');
            }
            // Re-throw to allow subscribers to handle it
            throw BookingException(
              message: error.toString(),
              type: errorTypeUnknown,
              operation: 'activeBookingsStream',
            );
          });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error setting up booking stream: $e');
      }
      // Return an empty stream with error
      return Stream.error(BookingException(
        message: e.toString(),
        type: errorTypeUnknown,
        operation: 'activeBookingsStream',
      ));
    }
  }
}

/// Custom exception class for booking operations
class BookingException implements Exception {
  final String message;
  final String type;
  final String operation;
  final Exception? originalException;

  BookingException({
    required this.message,
    required this.type,
    required this.operation,
    this.originalException,
  });

  @override
  String toString() {
    return 'BookingException[$type] during $operation: $message';
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

    // If the point is within ±threshold of the direction of travel, consider it "ahead"
    return diff <= AppConfig.bearingAngleThreshold;
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

    // Calculate distance between driver and destination
    final driverToDestinationDistance =
        calculateDistance(driverLocation, destinationLocation);

    // Check if pickup is too far away for either validation method
    if (driverToPickupDistance > AppConfig.maxDistanceSecondaryCheck) {
      if (kDebugMode) {
        debugPrint(
            'Pickup is too far away (${driverToPickupDistance.toStringAsFixed(2)}m)');
      }
      return false;
    }

    // Special case: If driver and destination are essentially at the same point
    if (driverToDestinationDistance < 10) {
      if (kDebugMode) {
        debugPrint(
            'SPECIAL CASE: Driver at/near destination, using alternative validation');
      }

      // When driver is near destination, we need different criteria
      final bearingToPickup = calculateBearing(driverLocation, pickupLocation);

      // Check if the pickup is in a direction generally considered "behind" the driver
      // This is based on accumulated knowledge from previous valid/invalid bookings
      final isLikelyBehindDriver =
          (bearingToPickup > AppConfig.behindDriverMinBearing &&
              bearingToPickup < AppConfig.behindDriverMaxBearing);

      if (isLikelyBehindDriver) {
        if (kDebugMode) {
          debugPrint(
              'SPECIAL CASE: Rejecting booking likely behind driver (bearing: ${bearingToPickup.toStringAsFixed(2)}°)');
        }
        return false;
      }

      // If not behind and within reasonable distance, consider it valid
      return driverToPickupDistance < AppConfig.maxPickupDistanceThreshold;
    }

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
    final isPrimaryValid = isAheadByBearing &&
        driverToPickupDistance < AppConfig.maxPickupDistanceThreshold;

    // SECONDARY CHECK: Is pickup significantly ahead by distance?
    // This helps in straight-line cases and provides backwards compatibility
    final isSecondaryValid = metersAhead > minRequiredDistance &&
        driverToPickupDistance < AppConfig.maxDistanceSecondaryCheck;

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
