# Routes

Typed routing helpers that replace raw string route names.

* `app_routes.dart` – declares the `AppRoute` enum and an extension to convert each value to its string `path`.

Using an enum gives us compile-time safety and makes refactors effortless. 

## Note: Navigation vs Driver Routes
This directory covers app navigation routes (Flutter pages). The driver "route" (transport line/track) is a different concept and is managed by:

- UI: Floating route button and `RouteSelectionSheet`
- State: `MapProvider` (`setRouteById`, `getRouteCoordinates`)
- Map: `MapPage` and `PolylineService`

See these docs for details:
- Root README – Driver Route System
- Map module README – Route handling and polylines
- Providers README – `MapProvider` API and caching