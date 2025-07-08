# Pasada Driver – `lib/`

This directory holds **all runnable Dart/Flutter code** for the driver-side
app.  The layout follows a clean-architecture layering so that UI sits on top
of business logic, which in turn sits on top of data access and framework-free
utilities.

```
lib/
  common/         # Pure-Dart helpers (no Flutter)
  data/           # Repositories & data-sources (Supabase, storage …)
  domain/         # Business rules and services
  presentation/   # Providers, state-management, Flutter-specific code
  NavigationPages/# UI pages (legacy – being refactored)
  Map/            # Google Maps widget & helpers
  Services/       # External integrations (auth, permissions)
  UI/             # Shared styling constants/helpers
```

Dependency rule (inner -> outer):

```
common  ← data  ← domain  ← presentation  ← UI pages/widgets
```

*Inner layers never import outer layers.*

## Conventions
* Lowercase snake_case folder names (legacy folders will be renamed over time).
* Each primary folder has its own `README.md` summarising contents and rules.
* Pure-Dart code (no Flutter) lives in `common` or `domain`.
* Keep providers (`presentation`) separate from UI widgets to allow unit
  testing without a widget tree.