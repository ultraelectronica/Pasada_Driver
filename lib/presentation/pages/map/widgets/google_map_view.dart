import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:pasada_driver_side/presentation/providers/map_provider.dart';
// import 'package:pasada_driver_side/presentation/providers/theme_provider.dart';

import 'package:pasada_driver_side/presentation/pages/map/utils/map_constants.dart';

/// Pure map widget responsible only for rendering the Google Map
/// Separated from business logic and state management
class GoogleMapView extends StatefulWidget {
  final LatLng initialLocation;
  final double bottomPadding;
  final Function(GoogleMapController)? onMapCreated;
  final VoidCallback? onCameraMoveStarted;
  final VoidCallback? onCameraIdle;
  final bool applyMapStyle;

  const GoogleMapView({
    super.key,
    required this.initialLocation,
    this.bottomPadding = MapConstants.bottomPaddingDefault,
    this.onMapCreated,
    this.onCameraMoveStarted,
    this.onCameraIdle,
    this.applyMapStyle = true,
  });

  @override
  State<GoogleMapView> createState() => _GoogleMapViewState();
}

class _GoogleMapViewState extends State<GoogleMapView> {
  final Completer<GoogleMapController> _mapControllerCompleter = Completer();
  String? _darkMapStyle;

  @override
  void initState() {
    super.initState();
    _loadMapStyle();
  }

  /// Load dark map style from assets
  void _loadMapStyle() {
    rootBundle.loadString(MapConstants.darkMapStylePath).then((string) {
      if (mounted) {
        setState(() {
          _darkMapStyle = string;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: GoogleMap(
        onMapCreated: (controller) {
          _mapControllerCompleter.complete(controller);
          widget.onMapCreated?.call(controller);
        },
        onCameraMoveStarted: widget.onCameraMoveStarted,
        onCameraIdle: widget.onCameraIdle,
        initialCameraPosition: CameraPosition(
          target: widget.initialLocation,
          zoom: MapConstants.defaultZoom,
          tilt: MapConstants.defaultTilt,
        ),
        style: _darkMapStyle,
        markers: context.watch<MapProvider>().markers,
        polylines: _buildPolylines(context),
        mapType: MapType.normal,

        // Map configuration
        buildingsEnabled: true,
        myLocationButtonEnabled: false, // Using custom button
        indoorViewEnabled: false,
        mapToolbarEnabled: false,
        trafficEnabled: false,

        // Gesture configuration
        rotateGesturesEnabled: true,
        tiltGesturesEnabled: true,
        scrollGesturesEnabled: true,
        zoomGesturesEnabled: true,
        zoomControlsEnabled: false,

        myLocationEnabled: true,
        padding: EdgeInsets.only(bottom: widget.bottomPadding),
      ),
    );
  }

  /// Build polylines from provider state
  Set<Polyline> _buildPolylines(BuildContext context) {
    final coords = context.watch<MapProvider>().polylineCoords;
    if (coords.isEmpty) return {};

    return {
      Polyline(
        polylineId: const PolylineId('route'),
        points: coords,
        color: const Color.fromARGB(255, 250, 242, 2),
        width: 8,
      )
    };
  }

  /// Get the map controller for external use
  Future<GoogleMapController> get mapController =>
      _mapControllerCompleter.future;
}
