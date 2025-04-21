import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:http/http.dart' as http;

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late GoogleMapController mapController;
  LocationData? _currentLocation;
  late Location _location;
  final LatLng _endPosition = const LatLng(37.42796133580664, -122.085749655962);
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  PolylinePoints polylinePoints = PolylinePoints();

  @override
  void initState() {
    super.initState();
    _location = Location();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) {
        print('Location service disabled by user');
        return;
      }
    }

    PermissionStatus permission = await _location.hasPermission();
    if (permission == PermissionStatus.denied) {
      permission = await _location.requestPermission();
      if (permission != PermissionStatus.granted) {
        print('Location permission denied');
        return;
      }
    }

    try {
      // Get initial location
      _currentLocation = await _location.getLocation();
      _updateMarkersAndCamera();
      _getPolyline();

      // Listen to location updates (optional)
      _location.onLocationChanged.listen((LocationData newLocation) {
        setState(() {
          _currentLocation = newLocation;
          _updateMarkersAndCamera();
        });
      });
    } catch (e) {
      print('Error getting location: $e');
    }
  }

  void _updateMarkersAndCamera() {
    if (_currentLocation == null) return;

    final LatLng currentLatLng = LatLng(
      _currentLocation!.latitude!,
      _currentLocation!.longitude!,
    );

    setState(() {
      _markers
        ..clear()
        ..add(Marker(
          markerId: const MarkerId('current'),
          position: currentLatLng,
          infoWindow: const InfoWindow(title: 'Current Location'),
        ))
        ..add(Marker(
          markerId: const MarkerId('end'),
          position: _endPosition,
          infoWindow: const InfoWindow(title: 'Destination'),
        ));

      // Move camera to current location
      mapController.animateCamera(
        CameraUpdate.newLatLngZoom(currentLatLng, 14),
      );
    });
  }

  Future<void> _getPolyline() async {
    if (_currentLocation == null) return;

    const String apiKey = 'AIzaSyAPCBttjYmWAWgsVJlCdC6EBf2y0XpOHPo';
    const String url = 'https://routes.googleapis.com/directions/v2:computeRoutes';

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': apiKey,
          'X-Goog-FieldMask': 'routes.polyline',
        },
        body: json.encode({
          "origin": {
            "location": {
              "latLng": {
                "latitude": _currentLocation!.latitude,
                "longitude": _currentLocation!.longitude,
              }
            }
          },
          "destination": {
            "location": {
              "latLng": {
                "latitude": _endPosition.latitude,
                "longitude": _endPosition.longitude,
              }
            }
          },
          "travelMode": "DRIVE",
          "polylineEncoding": "ENCODED_POLYLINE",
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final String encodedPolyline = data['routes'][0]['polyline']['encodedPolyline'];
          List<LatLng> polylineCoordinates = polylinePoints
              .decodePolyline(encodedPolyline)
              .map((point) => LatLng(point.latitude, point.longitude))
              .toList();

          setState(() {
            _polylines.add(Polyline(
              polylineId: const PolylineId('route'),
              points: polylineCoordinates,
              color: Colors.blue,
              width: 5,
            ));
          });
        }
      } else {
        print('API Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Polyline Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    const LatLng fallbackPosition = LatLng(37.427961, -122.085749);

    return Scaffold(
      appBar: AppBar(title: const Text('Route Map')),
      body: _currentLocation == null
          ? const Center(child: CircularProgressIndicator())
          : GoogleMap(
              onMapCreated: (controller) => mapController = controller,
              initialCameraPosition: CameraPosition(
                target: _currentLocation != null
                    ? LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!)
                    : fallbackPosition,
                zoom: 14,
              ),
              markers: _markers,
              polylines: _polylines,
              myLocationEnabled: true,  // Show user's location dot
              myLocationButtonEnabled: true,
            ),
    );
  }
}