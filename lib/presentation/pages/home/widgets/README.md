### Widgets

Reusable UI components that compose the Home screen.

Key widgets:
- `passenger_list_widget.dart` – Top of screen list for nearest/active bookings
- `seat_capacity_control.dart` – Standing/Sitting capacity with manual vs booked safety checks
- `total_capacity_indicator.dart` – Total capacity display with refresh
- `confirm_pickup_control.dart`, `complete_ride_control.dart` – Booking action wrappers using providers and mounted checks
- `confirm_pickup_control.dart`, `complete_ride_control.dart` – Booking action wrappers using providers and mounted checks; now stateful to drive button `isLoading`/`isEnabled`.
- Floating buttons: reset capacity button, route button

Guidelines:
- Stateless where possible
- No business logic: call controller/providers instead
- Expose `isLoading`/`isEnabled` signals on action buttons to give immediate feedback and prevent rapid double taps

#### FloatingRouteButton
- Disabled while driver is Driving or when there are active bookings (accepted/ongoing).
- Shows a tooltip explaining the disabled state.
- Opens a bottom sheet to choose from server-provided official routes.