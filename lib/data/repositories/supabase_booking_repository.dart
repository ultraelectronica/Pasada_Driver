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
        debugPrint('Retrieved ${response.length} active bookings');
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
      // Note: We don't filter by driver_id at the stream level because when
      // driver_id changes to null, we won't receive that update.
      // We DO filter by status to reduce the data load (only active bookings).
      return _supabase
          .from('bookings')
          .stream(primaryKey: [BookingConstants.fieldBookingId]).inFilter(
              BookingConstants.fieldRideStatus, [
        BookingConstants.statusRequested,
        BookingConstants.statusAccepted,
        BookingConstants.statusOngoing,
      ]).map((response) {
        final data = List<Map<String, dynamic>>.from(response);
        final filteredData = data.where((booking) {
          // First, ensure driver_id matches and is not null/empty
          final bookingDriverId = booking[BookingConstants.fieldDriverId];

          // If driver_id is null, empty, or doesn't match this driver, exclude it
          // This handles the case where passenger removes the driver
          if (bookingDriverId == null ||
              bookingDriverId.toString().trim().isEmpty ||
              bookingDriverId.toString() != driverId) {
            if (kDebugMode) {
              final bookingId = booking[BookingConstants.fieldBookingId];
              debugPrint(
                  'Filtering out booking $bookingId - driver_id mismatch or null');
            }
            return false;
          }

          // Then check status - only show active bookings
          final status = booking[BookingConstants.fieldRideStatus];
          if (status == null) return false;

          final statusStr = status.toString();
          return statusStr == BookingConstants.statusRequested ||
              statusStr == BookingConstants.statusAccepted ||
              statusStr == BookingConstants.statusOngoing;
        }).toList();

        if (kDebugMode) {
          debugPrint(
              'Stream emitting ${filteredData.length} bookings for driver $driverId');
        }

        return filteredData
            .map((json) => Booking.fromJson(json))
            .where((booking) => booking.isValid)
            .toList();
      }).handleError((error) {
        if (kDebugMode) {
          debugPrint('Error in booking stream: $error');
        }
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
