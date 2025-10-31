import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:pasada_driver_side/common/config/app_config.dart';
import 'package:pasada_driver_side/data/models/booking_model.dart';
import 'package:pasada_driver_side/data/models/booking_receipt_model.dart';
import 'package:pasada_driver_side/common/exceptions/booking_exception.dart';
import 'package:pasada_driver_side/common/constants/booking_constants.dart';

import 'booking_repository.dart';

/// Concrete Supabase implementation of [BookingRepository].
class SupabaseBookingRepository implements BookingRepository {
  final SupabaseClient _supabase;

  SupabaseBookingRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  @override
  Future<List<Booking>> fetchActiveBookings(String driverId) async {
    return _withRetry<List<Booking>>(
      () => _fetchActiveBookingsInternal(driverId),
      'fetchActiveBookings',
      maxRetries: BookingConstants.defaultMaxRetries,
    );
  }

  Future<List<Booking>> _fetchActiveBookingsInternal(String driverId) async {
    if (kDebugMode) {
      debugPrint('Fetching bookings for driver: $driverId');
    }

    try {
      const selectFields = '${BookingConstants.fieldBookingId}, '
          '${BookingConstants.fieldPassengerId}, '
          '${BookingConstants.fieldRideStatus}, '
          '${BookingConstants.fieldPickupLat}, '
          '${BookingConstants.fieldPickupLng}, '
          '${BookingConstants.fieldDropoffLat}, '
          '${BookingConstants.fieldDropoffLng}, '
          '${BookingConstants.fieldSeatType}, '
          '${BookingConstants.fieldPassengerIdImagePath}, '
          '${BookingConstants.fieldIsIdAccepted}';

      const statusFilter =
          '${BookingConstants.fieldRideStatus}.eq.${BookingConstants.statusRequested},'
          '${BookingConstants.fieldRideStatus}.eq.${BookingConstants.statusAccepted},'
          '${BookingConstants.fieldRideStatus}.eq.${BookingConstants.statusOngoing}';

      final response = await _supabase
          .from('bookings')
          .select(selectFields)
          .eq(BookingConstants.fieldDriverId, driverId)
          .or(statusFilter)
          .timeout(
            const Duration(seconds: AppConfig.databaseOperationTimeout),
            onTimeout: () =>
                throw TimeoutException('Database operation timed out'),
          );

      if (kDebugMode) {
        debugPrint('Retrieved: ${response.length} active bookings');
        debugPrint('Retrieved: $response');
        // Debug: Print the first booking to see what fields are actually returned
        if (response.isNotEmpty) {
          debugPrint('First booking data: ${response.first}');
        }
      }

      return List<Map<String, dynamic>>.from(response)
          .map((json) => Booking.fromJson(json))
          .where((booking) => booking.isValid)
          .toList();
    } on TimeoutException {
      if (kDebugMode) {
        debugPrint('Timeout when fetching active bookings');
      }
      throw BookingException(
        message: 'Operation timed out',
        type: BookingConstants.errorTypeTimeout,
        operation: 'fetchActiveBookings',
      );
    } on PostgrestException catch (e) {
      if (kDebugMode) {
        debugPrint('Database error fetching active bookings: ${e.message}');
      }
      throw BookingException(
        message: e.message,
        type: BookingConstants.errorTypeDatabase,
        operation: 'fetchActiveBookings',
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Unknown error fetching active bookings: $e');
      }
      throw BookingException(
        message: e.toString(),
        type: BookingConstants.errorTypeUnknown,
        operation: 'fetchActiveBookings',
      );
    }
  }

  @override
  Future<int> fetchCompletedBookingsCount(String driverId) async {
    return _withRetry<int>(
      () => _fetchCompletedBookingsCountInternal(driverId),
      'fetchCompletedBookingsCount',
      maxRetries: BookingConstants.defaultMaxRetries,
    );
  }

  Future<int> _fetchCompletedBookingsCountInternal(String driverId) async {
    try {
      final response = await _supabase
          .from('bookings')
          .select(BookingConstants.fieldBookingId)
          .eq(BookingConstants.fieldDriverId, driverId)
          .eq(BookingConstants.fieldRideStatus,
              BookingConstants.statusCompleted)
          .timeout(
            const Duration(seconds: AppConfig.databaseOperationTimeout),
            onTimeout: () =>
                throw TimeoutException('Database operation timed out'),
          );

      return response.length;
    } on TimeoutException {
      if (kDebugMode) {
        debugPrint('Timeout when fetching completed bookings count');
      }
      throw BookingException(
        message: 'Operation timed out',
        type: BookingConstants.errorTypeTimeout,
        operation: 'fetchCompletedBookingsCount',
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error fetching completed bookings count: $e');
      }
      throw BookingException(
        message: e.toString(),
        type: e is PostgrestException
            ? BookingConstants.errorTypeDatabase
            : BookingConstants.errorTypeUnknown,
        operation: 'fetchCompletedBookingsCount',
      );
    }
  }

  @override
  Future<bool> updateBookingStatus(String bookingId, String newStatus) async {
    return _withRetry<bool>(
      () => _updateBookingStatusInternal(bookingId, newStatus),
      'updateBookingStatus',
      maxRetries: BookingConstants.defaultMaxRetries,
    );
  }

  @override
  Future<bool> updateIdAccepted(String bookingId, bool accepted) async {
    return _withRetry<bool>(
      () => _updateIdAcceptedInternal(bookingId, accepted),
      'updateIdAccepted',
      maxRetries: BookingConstants.defaultMaxRetries,
    );
  }

  Future<bool> _updateIdAcceptedInternal(
      String bookingId, bool accepted) async {
    try {
      final response = await _supabase
          .from('bookings')
          .update({BookingConstants.fieldIsIdAccepted: accepted})
          .eq(BookingConstants.fieldBookingId, bookingId)
          .select(
              '${BookingConstants.fieldBookingId}, ${BookingConstants.fieldIsIdAccepted}')
          .timeout(
            const Duration(seconds: AppConfig.databaseOperationTimeout),
            onTimeout: () =>
                throw TimeoutException('Database operation timed out'),
          );
      if (kDebugMode) {
        debugPrint('updateIdAccepted rows: ${response.length}');
        if (response.isNotEmpty) {
          debugPrint('updateIdAccepted first row: ${response.first}');
        }
      }
      return response.isNotEmpty;
    } on TimeoutException {
      if (kDebugMode) {
        debugPrint('Timeout when updating id acceptance');
      }
      throw BookingException(
        message: 'Operation timed out',
        type: BookingConstants.errorTypeTimeout,
        operation: 'updateIdAccepted',
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error updating id acceptance: $e');
      }
      throw BookingException(
        message: e.toString(),
        type: e is PostgrestException
            ? BookingConstants.errorTypeDatabase
            : BookingConstants.errorTypeUnknown,
        operation: 'updateIdAccepted',
      );
    }
  }

  @override
  Future<int?> fetchFare(String bookingId) async {
    return _withRetry<int?>(
      () async {
        final response = await _supabase
            .from('bookings')
            .select(BookingConstants.fieldFare)
            .eq(BookingConstants.fieldBookingId, bookingId)
            .limit(1)
            .maybeSingle()
            .timeout(
              const Duration(seconds: AppConfig.databaseOperationTimeout),
              onTimeout: () =>
                  throw TimeoutException('Database operation timed out'),
            );
        if (response == null) return null;
        final num? fare = response[BookingConstants.fieldFare] as num?;
        return fare?.toInt();
      },
      'fetchFare',
      maxRetries: BookingConstants.defaultMaxRetries,
    );
  }

  @override
  Future<bool> updateFare(String bookingId, int newFare) async {
    return _withRetry<bool>(
      () async {
        final response = await _supabase
            .from('bookings')
            .update({BookingConstants.fieldFare: newFare})
            .eq(BookingConstants.fieldBookingId, bookingId)
            .select(BookingConstants.fieldBookingId)
            .timeout(
              const Duration(seconds: AppConfig.databaseOperationTimeout),
              onTimeout: () =>
                  throw TimeoutException('Database operation timed out'),
            );
        return response.isNotEmpty;
      },
      'updateFare',
      maxRetries: BookingConstants.defaultMaxRetries,
    );
  }

  Future<bool> _updateBookingStatusInternal(
      String bookingId, String newStatus) async {
    try {
      await _supabase
          .from('bookings')
          .update({BookingConstants.fieldRideStatus: newStatus})
          .eq(BookingConstants.fieldBookingId, bookingId)
          .timeout(
            const Duration(seconds: AppConfig.databaseOperationTimeout),
            onTimeout: () =>
                throw TimeoutException('Database operation timed out'),
          );
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
        type: BookingConstants.errorTypeTimeout,
        operation: 'updateBookingStatus',
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error updating booking status: $e');
      }
      throw BookingException(
        message: e.toString(),
        type: e is PostgrestException
            ? BookingConstants.errorTypeDatabase
            : BookingConstants.errorTypeUnknown,
        operation: 'updateBookingStatus',
      );
    }
  }

  @override
  Stream<List<Booking>> activeBookingsStream(String driverId) {
    try {
      // STEP 1: Setup - Create the stream controller that we'll use to emit booking lists
      final controller = StreamController<List<Booking>>();

      // This filter is for filtering out the bookings in the stream
      final twoDaysAgo =
          DateTime.now().subtract(const Duration(days: 2)).toIso8601String();

      // STEP 2: Create two tracking maps/sets
      final activeBookings = <String, Booking>{};

      // This set tracks which booking IDs have EVER been assigned to this driver
      final trackedBookingIds = <String>{};

      // STEP 3: Define what statuses are considered "active"
      const activeStatuses = [
        BookingConstants.statusRequested,
        BookingConstants.statusAccepted,
        BookingConstants.statusOngoing,
      ];

      // STEP 4: Subscribe to the Supabase stream
      // IMPORTANT: This stream emits ALL bookings from the table every time ANY booking changes
      final subscription = _supabase
          .from('bookings')
          .stream(primaryKey: [BookingConstants.fieldBookingId])
          .gte('created_at', twoDaysAgo)
          .listen((response) {
            // STEP 5: Convert the response to a list of maps
            final data = List<Map<String, dynamic>>.from(response);

            // STEP 6: Process each booking in the database snapshot
            for (final json in data) {
              // STEP 7: Extract the key fields from this booking
              final id = json[BookingConstants.fieldBookingId].toString();
              final bookingDriverId =
                  json[BookingConstants.fieldDriverId]?.toString();
              final status = json[BookingConstants.fieldRideStatus]?.toString();

              // STEP 8: Handle driver reassignment detection
              // Check if this booking was previously assigned to us, but now has a different driver
              // This catches when a passenger cancels and finds another driver
              if (trackedBookingIds.contains(id) &&
                  bookingDriverId != driverId) {
                if (kDebugMode) {
                  debugPrint(
                      '🔄 Booking $id reassigned (driver changed from $driverId to $bookingDriverId)');
                }

                // Remove from both tracking structures since it's no longer ours
                activeBookings.remove(id);
                trackedBookingIds.remove(id);

                // Skip to next booking - we don't need to process this one further
                continue;
              }

              // STEP 9: Check if this booking is relevant to this driver
              final isValidDriver = bookingDriverId == driverId;
              final isActive = activeStatuses.contains(status);

              // STEP 10: Decision tree for adding/removing bookings

              // CASE A: This booking is for us AND it's active
              if (isValidDriver && isActive) {
                // Add it to our active list
                activeBookings[id] = Booking.fromJson(json);

                // Mark that we're tracking this booking
                // This prevents it from being re-added later if it completes
                trackedBookingIds.add(id);

                if (kDebugMode) {
                  debugPrint('✅ Added/Updated booking $id (status: $status)');
                }
              }
              // CASE B: This booking WAS ours (we tracked it before), but now it's not active or not ours
              else if (trackedBookingIds.contains(id)) {
                // Remove it from active bookings
                activeBookings.remove(id);

                // CRITICAL: If the booking is no longer active (completed/cancelled),
                // stop tracking it entirely so it won't be re-added on future stream emissions
                if (!isActive) {
                  trackedBookingIds.remove(id);

                  if (kDebugMode) {
                    debugPrint(
                        '🏁 Booking $id completed/cancelled - stopped tracking');
                  }
                }
              }
              // CASE C: This booking is NOT ours and we've never tracked it
              // Do nothing - this prevents old completed bookings from other sessions
              // from being added to our list
              else {
                // Silently ignore - this is expected for:
                // - Bookings for other drivers
                // - Old completed bookings from previous sessions
                // - Bookings that were never assigned to this driver
              }
            }

            // STEP 11: Build the final list to emit
            // Filter out any invalid bookings (additional validation)
            final list = activeBookings.values
                .where((b) => b.isValid)
                .toList(growable: false);

            // STEP 12: Log for debugging
            if (kDebugMode) {
              debugPrint(
                  '📊 Active bookings count: ${list.length} for driver: $driverId');
              debugPrint('   Tracked booking IDs: ${trackedBookingIds.length}');
            }

            // STEP 13: Emit the updated list to all listeners
            controller.add(list);
          });

      // STEP 14: Handle stream errors
      subscription.onError((error) {
        if (kDebugMode) debugPrint('❌ Booking stream error: $error');

        controller.addError(BookingException(
          message: error.toString(),
          type: BookingConstants.errorTypeUnknown,
          operation: 'activeBookingsStream',
        ));
      });

      // STEP 15: Clean up resources when the stream is cancelled
      controller.onCancel = () {
        if (kDebugMode)
          debugPrint('🛑 Booking stream cancelled for driver: $driverId');
        subscription.cancel();
      };

      // STEP 16: Return the stream for listeners to subscribe to
      return controller.stream;
    } catch (e) {
      // STEP 17: Handle any setup errors
      if (kDebugMode) {
        debugPrint('💥 Error setting up booking stream: $e');
      }

      return Stream.error(BookingException(
        message: e.toString(),
        type: BookingConstants.errorTypeUnknown,
        operation: 'activeBookingsStream',
      ));
    }
  }

  @override
  Future<List<BookingReceipt>> fetchTodayBookings(String driverId) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    return fetchBookingsByDateRange(driverId, startOfDay, endOfDay);
  }

  @override
  Future<List<BookingReceipt>> fetchBookingsByDateRange(
    String driverId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    return _withRetry<List<BookingReceipt>>(
      () => _fetchBookingsByDateRangeInternal(driverId, startDate, endDate),
      'fetchBookingsByDateRange',
      maxRetries: BookingConstants.defaultMaxRetries,
    );
  }

  Future<List<BookingReceipt>> _fetchBookingsByDateRangeInternal(
    String driverId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    if (kDebugMode) {
      debugPrint(
          'Fetching bookings for driver: $driverId from $startDate to $endDate');
    }

    try {
      // Select all fields needed for receipt
      final response = await _supabase
          .from('bookings')
          .select('*')
          .eq(BookingConstants.fieldDriverId, driverId)
          .eq(BookingConstants.fieldRideStatus,
              BookingConstants.statusCompleted)
          .neq(BookingConstants.fieldRideStatus,
              BookingConstants.statusCancelled)
          .neq(BookingConstants.fieldRideStatus, BookingConstants.statusOngoing)
          .neq(BookingConstants.fieldRideStatus,
              BookingConstants.statusRequested)
          .neq(
              BookingConstants.fieldRideStatus, BookingConstants.statusAccepted)
          .gte('created_at', startDate.toIso8601String())
          .lte('created_at', endDate.toIso8601String())
          .order('created_at', ascending: false)
          .timeout(
            const Duration(seconds: AppConfig.databaseOperationTimeout),
            onTimeout: () =>
                throw TimeoutException('Database operation timed out'),
          );

      if (kDebugMode) {
        debugPrint('Retrieved ${response.length} bookings for date range');
        debugPrint('Retrieved: $response');
        if (response.isNotEmpty) {
          debugPrint('First booking data: ${response.first}');
        }
      }

      return List<Map<String, dynamic>>.from(response)
          .map((json) => BookingReceipt.fromJson(json))
          .toList();
    } on TimeoutException {
      if (kDebugMode) {
        debugPrint('Timeout when fetching bookings by date range');
      }
      throw BookingException(
        message: 'Operation timed out',
        type: BookingConstants.errorTypeTimeout,
        operation: 'fetchBookingsByDateRange',
      );
    } on PostgrestException catch (e) {
      if (kDebugMode) {
        debugPrint(
            'Database error fetching bookings by date range: ${e.message}');
      }
      throw BookingException(
        message: e.message,
        type: BookingConstants.errorTypeDatabase,
        operation: 'fetchBookingsByDateRange',
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Unknown error fetching bookings by date range: $e');
      }
      throw BookingException(
        message: e.toString(),
        type: BookingConstants.errorTypeUnknown,
        operation: 'fetchBookingsByDateRange',
      );
    }
  }

  /// Generic retry helper
  Future<T> _withRetry<T>(
    Future<T> Function() operation,
    String operationName, {
    int maxRetries = 2,
    Duration delayBetweenRetries = const Duration(seconds: 1),
  }) async {
    int attempts = 0;
    Exception? lastException;

    while (true) {
      try {
        attempts++;
        return await operation();
      } on BookingException catch (e) {
        lastException = e;
        if (e.type == BookingConstants.errorTypeDatabase) rethrow;
        if (attempts > maxRetries) rethrow;
        await Future.delayed(delayBetweenRetries * attempts);
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
        if (attempts > maxRetries) {
          throw BookingException(
            message: e.toString(),
            type: BookingConstants.errorTypeUnknown,
            operation: operationName,
            originalException: lastException,
          );
        }
        await Future.delayed(delayBetweenRetries * attempts);
      }
    }
  }
}
