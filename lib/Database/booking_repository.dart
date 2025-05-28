import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pasada_driver_side/Config/app_config.dart';
import 'booking_model.dart';
import 'booking_exception.dart';
import 'booking_constants.dart';
import 'booking_repository_interface.dart';

// ==================== REPOSITORIES ====================

/// Repository to handle all database operations related to bookings
class BookingRepository implements IBookingRepository {
  final SupabaseClient _supabase;

  BookingRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  @override
  Future<List<Booking>> fetchActiveBookings(String driverId) async {
    return _withRetry<List<Booking>>(
      () => _fetchActiveBookingsInternal(driverId),
      'fetchActiveBookings',
      maxRetries: BookingConstants.defaultMaxRetries,
    );
  }

  /// Internal implementation of fetchActiveBookings
  Future<List<Booking>> _fetchActiveBookingsInternal(String driverId) async {
    if (kDebugMode) {
      debugPrint('Fetching bookings for driver: $driverId');
    }

    try {
      // Build the select query with all required fields
      const selectFields = '${BookingConstants.fieldBookingId}, '
          '${BookingConstants.fieldPassengerId}, '
          '${BookingConstants.fieldRideStatus}, '
          '${BookingConstants.fieldPickupLat}, '
          '${BookingConstants.fieldPickupLng}, '
          '${BookingConstants.fieldDropoffLat}, '
          '${BookingConstants.fieldDropoffLng}, '
          '${BookingConstants.fieldSeatType}';

      // Build the OR condition for active statuses
      const statusFilter =
          '${BookingConstants.fieldRideStatus}.eq.${BookingConstants.statusRequested},'
          '${BookingConstants.fieldRideStatus}.eq.${BookingConstants.statusAccepted},'
          '${BookingConstants.fieldRideStatus}.eq.${BookingConstants.statusOngoing}';

      final response = await _supabase
          .from('bookings')
          .select(selectFields)
          .eq(BookingConstants.fieldDriverId, driverId)
          .or(statusFilter)
          .timeout(Duration(seconds: AppConfig.databaseOperationTimeout),
              onTimeout: () {
        throw TimeoutException('Database operation timed out');
      });

      if (kDebugMode) {
        debugPrint('Retrieved ${response.length} active bookings');
      }

      return List<Map<String, dynamic>>.from(response)
          .map((json) => Booking.fromJson(json))
          .where((booking) => booking.isValid) // Additional validation
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

  /// Internal implementation of fetchCompletedBookingsCount
  Future<int> _fetchCompletedBookingsCountInternal(String driverId) async {
    try {
      final response = await _supabase
          .from('bookings')
          .select(BookingConstants.fieldBookingId)
          .eq(BookingConstants.fieldDriverId, driverId)
          .eq(BookingConstants.fieldRideStatus,
              BookingConstants.statusCompleted)
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

  /// Internal implementation of updateBookingStatus
  Future<bool> _updateBookingStatusInternal(
      String bookingId, String newStatus) async {
    try {
      await _supabase
          .from('bookings')
          .update({BookingConstants.fieldRideStatus: newStatus})
          .eq(BookingConstants.fieldBookingId, bookingId)
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
        if (e.type == BookingConstants.errorTypeDatabase) {
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
            type: BookingConstants.errorTypeUnknown,
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

  @override
  Stream<List<Booking>> activeBookingsStream(String driverId) {
    try {
      return _supabase
          .from('bookings')
          .stream(primaryKey: [BookingConstants.fieldBookingId])
          .eq(BookingConstants.fieldDriverId, driverId)
          .map((response) {
            // Filter the response here since we can't use .or() in stream queries
            final data = List<Map<String, dynamic>>.from(response);
            final filteredData = data.where((booking) {
              final status =
                  booking[BookingConstants.fieldRideStatus] as String;
              return status == BookingConstants.statusRequested ||
                  status == BookingConstants.statusAccepted ||
                  status == BookingConstants.statusOngoing;
            }).toList();

            return filteredData
                .map((json) => Booking.fromJson(json))
                .where((booking) => booking.isValid) // Additional validation
                .toList();
          })
          .handleError((error) {
            if (kDebugMode) {
              debugPrint('Error in booking stream: $error');
            }
            // Re-throw to allow subscribers to handle it
            throw BookingException(
              message: error.toString(),
              type: BookingConstants.errorTypeUnknown,
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
        type: BookingConstants.errorTypeUnknown,
        operation: 'activeBookingsStream',
      ));
    }
  }
}
