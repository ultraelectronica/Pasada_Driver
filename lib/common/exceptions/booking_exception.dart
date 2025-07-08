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
  String toString() => 'BookingException[$type] during $operation: $message';
}
