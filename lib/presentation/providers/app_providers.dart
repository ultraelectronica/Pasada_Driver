import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'driver/driver_provider.dart';
import 'map_provider.dart';
import 'package:pasada_driver_side/presentation/providers/quota/quota_provider.dart';
import 'passenger/passenger_provider.dart';
import 'package:pasada_driver_side/presentation/providers/booking_receipt/booking_receipt_provider.dart';
import 'package:pasada_driver_side/data/repositories/supabase_booking_repository.dart';

/// Root-level widget that wires up all ChangeNotifierProviders 
class AppProviders extends StatelessWidget {
  final Widget child;

  const AppProviders({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DriverProvider()),
        ChangeNotifierProvider(create: (_) => MapProvider()),
        ChangeNotifierProvider(create: (_) => PassengerProvider()),
        ChangeNotifierProvider(create: (_) => QuotaProvider()),
        ChangeNotifierProvider(
          create: (_) => BookingReceiptProvider(
            bookingRepository: SupabaseBookingRepository(),
          ),
        ),
      ],
      child: child,
    );
  }
}
