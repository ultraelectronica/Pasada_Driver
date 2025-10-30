import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pasada_driver_side/data/models/booking_receipt_model.dart';
import 'package:pasada_driver_side/data/repositories/booking_repository.dart';
import 'package:pasada_driver_side/presentation/providers/driver/driver_provider.dart';
import 'package:provider/provider.dart';

/// Provider to manage booking receipts state
class BookingReceiptProvider with ChangeNotifier {
  final BookingRepository _bookingRepository;

  BookingReceiptProvider({
    required BookingRepository bookingRepository,
  }) : _bookingRepository = bookingRepository;

  // State
  List<BookingReceipt> _todayBookings = [];
  bool _isLoading = false;
  String? _errorMessage;
  int _displayCount = 10;
  bool _isLoadingMore = false;
  static const int _initialDisplayLimit = 10;
  static const int _loadMoreIncrement = 10;

  // Getters
  List<BookingReceipt> get todayBookings => _todayBookings;

  /// Get bookings to display (limited by _displayCount)
  List<BookingReceipt> get displayedBookings {
    if (_todayBookings.length <= _displayCount) {
      return _todayBookings;
    }
    return _todayBookings.take(_displayCount).toList();
  }

  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  String? get errorMessage => _errorMessage;
  bool get hasError => _errorMessage != null;

  /// Get count of today's bookings
  int get todayBookingsCount => _todayBookings.length;

  /// Check if there are more bookings to show
  bool get hasMoreBookings => _todayBookings.length > _displayCount;

  /// Get count of remaining bookings
  int get remainingBookingsCount => _todayBookings.length > _displayCount
      ? _todayBookings.length - _displayCount
      : 0;

  /// Get count of next batch to load
  int get nextBatchCount {
    final remaining = remainingBookingsCount;
    return remaining > _loadMoreIncrement ? _loadMoreIncrement : remaining;
  }

  /// Get count of completed bookings today
  int get completedBookingsCount =>
      _todayBookings.where((b) => b.isCompleted).length;

  /// Get total earnings from today's bookings
  int get todayTotalEarnings =>
      _todayBookings.fold(0, (sum, booking) => sum + (booking.fare ?? 0));

  /// Fetch today's bookings
  Future<void> fetchTodayBookings(BuildContext context) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final driverProvider = context.read<DriverProvider>();

      // Wait for driver ID to be loaded from secure storage if needed
      String driverId = driverProvider.driverID;

      if (driverId.isEmpty) {
        if (kDebugMode) {
          debugPrint(
              'Driver ID not loaded yet, attempting to load from storage...');
        }

        // Try to load from secure storage
        final loaded = await driverProvider.loadFromSecureStorage(context);

        if (loaded) {
          driverId = driverProvider.driverID;
        }

        if (driverId.isEmpty) {
          // Still empty, user might not be logged in
          _todayBookings = [];
          _errorMessage = null; // Don't show error, just empty state
          if (kDebugMode) {
            debugPrint('Driver ID not available, skipping bookings fetch');
          }
          return;
        }
      }

      final bookings = await _bookingRepository.fetchTodayBookings(driverId);
      _todayBookings = bookings;
      _errorMessage = null;
      _displayCount = _initialDisplayLimit; // Reset display count

      if (kDebugMode) {
        debugPrint('Fetched ${bookings.length} bookings for today');
      }
    } catch (e) {
      _errorMessage = 'Failed to load bookings: ${e.toString()}';
      if (kDebugMode) {
        debugPrint('Error fetching today bookings: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetch bookings for a specific date range
  Future<void> fetchBookingsByDateRange(
    BuildContext context,
    DateTime startDate,
    DateTime endDate,
  ) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final driverProvider = context.read<DriverProvider>();

      // Wait for driver ID to be loaded from secure storage if needed
      String driverId = driverProvider.driverID;

      if (driverId.isEmpty) {
        if (kDebugMode) {
          debugPrint(
              'Driver ID not loaded yet, attempting to load from storage...');
        }

        // Try to load from secure storage
        final loaded = await driverProvider.loadFromSecureStorage(context);

        if (loaded) {
          driverId = driverProvider.driverID;
        }

        if (driverId.isEmpty) {
          // Still empty, user might not be logged in
          _todayBookings = [];
          _errorMessage = null; // Don't show error, just empty state
          if (kDebugMode) {
            debugPrint('Driver ID not available, skipping bookings fetch');
          }
          return;
        }
      }

      final bookings = await _bookingRepository.fetchBookingsByDateRange(
        driverId,
        startDate,
        endDate,
      );
      _todayBookings = bookings;
      _errorMessage = null;
      _displayCount = _initialDisplayLimit; // Reset display count

      if (kDebugMode) {
        debugPrint('Fetched ${bookings.length} bookings for date range');
      }
    } catch (e) {
      _errorMessage = 'Failed to load bookings: ${e.toString()}';
      if (kDebugMode) {
        debugPrint('Error fetching bookings by date range: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Get a specific booking by ID
  BookingReceipt? getBookingById(String bookingId) {
    try {
      return _todayBookings.firstWhere((b) => b.bookingId == bookingId);
    } catch (e) {
      return null;
    }
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Clear all bookings
  void clearBookings() {
    _todayBookings = [];
    _errorMessage = null;
    _displayCount = _initialDisplayLimit;
    _isLoadingMore = false;
    notifyListeners();
  }

  /// Load more bookings (progressive loading)
  Future<void> loadMoreBookings() async {
    if (_isLoadingMore || !hasMoreBookings) return;

    _isLoadingMore = true;
    notifyListeners();

    // Simulate a brief delay to show loading state and prevent UI freeze
    await Future.delayed(const Duration(milliseconds: 150));

    // Increase display count by increment
    _displayCount =
        (_displayCount + _loadMoreIncrement).clamp(0, _todayBookings.length);

    _isLoadingMore = false;
    notifyListeners();

    if (kDebugMode) {
      debugPrint(
          'Loaded more bookings. Now showing $_displayCount of ${_todayBookings.length}');
    }
  }

  /// Show all bookings at once (use with caution for large lists)
  Future<void> showAllBookings() async {
    if (_isLoadingMore) return;

    _isLoadingMore = true;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 150));

    _displayCount = _todayBookings.length;

    _isLoadingMore = false;
    notifyListeners();
  }

  /// Reset to initial display count
  void resetDisplayCount() {
    _displayCount = _initialDisplayLimit;
    notifyListeners();
  }
}
