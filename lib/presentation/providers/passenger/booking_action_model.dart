import 'package:pasada_driver_side/data/models/booking_model.dart';

enum BookingActionType {
  pickup,
  dropoff,
}

class BookingAction {
  final BookingActionType type;
  final List<Booking> bookings;
  final DateTime timestamp;

  BookingAction({
    required this.type,
    required this.bookings,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}
