## Home Page Module

This directory contains the refactored Home screen for the Pasada driver application.

Sub-folders:

* `models/`  – data classes used only by the Home module (e.g. `PassengerStatus`).
* `widgets/` – small stateless/stateful widgets that compose the UI (floating buttons, list, etc.).
* `utils/`    – tiny pure-Dart helpers (e.g. snackbar helper).

The goal is to keep each file focused and below ~300 LOC. 