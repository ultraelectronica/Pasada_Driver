import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapScreen extends StatefulWidget {
  final LatLng? initialLocation, finalLocation;
  const MapScreen({super.key, this.initialLocation, this.finalLocation});
  @override
  MapScreenState createState() => MapScreenState();
}

class MapScreenState extends State<MapScreen> {
  LatLng? currentLocation; // Location Data
  final Completer<GoogleMapController> mapController = Completer();

  void onMapCreated(GoogleMapController controller) {
    mapController.complete(controller);
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: RepaintBoundary(
        child: currentLocation == null
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : GoogleMap(
                onMapCreated: (controller) =>
                    mapController.complete(controller),
                initialCameraPosition: CameraPosition(
                  target: currentLocation!,
                  zoom: 15,
                ),
                // markers: {
                //   Marker(
                //     markerId: const MarkerId('m1'),
                //     position: currentLocation!,
                //   ),
                // },
                mapType: MapType.normal,
                buildingsEnabled: false,
                myLocationButtonEnabled: false,
                indoorViewEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                trafficEnabled: false,
                rotateGesturesEnabled: true,
                myLocationEnabled: true,
                padding: EdgeInsets.only(
                  bottom: screenHeight * 0.15,
                  right: screenWidth * 0.1,
                ),
              ),
      ),
    );
  }
}