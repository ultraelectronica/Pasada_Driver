# `lib/data`

“How we talk to storage.”  Repositories, models and low-level data sources.
No UI, no business rules.

Folders
| Folder | Purpose |
|--------|---------|
| `models/`       | Plain data objects with `fromJson` / `toJson` |
| `repositories/` | Abstract API + concrete Supabase/HTTP/Cache impls |
| `datasources/`  | (optional) very low-level API clients |

Guidelines
1. Do NOT import Flutter.
2. Throw typed exceptions (`common/exceptions`) – never raw PostgREST errors.
3. Keep network/SQL details inside this layer; upstream code works with typed
   models only. 