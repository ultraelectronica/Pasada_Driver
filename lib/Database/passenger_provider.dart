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

  /// method to get all booking details from the DB
  ///
  /// TODO: get all first the booking request that is requested
  /// TODO: check if the booking request is hindi pa nalalagpasan
  /// TODO: once na nameet yung requirement, mark booking as accepted
  /// TODO: get the nearest passenger
  /// TODO: set booking request to accepted
  /// TODO: set drop off location in the map screen
  /// TODO: check if the driver is near the drop off location
  /// TODO: when driver is in the drop off location, set ride status to completed
  Future<void> getBookingRequestsID(BuildContext context) async {
    try {
      final driverID = context.read<DriverProvider>().driverID;

      //Get booking requests
      final response = await supabase
          .from('bookings')
          .select(
              'booking_id, passenger_id, ride_status, pickup_lat, pickup_lng, dropoff_lat, dropoff_lng')
          .eq('driver_id', driverID)
          .eq('ride_status', 'requested');
      // Ride Statuses: [requested, accepted, ongoing, completed, cancelled]

      debugPrint('Booking response: $response');

      debugPrint('Check if booking request has passed the driver...');
      //loops through the booking requests in the database and checks if the passenger is in front of the driver
      for (var booking in response) {
        //this serves as a default base location for comparing
        LatLng? EndingLocation;
        EndingLocation = context.read<MapProvider>().endingLocation;
        debugPrint('Check Ending Location: $EndingLocation');

        //this is the pickup location of the passenger
        LatLng? PickUpLocation;
        PickUpLocation = LatLng(booking['pickup_lat'], booking['pickup_lng']);

        //this is the current location of the driver
        LatLng? DriverLocation;
        DriverLocation = context.read<MapProvider>().currentLocation;
        debugPrint('Check Driver Location: $DriverLocation');

        if (EndingLocation != null) {
          //distance between the passenger and the ending location
          double passengerDistanceToEnd = Geolocator.distanceBetween(
            EndingLocation.latitude,
            EndingLocation.longitude,
            PickUpLocation.latitude,
            PickUpLocation.longitude,
          );

          //distance between the driver and the ending location
          double driverDistanceToEnd = Geolocator.distanceBetween(
            EndingLocation.latitude,
            EndingLocation.longitude,
            DriverLocation!.latitude,
            DriverLocation.longitude,
          );

          //if the passenger is in front of the driver, accept the booking request
          debugPrint('\n\t\tchecking distance');
          debugPrint('Check booking ID: ${booking['booking_id']}');

          //check if passenger pick up is in front of the driver
          if (passengerDistanceToEnd < driverDistanceToEnd) {
            double metersAhead = driverDistanceToEnd - passengerDistanceToEnd;

            //check if passenger pickup is more than 20 meters ahead
            if (metersAhead > 20) {
              //accept booking request
              debugPrint('Pickup is in front of the driver');
              debugPrint('Check if passenger is not in front of the driver');
              debugPrint(
                  'Check passenger distance to end: $passengerDistanceToEnd');
              debugPrint('Check driver distance to end: $driverDistanceToEnd');

              debugPrint(
                  'check if distance between driver and passenger: ${passengerDistanceToEnd - driverDistanceToEnd} meters.');
              debugPrint(
                  'check if passenger distance to driver less than 20 meters? ${passengerDistanceToEnd - driverDistanceToEnd > 20}');
            } else {
              //reject booking request
              debugPrint('Passenger is not in front of the driver');
            }
          } else {
            //passenger pickup is behind the driver
            //reject booking request
            debugPrint('passenger is not in front of the driver');
            debugPrint(
                'Check passenger distance to end: $passengerDistanceToEnd');
            debugPrint('Check driver distance to end: $driverDistanceToEnd');

            debugPrint(
                'check if distance between driver and passenger: ${passengerDistanceToEnd - driverDistanceToEnd} meters.');
            debugPrint(
                'check if passenger distance to driver less than 20 meters? ${passengerDistanceToEnd - driverDistanceToEnd > 20}');
          }
        }
      }

      checkNearestBookingRequest(response, context);
      debugPrint('Checking nearest booking request');

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

      if (kDebugMode) {
        // print('Booking Details: $_bookingDetails');
        // print('Booking response: $response');
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
      String nearestPassenger; //stores nearest passenger
      double?
          currentNearestPassengerDistance; //serves as a placeholder for the nearest passenger distance

      //Get nearest passenger
      //loops through the booking requests
      for (var booking in response) {
        LatLng? currentLocation;
        currentLocation = context.read<MapProvider>().currentLocation;
        LatLng? passengerLocation;
        passengerLocation =
            LatLng(booking['pickup_lat'], booking['pickup_lng']);

        if (currentLocation != null) {
          // Calculate distance between driver and passenger
          double distance = Geolocator.distanceBetween(
            currentLocation.latitude,
            currentLocation.longitude,
            passengerLocation.latitude,
            passengerLocation.longitude,
          );
          //set nearest passenger if currentNearestPassengerDistance is null
          currentNearestPassengerDistance ??= distance;

          // Update nearest passenger if current distance is smaller
          if (distance < currentNearestPassengerDistance) {
            currentNearestPassengerDistance = distance;
            nearestPassenger = booking['booking_id'].toString();
            debugPrint('nearest passenger ID: $nearestPassenger');

            //set the drop off location in the map screen
            context.read<MapProvider>().setPickUpLocation(passengerLocation);
            debugPrint('Passenger Location: $passengerLocation');
          }

          if (kDebugMode) {
            print('Booking distance: $distance');
          }
        }
        debugPrint(
            'booking request: ID: ${booking['booking_id']} | pickup: ${booking['pickup_lat']}, ${booking['pickup_lng']}');
      }
    } on Exception catch (e, StackTrace) {
      debugPrint('Error checking nearest passenger: $e');
      debugPrint('Stack Trace in nearest passenger: $StackTrace');
    }
  }
}
