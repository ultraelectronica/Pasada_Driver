# Map Feature Module

This module follows clean architecture principles with proper separation of concerns.

## Structure

### `/models/`
- `map_state.dart` - State models for map initialization and configuration
- Contains immutable state classes and enums

### `/utils/`
- `map_constants.dart` - Constants and utility functions for map operations
- Distance calculations, thresholds, UI constants

### `/widgets/`
- `map_page.dart` - Main map page (refactored from 1,148-line google_map.dart)
- `google_map_view.dart` - Pure Google Map widget
- `custom_location_button.dart` - Custom location button component  
- `map_loading_view.dart` - Loading state display
- `map_error_view.dart` - Error state display
- `map_status_indicator.dart` - Status indicator during initialization

## Architecture

### Separation of Concerns
- **UI Layer**: Widgets handle only rendering and user input
- **Business Logic**: Moved to domain services (`PolylineService`)
- **State Management**: Clean state models with providers
- **Utilities**: Pure functions in common layer

### Key Improvements
1. **Reduced Complexity**: Main map file reduced from 1,148 to ~300 lines
2. **Single Responsibility**: Each widget has one clear purpose  
3. **Testable**: Business logic separated from Flutter widgets
4. **Maintainable**: Clear folder structure and naming conventions
5. **Consistent**: Follows same patterns as other feature modules
6. **Throttled updates**: Camera/polyline/DB location updates are throttled to reduce API/DB load
7. **Debounced polylines**: Polyline generation is guarded to avoid concurrent/in-flight requests and enforces a minimum interval
7. **Correct distance math**: Haversine calculation corrected; thresholds centralized in `MapConstants`

### Dependencies
- Domain: `polyline_service.dart`, `location_tracker.dart`
- Common: `network_utility.dart` (moved from Map/ folder)
- Providers: `map_provider.dart`, `driver_provider.dart`, `passenger_provider.dart`

### Route handling and polylines
- `MapProvider.getRouteCoordinates(routeId)` loads route geometry from `official_routes` and caches results.
- `MapProvider.setRouteById(routeId: ..., driverProv: ...)` centralizes route switching; updates local state first, then persists to backend.
- `MapProvider.generatePolyline()` is debounced and rejects overlapping calls to prevent UI flicker and API overuse.

### Notes
- `GoogleMapView` exposes `onCameraMoveStarted/onCameraIdle` so the page can pause auto-follow during manual panning
- `MapProvider.initialize` returns `bool` for clear error signaling to the page

## Usage

```dart
// Use the new MapPage instead of MapScreen
import 'package:pasada_driver_side/presentation/pages/map/map_page.dart';

MapPage(
  initialLocation: LatLng(lat, lng),
  finalLocation: LatLng(lat, lng),
  bottomPadding: 0.13,
)
```

## Migration

The old `MapScreen` class from `lib/Map/google_map.dart` has been refactored into:
- Main page logic: `map_page.dart`
- Business logic: `domain/services/polyline_service.dart`  
- UI components: Individual widget files
- State management: `models/map_state.dart`
- Utilities: `utils/map_constants.dart`