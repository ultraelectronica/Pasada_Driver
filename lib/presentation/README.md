# `lib/presentation`

Glue between UI widgets and business logic.

* `providers/` – `ChangeNotifier` classes and related helpers
  * `driver/` – driver profile & status
  * `passenger/` – booking stream and processing
  * `map_provider.dart` – live route/location
* Screens still live in `NavigationPages/`; they listen to these providers.

Rules
1. May import Flutter and lower layers (`domain`, `data`, `common`).
2. Keep providers/widget code separate to keep providers testable without UI. 