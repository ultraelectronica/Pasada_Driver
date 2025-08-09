# lib/presentation

UI widgets and state-management layer for the Pasada Driver app. Everything that touches Flutter’s `BuildContext` lives here; lower layers (`domain`, `data`, `common`) stay framework-agnostic.

Directory map
-------------
```
lib/presentation/
├── providers/   # ChangeNotifier classes (pure logic – no UI)
├── pages/       # Feature modules (one folder per screen)
│   ├── home/
│   ├── activity/
│   ├── profile/
│   ├── login/
│   └── start/
└── widgets/     # Cross-feature reusable UI atoms (e.g. ErrorRetryWidget)
```

State-management conventions
----------------------------
Every provider **must** expose these two fields so widgets can implement a "3-state" UI (loading ▸ error ▸ data):

* `bool isLoading`    – `true` while an async operation is in flight.
* `Failure? error`   – `null` when healthy, otherwise a rich error object containing `message`, `type`, and optional exception.
  * Use `error?.message` when you need the display string.

Widget skeleton:
```dart
if (provider.isLoading) {
  return const Center(child: CircularProgressIndicator());
}
if (provider.error != null) {
  return ErrorRetryWidget(message: provider.error!, onRetry: () {...});
}
return DataView();
```

Performance rules
-----------------
1. Use `context.select`, `Selector`, or `Consumer` to listen only to the fields you actually need.
2. Use `context.read` for mutations.
3. Never store a `BuildContext` across an `await` boundary.

See the READMEs inside `pages/` and `providers/` for page-specific notes. 