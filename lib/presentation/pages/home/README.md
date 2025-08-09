## Home Page Module

This directory contains the refactored Home screen for the Pasada driver application.

Sub-folders:

* `models/`  – data classes used only by the Home module (e.g. `PassengerStatus`).
* `widgets/` – small stateless/stateful widgets that compose the UI (floating buttons, list, etc.).
* `utils/`    – tiny pure-Dart helpers (e.g. snackbar helper).

The goal is to keep each file focused and below ~300 LOC. 

### Provider & network state

HomePage follows the global 3-state contract:

```dart
final passengerCapacity = context.select<DriverProvider,int>((p) => p.passengerCapacity);
final isBookingLoading = context.select<PassengerProvider,bool>((p) => p.isLoading);
final bookingError = context.select<PassengerProvider,String?>((p) => p.error);
```

UI rendering logic (simplified):
```dart
if (isBookingLoading) return const Center(child: CircularProgressIndicator());
if (bookingError != null) {
  return ErrorRetryWidget(message: bookingError!, onRetry: () => fetchBookings(context));
}
return PassengerListWidget(passengers: _nearbyPassengers);
```

### Constants
All layout numbers live in `utils/home_constants.dart`. New numbers must be added there – no in-line `0.05` multipliers. 