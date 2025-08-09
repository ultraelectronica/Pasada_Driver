# Map Models

Contains immutable state models and data structures for the map feature.

## Files

### `map_state.dart`
- `MapInitState` enum - Tracks map initialization progress
- `MapState` class - Complete map state with location data
- `PolylineConfig` class - Configuration for polyline rendering

## Usage

```dart
import 'package:pasada_driver_side/presentation/pages/map/models/map_state.dart';

// Using MapState
final state = MapState(
  initState: MapInitState.initialized,
  currentLocation: LatLng(lat, lng),
  // ... other properties
);

// Updating state immutably
final newState = state.copyWith(
  currentLocation: newLocation,
);
```

These models provide type-safe, immutable state management for the map feature while maintaining clean separation from UI logic.