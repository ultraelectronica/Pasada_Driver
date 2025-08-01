# Bootstrap

This directory contains application start-up helpers that run **before** any UI is rendered.

* `initialize_app.dart` – loads environment variables, initializes Supabase, checks permissions, and prepares frequently-used assets for precache.
* `app_bootstrap_error_screen.dart` – a minimal UI shown when the bootstrap phase crashes, giving the user a retry button and exposing the error when in debug mode.

> Everything in here should be **framework agnostic** (no Provider / routing logic) and run exactly once at app launch. 