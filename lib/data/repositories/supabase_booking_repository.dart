import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:pasada_driver_side/common/config/app_config.dart';
import 'package:pasada_driver_side/data/models/booking_model.dart';
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
          '${BookingConstants.fieldSeatType}';

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
      return _supabase
          .from('bookings')
          .stream(primaryKey: [BookingConstants.fieldBookingId])
          .eq(BookingConstants.fieldDriverId, driverId)
          .map((response) {
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
                .where((booking) => booking.isValid)
                .toList();
          })
          .handleError((error) {
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
