import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import 'driver_provider.dart';

class BookingDetail {
  final String bookingId;
  final String passengerId;
  final String rideStatus;
  final double pickupLat;
  final double pickupLng;
  final double dropoffLat;
  final double dropoffLng;

  BookingDetail({
    required this.bookingId,
    required this.passengerId,
    required this.rideStatus,
    required this.pickupLat,
    required this.pickupLng,
    required this.dropoffLat,
    required this.dropoffLng,
  });

  factory BookingDetail.fromJson(Map<String, dynamic> json) {
    return BookingDetail(
      bookingId: json['booking_id'].toString(),
      passengerId: json['passenger_id'].toString(),
      rideStatus: json['ride_status'] as String,
      pickupLat: (json['pickup_lat'] as num).toDouble(),
      pickupLng: (json['pickup_lng'] as num).toDouble(),
      dropoffLat: (json['dropoff_lat'] as num).toDouble(),
      dropoffLng: (json['dropoff_lng'] as num).toDouble(),
    );
  }
}

class PassengerProvider with ChangeNotifier {
  final SupabaseClient supabase = Supabase.instance.client;

  int _passengerCapacity = 0;
  List<String> _bookingIDs = [];
  List<BookingDetail> _bookingDetails = [];

  int get passengerCapacity => _passengerCapacity;
  List<String> get bookingIDs => _bookingIDs;
  List<BookingDetail> get bookingDetails => _bookingDetails;

  void setPassengerCapacity(int value) {
    _passengerCapacity = value;
    notifyListeners();
  }

  void setBookingIDs(List<String> value) {
    _bookingIDs = value;
    notifyListeners();
  }

  void setBookingDetails(List<BookingDetail> value) {
    _bookingDetails = value;
    notifyListeners();
  }

  /// method to get all booking details from the DB
  Future<void> getBookingRequestsID(BuildContext context) async {
    try {
      final driverID = context.read<DriverProvider>().driverID;

      final response = await supabase
          .from('bookings')
          .select(
              'booking_id, passenger_id, ride_status, pickup_lat, pickup_lng, dropoff_lat, dropoff_lng')
          .eq('driver_id', driverID)
          .eq('ride_status',
              'requested'); // Ride Statuses: [requested, accepted, ongoing, completed, cancelled]

      debugPrint('Driver ID: $driverID');

      if (response.isNotEmpty) {
        // Store full booking details
        List<BookingDetail> details = response
            .map<BookingDetail>((record) => BookingDetail.fromJson(record))
            .toList();
        setBookingDetails(details);

        // Also maintain the list of booking IDs for backward compatibility
        List<String> ids = details.map((detail) => detail.bookingId).toList();
        setBookingIDs(ids);
      } else {
        setBookingDetails([]);
        setBookingIDs([]);
      }

      if (kDebugMode) {
        print('Booking Details: $_bookingDetails');
        print('Booking response: $response');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('Error fetching booking details: $e');
        print('Stack Trace: $stackTrace');
      }
    }
  }

  Future<void> saveBookingRequestToDriver(
    String bookingID,
    String passengerID,
    String rideStatus,
    double pickupLat,
    double pickupLng,
    double dropoffLat,
    double dropoffLng,
  ) async {
    try {
      final response = await supabase.from('bookings').insert({
        'booking_id': bookingID,
        'passenger_id': passengerID,
        'ride_status': rideStatus,
        'pickup_lat': pickupLat,
        'pickup_lng': pickupLng,
        'dropoff_lat': dropoffLat,
        'dropoff_lng': dropoffLng,
      }).single();

      debugPrint('Error saving booking request: $response');
    } catch (e) {
      debugPrint('Error saving booking request: $e');
    }
  }
}
