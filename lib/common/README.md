# `lib/common`

Framework-free utilities that **every other layer can depend on**.
Anything here must be pure Dart (no Flutter, no Supabase).

Contents
| Folder | What’s inside |
|--------|---------------|
| `constants/` | Static strings & numbers (e.g. `BookingConstants`) |
| `config/`    | Runtime knobs such as distance/time thresholds (`AppConfig`) |
| `exceptions/`| Typed error classes for uniform error handling |
| `geo/`       | Distance, bearing & location validators |
| `logging/`   | `BookingLogger` – console + file logging |
| `utils/`     | Misc helpers (`Result`, etc.) |

Rule of thumb: if code **could** be published as a stand-alone Dart package,
put it in `common`. 