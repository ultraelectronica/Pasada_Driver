# Providers

`lib/presentation/providers` contains **framework-aware business logic** – plain `ChangeNotifier` classes that sit between the Flutter UI and domain layer.

Contract
--------
Every provider must implement:

```
bool get isLoading;   // true while an async task is running
String? get error;    // null on success; human-readable message on failure
```

and call `notifyListeners()` whenever public state changes.

Directory overview
------------------
* **driver/** `driver_provider.dart` – Driver profile, status, passenger counts, secure-storage bootstrapping.
* **map_provider.dart** – Live route data, GPS location, and route-switching.
* **passenger/** `passenger_provider.dart` – Booking stream, processing & completed stats.

Usage pattern
-------------
```dart
final capacity = context.select<DriverProvider,int>((p) => p.passengerCapacity);

ElevatedButton(
  onPressed: () => context.read<DriverProvider>().updateStatusToDB('Online', context),
  child: const Text('Go Online'),
);
```

Testing
-------
Because providers have **no UI code**, they can be unit-tested directly:
```dart
final prov = DriverProvider();
prov.setLoading(true);
expect(prov.isLoading, true);
``` 