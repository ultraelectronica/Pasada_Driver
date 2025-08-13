# pasada_driver_side

PasadaDriverSide

## Getting Started

Pasada Driver is an application built for drivers of modern jeepneys.

# Features
- Real-time location tracking.  
- Driver status (online, offline, idling, driving).  
- Passenger Booking Manager (accepts, picks up, drops off passenger bookings).  
- Manual override of vehicle capacity (for non-Pasada App users).  
- Displays real-time and urgent bookings assigned to the driver.

## Recent UX improvements
- Optimistic booking updates: UI reflects Confirm Pickup / Complete Ride actions immediately, then confirms with backend.
- Safe rollbacks: If capacity update fails after a status change, booking state is reverted and an error snackbar is shown.
- Action button feedback: Confirm/Complete buttons show a spinner and disable while processing, preventing double taps.
- Faster list refresh: Home now reacts to booking stream changes instantly (no lag waiting for periodic timers).