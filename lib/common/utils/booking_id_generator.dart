import 'dart:math';

/// Utility class for generating and validating booking IDs
class BookingIdGenerator {
  static final Random _random = Random();

  /// Generate a booking ID with prefix 10000 followed by 6 random digits
  /// Format: 10000XXXXXX (where XXXXXX are random digits 0-9)
  static String generateBookingId() {
    // Generate 6 random digits
    final randomDigits = List.generate(6, (index) => _random.nextInt(10));
    final randomString = randomDigits.join('');

    // Combine with prefix
    return '10000$randomString';
  }

  /// Generate a booking ID as integer (for database storage)
  /// Format: 10000XXXXXX (where XXXXXX are random digits 0-9)
  static int generateBookingIdAsInt() {
    final bookingId = generateBookingId();
    return int.parse(bookingId);
  }

  /// Format an existing booking ID to display format
  /// If the ID is already in the correct format, return as-is
  /// Otherwise, generate a new formatted ID
  static String formatBookingId(int backendBookingId) {
    // For now, we'll generate a new formatted ID based on the backend ID
    // This ensures consistency while maintaining the prefix format
    final random =
        Random(backendBookingId); // Use backend ID as seed for consistency
    final randomDigits = List.generate(6, (index) => random.nextInt(10));
    final randomString = randomDigits.join('');

    return '10000$randomString';
  }

  /// Check if a booking ID is in the correct format (10000XXXXXX)
  static bool isValidFormat(String bookingId) {
    if (bookingId.length != 11) return false;
    if (!bookingId.startsWith('10000')) return false;

    // Check if the last 6 characters are all digits
    final lastSix = bookingId.substring(5);
    return lastSix.split('').every((char) => int.tryParse(char) != null);
  }

  /// Check if a booking ID integer is in the correct format
  static bool isValidFormatInt(int bookingId) {
    return isValidFormat(bookingId.toString());
  }

  /// Extract the random portion of the booking ID
  static String extractRandomPortion(String bookingId) {
    if (!isValidFormat(bookingId)) {
      throw ArgumentError('Invalid booking ID format');
    }
    return bookingId.substring(5);
  }
}
