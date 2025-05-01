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
  /// 2. Checks all valid booking request | Conditions: passenger ahead to driver by > 20m
  /// 3. Finds the nearest valid passenger
  /// 4. Sets the pickup location for the nearest valid passenger and displays it on the map
  /// 5. Updates the provider state with booking details
  Future<void> getBookingRequestsID(BuildContext context) async {
    try {
      // Store the context in a local variable to avoid BuildContext across async gaps warning
      final currentContext = context;

      // Get driver ID and locations before async operation
      final driverID = currentContext.read<DriverProvider>().driverID;
      final LatLng? currentLocation =
          currentContext.read<MapProvider>().currentLocation;
      final LatLng? endingLocation =
          currentContext.read<MapProvider>().endingLocation;

      /// Get booking requests
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

      // Check if context is still valid after async operation
      if (!currentContext.mounted) {
        debugPrint('Context no longer mounted, aborting operation');
        return;
      }

      // container for valid bookings (passengers ahead by more than 20 meters)
      List<Map<String, dynamic>> validBookings = [];

      //check if necessary locations are available
      if (currentLocation != null &&
          endingLocation != null &&
          response.isNotEmpty) {
        // Calculate driver's distance to end once
        final double driverDistanceToEnd = Geolocator.distanceBetween(
          endingLocation.latitude,
          endingLocation.longitude,
          currentLocation.latitude,
          currentLocation.longitude,
        );

        // Filter valid bookings and pre-calculate distances to driver
        for (var booking in response) {
          final LatLng pickupLocation =
              LatLng(booking['pickup_lat'], booking['pickup_lng']);

          // Calculate passenger's distance to end
          final double passengerDistanceToEnd = Geolocator.distanceBetween(
            endingLocation.latitude,
            endingLocation.longitude,
            pickupLocation.latitude,
            pickupLocation.longitude,
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

        debugPrint(
            'Found ${validBookings.length} valid bookings (passengers ahead by >20m)');

        if (currentContext.mounted) {
          // Find the nearest valid booking request
          findNearestBookingAndSetPickup(validBookings, currentContext);
        }

        if (validBookings.isNotEmpty) {
          // Store only valid booking details
          List<BookingDetail> details = validBookings
              .map<BookingDetail>((record) => BookingDetail.fromJson({
                    'booking_id': record['booking_id'],
                    'passenger_id': record['passenger_id'],
                    'ride_status': record['ride_status'],
                    'pickup_lat': record['pickup_lat'],
                    'pickup_lng': record['pickup_lng'],
                    'dropoff_lat': record['dropoff_lat'],
                    'dropoff_lng': record['dropoff_lng'],
                  }))
              .toList();
          setBookingDetails(details);

          List<String> ids = details.map((detail) => detail.bookingId).toList();
          setBookingIDs(ids);

          if (kDebugMode) {
            debugPrint('Stored ${details.length} valid booking details');
          }
        } else {
          setBookingDetails([]);
          setBookingIDs([]);
          if (kDebugMode) {
            debugPrint('No valid bookings to store');
          }
        }
      } else {
        // Handle case when locations are not available or no bookings
        setBookingDetails([]);
        setBookingIDs([]);
        if (kDebugMode) {
          if (currentLocation == null || endingLocation == null) {
            debugPrint(
                'Missing location data: currentLocation=$currentLocation, endingLocation=$endingLocation');
          } else if (response.isEmpty) {
            debugPrint('No booking requests found');
          }
        }
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('Error fetching booking details: $e');
        print('Stack Trace: $stackTrace');
      }
    }
  }

  void findNearestBookingAndSetPickup(
      List<Map<String, dynamic>> validBookings, BuildContext context) {
    try {
      // Early exit if no bookings
      if (validBookings.isEmpty) {
        if (kDebugMode) {
          debugPrint('No valid bookings to process');
        }
        return;
      }

      // Sort valid bookings by distance (most efficient way to find nearest)
      validBookings.sort((a, b) => (a['distance_to_driver'] as double)
          .compareTo(b['distance_to_driver'] as double));

      // The first booking is now the nearest
      final nearestBooking = validBookings.first;
      final String nearestPassengerId = nearestBooking['booking_id'].toString();
      final double nearestDistance =
          nearestBooking['distance_to_driver'] as double;
      final LatLng nearestPassengerLocation =
          nearestBooking['pickup_location'] as LatLng;

      // Set the pickup location for the nearest valid passenger
      context.read<MapProvider>().setPickUpLocation(nearestPassengerLocation);

      if (kDebugMode) {
        debugPrint(
            'Set nearest passenger: ID: $nearestPassengerId, Distance: ${nearestDistance.toStringAsFixed(2)} meters');
      }
    } on Exception catch (e, stackTrace) {
      debugPrint('Error finding nearest passenger: $e');
      debugPrint('Stack Trace in nearest passenger: $stackTrace');
    }
  }
}
