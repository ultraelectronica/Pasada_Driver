# Providers

`lib/presentation/providers` contains **framework-aware business logic** – plain `ChangeNotifier` classes that sit between the Flutter UI and domain layer.

Contract
--------
Every provider must implement:

```
bool get isLoading;   // true while an async task is running
Failure? get error;   // null on success; use `error?.message` to show text
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
  onPressed: () => context.read<DriverProvider>().updateStatusToDB('Online'),
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

### Recent changes
- `DriverProvider.updateStatusToDB` no longer requires `BuildContext` and validates/throttles updates
- `MapProvider.initialize` returns `bool` for clearer error propagation to UI
- `MapProvider.setRouteById({required int routeId, required DriverProvider driverProv})` is the single entry point for route switching; updates local state and persists to backend
- `MapProvider.getRouteCoordinates(routeId)` caches route geometry (LRU-like, up to 20 entries)
- `MapProvider.generatePolyline()` is debounced and ignores overlapping calls to avoid flicker and reduce API usage