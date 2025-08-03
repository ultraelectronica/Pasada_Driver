# Map module (driver side)

This folder implements **all Google-Map related functionality** for the
Pasada Driver app. After the 2024-05 refactor it follows the same
clean-architecture layering used in the rest of `lib/` –
only the widget lives here, the logic has moved to `presentation` and
`domain` packages.

```
lib/
 ├── Map/                 # 🗺  This folder (UI only)
 │   ├── google_map.dart  # <- MapScreen widget
 │   └── README.md        # ← you are here
 ├── presentation/
 │   └── providers/
 │       └── map_provider.dart   # state & marker / polyline logic
 └── domain/
     └── services/
         ├── route_service.dart  # Google Routes API wrapper
         └── location_tracker.dart  # Stream of LocationData
```

> **Why keep the capitalised `Map/` folder?**  It is a legacy artefact that
> will be renamed to `map/` once all references are updated.  For now we
> isolate UI-only code here so nothing inside needs importing by lower layers.

## Responsibilities
1. **Render** the `GoogleMap` widget.
2. **Consume** state from `MapProvider` – markers, polylines, dark-mode style.
3. **Dispatch** user actions upward ("my-location" FAB, custom markers).
4. **Camera animation** convenience (`animateToLocation`).

Everything else (locations, DB writes, route fetching, marker building) now
resides outside this folder.

## Lifecycle
```
MapScreen.initState → _initializeMap()
  ├─ MapProvider.initialize()       // async bootstrap
  │   ├─ LocationTracker.current()  // one-shot GPS
  │   ├─ getRouteCoordinates()      // Supabase → official_routes
  │   ├─ generatePolyline()         // RouteService → Google Routes API
  │   └─ getBookingRequestsID()     // PassengerProvider (pickup)
  └─ _startLocationTracking()       // LocationTracker.stream → updates
```

## Testing
* `test/presentation/map_provider_test.dart` – verifies marker generation.
* Add more tests in `test/domain/` for `RouteService` as needed.

Widget-only code is kept minimal, so most logic can be unit-tested without a
widget tree.

## Adding a feature
1. Extend `MapProvider` with new state / intent (eg. traffic toggling).
2. Trigger business work from provider or a new domain service.
3. Reflect state in `google_map.dart` via `context.watch` / `select`.
4. Cover the provider/service with unit tests.

---
*Last updated: 2024-05-22*
