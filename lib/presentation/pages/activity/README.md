### Activity Page

Contains the driver activity history / logs UI and related widgets. 

### Provider pattern
ActivityPage listens to `PassengerProvider` via a `Consumer` and renders:
1. `CircularProgressIndicator` when `provider.isLoading`
2. `ErrorRetryWidget` when `provider.error != null`
3. Stat cards & booking list otherwise.

### Constants
All paddings, spacings and colors that were magic numbers are now defined in `utils/activity_constants.dart`. 