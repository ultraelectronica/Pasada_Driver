## Home Page Module

This directory contains the refactored Home feature for the Pasada driver app.

### Structure

- `controllers/`
  - `home_controller.dart`: Non-UI logic (proximity checks, periodic fetches, marker updates). Exposes read-only state for the UI.
- `models/`
  - `passenger_status.dart`: View model used to render bookings with distance/proximity flags.
- `widgets/`
  - `passenger_list_widget.dart`: Nearby/active bookings list
  - `seat_capacity_control.dart`: Encapsulated Standing/Sitting capacity control (manual vs booked-safe decrement)
  - `total_capacity_indicator.dart`: Total capacity display and refresh
  - `confirm_pickup_control.dart`, `complete_ride_control.dart`: Booking action wrappers with mounted checks, button-level loading/disable state
  - Floating buttons and status switch components
- `utils/`
  - `home_constants.dart`: Layout multipliers (positions/z-index)
  - `snackbar_utils.dart`: Unified snackbars for consistent UX

### Principles
- UI delegates logic to `HomeController` and providers
- Small widgets; no business logic inside widgets
- Avoid context across async gaps; use mounted checks
- Prefer provider `select` to minimize rebuilds

### Provider & network state
Home follows the global 3-state contract via providers. Example:

```dart
final capacity = context.select<DriverProvider,int>((p) => p.passengerCapacity);
final isLoading = context.select<PassengerProvider,bool>((p) => p.isLoading);
final error = context.select<PassengerProvider,String?>((p) => p.error);
```

### Capacity rules
- Manual increment/decrement uses `PassengerCapacity`
- Manual decrement is blocked when only booked capacity remains (safe-guard)
- Manual counts are persisted locally to survive restarts

### Map integration
`HomeController` owns selection, focusing the map, and rebuilding passenger markers via the `MapPageState` key.

### Recent changes
- React to booking stream changes immediately to refresh the passenger list without timer delay.
- Buttons show processing state and prevent double taps while booking mutations are in-flight.