import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import 'driver_provider.dart';

class PassengerProvider with ChangeNotifier {
  final SupabaseClient supabase = Supabase.instance.client;

  ///Statuses
  ///[requested, accepted, ongoing, completed, cancelled]
  ///
  // final List<List<int>> _bookingDetails = [];

  int _passengerCapacity = 0;
  List<int> _bookingIDs = [];

  int get passengerCapacity => _passengerCapacity;
  List<int> get bookingIDs => _bookingIDs;

  void setPassengerCapacity(int value) {
    _passengerCapacity = value;
    notifyListeners();
  }

  void setBookingIDs(List<int> value) {
    // _bookingIDs.addAll(value);
    _bookingIDs = value;
    notifyListeners();
  }

  /// method to get all booking IDs in the DB
  Future<void> getBookingIDs(BuildContext context) async {
    try {
      final driverID = context.read<DriverProvider>().driverID;

      final response = await supabase
          .from('bookings')
          .select(
              'booking_id, passenger_id, pickup_lat, pickup_lng, dropoff_lat, dropoff_lng')
          .eq('driver_id', driverID)
          .eq('ride_status', 'requested');   // Ride Statuses: [requested, accepted, ongoing, completed, cancelled]

      debugPrint('Driver ID: $driverID');

      if (response.isNotEmpty) {
        List<int> ids =
            response.map<int>((record) => record['booking_id'] as int).toList();

        // //method to check if the booking ID is already in the list
        // flawed, high change of out of bounds error
        // for (int i = 0; i < bookingIDs.length; i++) {
        //   if (ids[i] == bookingIDs[i]) {
        //     ids.removeAt(i);
        //   }
        // }

        // Ensure no duplicates (extra safeguard)
        ids = ids.toSet().toList();

        // replace with currently active bookings
        setBookingIDs(ids);
      } else {
        // clear list if no active bookings
        setBookingIDs([]);
      }

      if (kDebugMode) {
        print('Booking IDs: $_bookingIDs');
        print('Booking response: $response');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('Error fetching booking IDs: $e');
        print('Booking IDs Stack Trace: $stackTrace');
      }
    }
  }
}
