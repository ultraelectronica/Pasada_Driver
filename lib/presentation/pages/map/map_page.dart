import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:provider/provider.dart';
import 'package:pasada_driver_side/domain/services/location_tracker.dart';
import 'package:pasada_driver_side/presentation/providers/driver/driver_provider.dart';
import 'package:pasada_driver_side/presentation/providers/map_provider.dart';

import 'package:pasada_driver_side/presentation/pages/map/models/map_state.dart';
import 'package:pasada_driver_side/presentation/pages/map/utils/map_constants.dart';
import 'package:pasada_driver_side/presentation/pages/map/widgets/google_map_view.dart';
import 'package:pasada_driver_side/presentation/pages/map/widgets/custom_location_button.dart';
import 'package:pasada_driver_side/presentation/pages/map/widgets/map_loading_view.dart';
import 'package:pasada_driver_side/presentation/pages/map/widgets/map_error_view.dart';
import 'package:pasada_driver_side/presentation/pages/map/widgets/map_status_indicator.dart';

/// Refactored map page following clean architecture principles
/// Reduced from 1,148 lines to focused UI-only code
/// Business logic moved to domain services and providers
class MapPage extends StatefulWidget {
  final LatLng? initialLocation;
  final LatLng? finalLocation;
  final LatLng? currentLocation;
  final double bottomPadding;

  const MapPage({
    super.key,
    this.initialLocation,
    this.finalLocation,
    this.currentLocation,
    this.bottomPadding = MapConstants.bottomPaddingDefault,
  });

  @override
  State<MapPage> createState() => MapPageState();
}

class MapPageState extends State<MapPage> {
  // Clean state management using the MapState model
  MapState _mapState = const MapState();

  // Location tracking
  StreamSubscription<LocationData>? _locationSubscription;
  LatLng? _lastPolylineUpdateLocation;

  // Map controller for camera animations
  GoogleMapController? _mapController;

  // Throttling helpers
  DateTime? _lastPolylineUpdateAt;
  DateTime? _lastDbLocationUpdateAt;

  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      debugPrint('MapPage: Starting initialization sequence');
    }
    _initializeMap();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    super.dispose();
  }

  /// Single controlled initialization flow
  Future<void> _initializeMap() async {
    try {
      _updateMapState(_mapState.copyWith(
        initState: MapInitState.loadingLocation,
      ));

      // Delegate heavy work to provider
      final ok = await context.read<MapProvider>().initialize(context);
      if (!ok) {
        throw Exception('Error: MapProvider initialization failed');
      }

      // Start location tracking once provider has data
      _startLocationTracking();

      _updateMapState(_mapState.copyWith(
        initState: MapInitState.initialized,
      ));
    } catch (e) {
      _updateMapState(_mapState.copyWith(
        initState: MapInitState.error,
        errorMessage: e.toString(),
      ));
    }
  }

  /// Update map state and trigger UI rebuild
  void _updateMapState(MapState newState) {
    if (!mounted) return;

    setState(() {
      _mapState = newState;
    });

    if (kDebugMode) {
      debugPrint('MapPage: State changed to ${newState.initState}');
      if (newState.errorMessage != null) {
        debugPrint('MapPage ERROR: ${newState.errorMessage}');
      }
    }
  }

  /// Start continuous location tracking
  void _startLocationTracking() {
    if (kDebugMode) {
      debugPrint('MapPage: Starting location tracking');
    }

    _locationSubscription = LocationTracker.instance.locationStream.listen(
      (LocationData newLocation) {
        if (!mounted) return;
        if (newLocation.latitude == null || newLocation.longitude == null)
          return;

        final newLatLng = LatLng(newLocation.latitude!, newLocation.longitude!);
        _handleLocationUpdate(newLatLng, newLocation);
      },
    );
  }

  /// Handle location updates with clean separation of concerns
  void _handleLocationUpdate(LatLng newLatLng, LocationData locationData) {
    // Update driver location in database via provider (throttled)
    final now = DateTime.now();
    final bool canWriteDb = _lastDbLocationUpdateAt == null ||
        now.difference(_lastDbLocationUpdateAt!) >=
            MapConstants.dbLocationUpdateMinInterval;
    if (canWriteDb) {
      context.read<DriverProvider>().updateCurrentLocation(locationData);
      _lastDbLocationUpdateAt = now;
    }

    // Update UI if moved significantly
    if (MapUtils.shouldUpdateUI(_mapState.currentLocation, newLatLng)) {
      _updateMapState(_mapState.copyWith(currentLocation: newLatLng));
      context.read<MapProvider>().setCurrentLocation(newLatLng);
    }

    // Update polyline if needed and map is initialized
    if (_mapState.isInitialized &&
        context.read<MapProvider>().endingLocation != null) {
      final bool movedEnough =
          MapUtils.shouldUpdatePolyline(_lastPolylineUpdateLocation, newLatLng);
      final bool intervalPassed = _lastPolylineUpdateAt == null ||
          now.difference(_lastPolylineUpdateAt!) >=
              MapConstants.polylineUpdateMinInterval;
      if (movedEnough && intervalPassed) {
        _updatePolylineForCurrentLocation(newLatLng);
        _lastPolylineUpdateAt = now;
      }
    }

    // Animate camera if not manually positioned
    if (!_mapState.isAnimatingLocation) {
      _animateToLocation(newLatLng);
    }

    // Check if destination reached
    if (context.read<MapProvider>().endingLocation != null) {
      _checkDestinationReached(newLatLng);
    }
  }

  /// Update polyline based on current location
  Future<void> _updatePolylineForCurrentLocation(LatLng currentLocation) async {
    final mapProv = context.read<MapProvider>();
    final end = mapProv.endingLocation;
    if (end == null) return;

    final List<LatLng> waypoints = [];
    if (mapProv.intermediateLoc1 != null)
      waypoints.add(mapProv.intermediateLoc1!);
    if (mapProv.intermediateLoc2 != null)
      waypoints.add(mapProv.intermediateLoc2!);

    await mapProv.generatePolyline(
      start: currentLocation,
      end: end,
      waypoints: waypoints.isEmpty ? null : waypoints,
    );

    _lastPolylineUpdateLocation = currentLocation;
  }

  /// Animate camera to specified location
  Future<void> _animateToLocation(LatLng target) async {
    if (_mapController == null) return;

    await _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: target,
          zoom: MapConstants.trackingZoom,
        ),
      ),
    );
  }

  /// Check if user has reached the destination
  void _checkDestinationReached(LatLng currentPos) {
    final end = context.read<MapProvider>().endingLocation;
    if (end == null) return;

    if (MapUtils.hasReachedDestination(currentPos, end)) {
      if (kDebugMode) {
        debugPrint('MapPage: Destination reached');
      }

      // Use post-frame callback to avoid state updates during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<MapProvider>().changeRouteLocation(context);

          // Update driver status
          final driverProvider = context.read<DriverProvider>();
          driverProvider.setIsDriving(false);
          driverProvider.updateStatusToDB('Online');
          driverProvider.setDriverStatus('Online');
        }
      });
    }
  }

  /// Handle custom location button press
  void _onLocationButtonPressed() {
    if (_mapState.currentLocation != null) {
      _animateToLocation(_mapState.currentLocation!);
    }
  }

  /// Handle map creation callback
  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (kDebugMode) {
      debugPrint('MapPage: Google Map created');
    }
  }

  void _onCameraMoveStarted() {
    if (!_mapState.isAnimatingLocation) {
      _updateMapState(_mapState.copyWith(isAnimatingLocation: true));
    }
  }

  void _onCameraIdle() {
    if (_mapState.isAnimatingLocation) {
      _updateMapState(_mapState.copyWith(isAnimatingLocation: false));
    }
  }

  // Public methods for external access (needed by HomePage)

  /// Animate camera to specified location (public method)
  Future<void> animateToLocation(LatLng target) async {
    await _animateToLocation(target);
  }

  /// Clear all passenger-related markers (preserves route markers)
  void clearPassengerMarkers() {
    if (!mounted) return;
    context.read<MapProvider>().clearPassengerMarkers();
  }

  /// Add custom marker with all options
  void addCustomMarker({
    required String id,
    required LatLng position,
    required BitmapDescriptor icon,
    required String title,
    double zIndex = 1.0,
    double alpha = 1.0,
  }) {
    if (!mounted) return;
    context.read<MapProvider>().addPassengerMarker(
          id: id,
          pos: position,
          icon: icon,
          title: title,
          zIndex: zIndex,
          alpha: alpha,
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Show loading view if location not yet available
          if (_mapState.currentLocation == null)
            const MapLoadingView()
          // Show error view if initialization failed
          else if (_mapState.hasError)
            MapErrorView(
              errorMessage: _mapState.errorMessage,
              onRetry: _initializeMap,
            )
          // Show map when location is available
          else
            GoogleMapView(
              initialLocation: _mapState.currentLocation!,
              bottomPadding: widget.bottomPadding,
              onMapCreated: _onMapCreated,
              onCameraMoveStarted: _onCameraMoveStarted,
              onCameraIdle: _onCameraIdle,
            ),

          // Custom location button
          CustomLocationButton(
            currentLocation: _mapState.currentLocation,
            onPressed: _onLocationButtonPressed,
            isVisible: _mapState.currentLocation != null,
          ),

          // Status indicator during initialization
          MapStatusIndicator(
            initState: _mapState.initState,
            isVisible: !_mapState.isInitialized && !_mapState.hasError,
          ),
        ],
      ),
    );
  }
}
