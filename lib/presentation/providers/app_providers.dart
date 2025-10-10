import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'driver/driver_provider.dart';
import 'map_provider.dart';
import 'package:pasada_driver_side/presentation/providers/quota/quota_provider.dart';
import 'passenger/passenger_provider.dart';
// import 'theme_provider.dart';

/// Root-level widget that wires up all `ChangeNotifierProvider`s used by the
/// presentation layer. By keeping provider registration in one place we avoid
/// cluttering `main.dart` and make it simpler to add/remove providers later.
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
      ],
      child: child,
    );
  }
}
