# `lib/domain`

Business rules – pure Dart, no framework imports.

Currently contains:
* `services/` – stateless helpers like `BookingFilterService`,
  `PassengerCapacity`.

You may add **use-cases** (interactors) here later (`AcceptBookingUseCase`,
`GetNearestPassengerUseCase`, etc.).

Rules
1. Depends only on `common`.
2. No Flutter, no Supabase. 

### Recent updates
- `PolylineService` centralizes Google Routes API calls and decoding
- `LocationTracker` exposes a singleton `locationStream` without UI deps
- `PassengerCapacity` now guards manual decrement vs booked seats and persists manual counts locally for restart safety