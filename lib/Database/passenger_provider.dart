import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pasada_driver_side/Database/map_provider.dart';
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

  /// Method to get all booking details from the DB
  ///
  /// This method:
  /// 1. Fetches booking requests with 'requested' status for the current driver
  /// 2. Processes the booking requests to find valid ones (passenger ahead by >20m)
  /// 3. Finds the nearest valid passenger
  /// 4. Updates the provider state with booking details
  Future<void> getBookingRequestsID(BuildContext context) async {
    try {
      final driverID = context.read<DriverProvider>().driverID;

      // Get booking requests
      final response = await supabase
          .from('bookings')
          .select(
              'booking_id, passenger_id, ride_status, pickup_lat, pickup_lng, dropoff_lat, dropoff_lng')
          .eq('driver_id', driverID)
          .eq('ride_status', 'requested');
      // Ride Statuses: [requested, accepted, ongoing, completed, cancelled]

      if (kDebugMode) {
        debugPrint('Retrieved ${response.length} booking requests');
      }

      // Store the context in a local variable to avoid BuildContext across async gaps warning
      final currentContext = context;
      if (currentContext.mounted) {
        // Find the nearest valid booking request
        checkNearestBookingRequest(response, currentContext);
      }

      if (response.isNotEmpty) {
        // Store full booking details
        List<BookingDetail> details = response
            .map<BookingDetail>((record) => BookingDetail.fromJson(record))
            .toList();
        setBookingDetails(details);

        List<String> ids = details.map((detail) => detail.bookingId).toList();
        setBookingIDs(ids);
      } else {
        setBookingDetails([]);
        setBookingIDs([]);
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('Error fetching booking details: $e');
        print('Stack Trace: $stackTrace');
      }
    }
  }

  void checkNearestBookingRequest(
      PostgrestList response, BuildContext context) {
    try {
      // Early exit if no bookings
      if (response.isEmpty) {
        return;
      }

      // Get locations once outside the loop
      final LatLng? currentLocation =
          context.read<MapProvider>().currentLocation;
      final LatLng? endingLocation = context.read<MapProvider>().endingLocation;

      if (currentLocation == null || endingLocation == null) {
        debugPrint(
            'Cannot check nearest booking: current or ending location is null');
        return;
      }

      String? nearestPassengerId;
      double? nearestDistance;
      LatLng? nearestPassengerLocation;

      // Pre-filter valid bookings (passengers ahead by more than 20 meters)
      List<Map<String, dynamic>> validBookings = [];

      for (var booking in response) {
        final LatLng pickupLocation =
            LatLng(booking['pickup_lat'], booking['pickup_lng']);

        // Calculate distances once
        final double passengerDistanceToEnd = Geolocator.distanceBetween(
          endingLocation.latitude,
          endingLocation.longitude,
          pickupLocation.latitude,
          pickupLocation.longitude,
        );

        final double driverDistanceToEnd = Geolocator.distanceBetween(
          endingLocation.latitude,
          endingLocation.longitude,
          currentLocation.latitude,
          currentLocation.longitude,
        );

        // Check if passenger is ahead of driver by more than 20 meters
        if (passengerDistanceToEnd < driverDistanceToEnd) {
          final double metersAhead =
              driverDistanceToEnd - passengerDistanceToEnd;
          if (metersAhead > 20) {
            // Calculate distance to driver once
            final double distanceToDriver = Geolocator.distanceBetween(
              currentLocation.latitude,
              currentLocation.longitude,
              pickupLocation.latitude,
              pickupLocation.longitude,
            );

            // Add to valid bookings with pre-calculated distance
            validBookings.add({
              ...booking,
              'distance_to_driver': distanceToDriver,
              'pickup_location': pickupLocation,
            });
          }
        }
      }

      // Sort valid bookings by distance (most efficient way to find nearest)
      if (validBookings.isNotEmpty) {
        validBookings.sort((a, b) => (a['distance_to_driver'] as double)
            .compareTo(b['distance_to_driver'] as double));

        // The first booking is now the nearest
        final nearestBooking = validBookings.first;
        nearestPassengerId = nearestBooking['booking_id'].toString();
        nearestDistance = nearestBooking['distance_to_driver'];
        nearestPassengerLocation = nearestBooking['pickup_location'];

        // Set the pickup location for the nearest valid passenger
        if (nearestPassengerLocation != null) {
          context
              .read<MapProvider>()
              .setPickUpLocation(nearestPassengerLocation);
          debugPrint(
              'Set nearest passenger: ID: $nearestPassengerId, Distance: $nearestDistance meters, location: $nearestPassengerLocation');
        }
      } else {
        debugPrint(
            'No valid bookings found (passengers must be ahead by >20m)');
      }
    } on Exception catch (e, stackTrace) {
      debugPrint('Error checking nearest passenger: $e');
      debugPrint('Stack Trace in nearest passenger: $stackTrace');
    }
  }
}
