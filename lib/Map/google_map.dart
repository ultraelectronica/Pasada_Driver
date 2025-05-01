// ignore_for_file: non_constant_identifier_names

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:pasada_driver_side/Map/network_utility.dart';
import 'package:pasada_driver_side/Database/driver_provider.dart';
import 'package:pasada_driver_side/UI/message.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pasada_driver_side/Database/map_provider.dart';

class MapScreen extends StatefulWidget {
  final LatLng? initialLocation, finalLocation, currentLocation;
  final double bottomPadding;

  const MapScreen({
    super.key,
    this.initialLocation,
    this.finalLocation,
    this.currentLocation,
    this.bottomPadding = 0.13,
  });

  @override
  MapScreenState createState() => MapScreenState();
}

class MapScreenState extends State<MapScreen> {
  LatLng? currentLocation;
  LocationData? locationData;
  final Location location = Location();
  LatLng? _lastPolylineUpdateLocation; // Tracks last polyline update location
  final GlobalKey<MapScreenState> mapScreenKey = GlobalKey<MapScreenState>();

  // <<-- POLYLINES -->>
  Map<PolylineId, Polyline> polylines = {};

  // <<-- MARKERS -->>
  Set<Marker> markers = {};

  // <<-- DEFAULT LOCATIONS -->>

  /// Novaliches to Malinta
  static LatLng StartingLocation = const LatLng(14.721957951314671, 121.03660698876655); // savemore novaliches
  static LatLng IntermediateLocation1 = const LatLng(14.711095415234702, 120.99311060642324); // VGC bus terminal
  static LatLng IntermediateLocation2 = const LatLng(14.701160828529744, 120.98308262221344);
  static LatLng EndingLocation = const LatLng(14.693028415325333, 120.96837623290318); // valenzuela peoples park

  static LatLng? PickupLocation;

  // LatLng? StartingLocation;
  // LatLng? IntermediateLocation1;
  // LatLng? IntermediateLocation2;
  // LatLng? EndingLocation;

  /// Malinta to Novaliches
  // LatLng StartingLocation =
  //     const LatLng(14.694370509154878, 120.97003705410779);

  // LatLng IntermediateLocation1 =
  //     const LatLng(14.703456631743745, 120.98572633206065);

  // LatLng IntermediateLocation2 =
  //     const LatLng(14.7111498286728, 120.99310735112863);

  // LatLng EndingLocation = const LatLng(14.721876764899815, 121.0366831829442);

  final Completer<GoogleMapController> _mapControllerCompleter = Completer();
  final String apiKey = dotenv.env['ANDROID_MAPS_API_KEY']!;

  // <<-- DRIVER ROUTE -->>
  LatLng? initialLocation, finalLocation;
  Marker? initialMarker, finalMarker;

  // animation ng location to kapag pinindot yung custom my location button
  bool isAnimatingLocation = false;

  // Minimum distance in meters to update polyline
  final double _minDistanceForPolylineUpdate = 10;

  // Flag to prevent redundant route coordinate fetches
  bool _routeCoordinatesLoaded = false;

  @override
  void initState() {
    super.initState();
    getLocationUpdates();
  }

  void getPickUpLocation() {
    PickupLocation = context.read<MapProvider>().pickupLocation;
    debugPrint('Pickup Location: $PickupLocation');
    setState(() {});
    _initializeMarkers();
  }

  Future<void> getRouteCoordinates() async {
    if (_routeCoordinatesLoaded) return;

    try {
      final mapProvider = context.read<MapProvider>();
      final driverProvider = context.read<DriverProvider>();

      // Make sure we have a valid route ID
      if (driverProvider.routeID <= 0) {
        await driverProvider.getDriverRoute();
      }

      // Wait for the route coordinates to be fetched
      await mapProvider.getRouteCoordinates(driverProvider.routeID);

      debugPrint('Is location loaded: ${mapProvider.currentLocation != null}');

      // Update current location in MapProvider if we have it
      if (currentLocation != null && mapProvider.currentLocation == null) {
        mapProvider.setCurrentLocation(currentLocation!);
      }

      // Use the static locations from MapProvider if available
      if (mapProvider.intermediateLoc1 != null) {
        debugPrint('Intermediate Location 1: ${mapProvider.intermediateLoc1}');
        IntermediateLocation1 = mapProvider.intermediateLoc1!;
      }

      if (mapProvider.intermediateLoc2 != null) {
        debugPrint('Intermediate Location 2: ${mapProvider.intermediateLoc2}');
        IntermediateLocation2 = mapProvider.intermediateLoc2!;
      }

      if (mapProvider.endingLocation != null) {
        debugPrint('Ending Location: ${mapProvider.endingLocation}');
        EndingLocation = mapProvider.endingLocation!;
      }

      // // Initialize markers with the route points
      // _initializeMarkers();

      // Generate polyline once coordinates are loaded
      if (currentLocation != null) {
        generatePolylineBetween(currentLocation!, IntermediateLocation1, IntermediateLocation2, EndingLocation);
      } else {
        generatePolylineBetween(StartingLocation, IntermediateLocation1, IntermediateLocation2, EndingLocation);
      }

      _routeCoordinatesLoaded = true;
    } catch (e, stackTrace) {
      debugPrint('Error loading route coordinates: $e');
      debugPrint('Stack Trace: $stackTrace');
      _routeCoordinatesLoaded = false;
    }
  }

  Future<void> getLocationUpdates() async {
    try {
      // Get current location first
      LocationData locationData = await location.getLocation();

      if (mounted) {
        setState(() {
          currentLocation = LatLng(locationData.latitude!, locationData.longitude!);
        });

        // Update MapProvider with current location
        context.read<MapProvider>().setCurrentLocation(currentLocation!);
      }

      // Now load route coordinates with the current location available
      if (mounted) {
        debugPrint('Getting route coordinates');
        await getRouteCoordinates();
      }

      if (mounted) {
        // Generate initial polyline if not already done
        if (_lastPolylineUpdateLocation == null && currentLocation != null) {
          generatePolylineBetween(currentLocation!, IntermediateLocation1, IntermediateLocation2, EndingLocation);
          _lastPolylineUpdateLocation = currentLocation;
        }

        // // Make sure markers are initialized
        // _initializeMarkers();
      }

      // Listen to location updates
      location.onLocationChanged.listen((LocationData newLocation) {
        if (!mounted) return;
        if (newLocation.latitude != null && newLocation.longitude != null) {
          //save location to DB
          final String driverID = context.read<DriverProvider>().driverID;
          _updateDriverLocationToDB(driverID, newLocation);

          // Convert LocationData to LatLng
          final newLatLng = LatLng(newLocation.latitude!, newLocation.longitude!);

          // Only update UI state if location actually changed
          if (currentLocation == null || currentLocation!.latitude != newLatLng.latitude || currentLocation!.longitude != newLatLng.longitude) {
            setState(() {
              currentLocation = newLatLng;

              // Update current location marker
              markers.removeWhere((marker) => marker.markerId == const MarkerId('CurrentLocation'));
              markers.add(
                Marker(
                  markerId: const MarkerId('CurrentLocation'),
                  position: newLatLng,
                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
                  infoWindow: const InfoWindow(title: 'Current Location'),
                  zIndex: 2, // Higher zIndex to ensure it's on top of other markers
                ),
              );
            });
          }

          // Check user is far enough to update polyline
          if (_shouldUpdatePolyline(newLatLng)) {
            generatePolylineBetween(newLatLng, IntermediateLocation1, IntermediateLocation2, EndingLocation);
            _lastPolylineUpdateLocation = newLatLng;
          }

          getPickUpLocation();

          // Move the camera to new location
          animateToLocation(newLatLng);

          // Check if near EndingLocation
          _checkDestinationReached(newLatLng);
        }
      });
    } catch (e) {
      ShowMessage().showToast('An error occurred while fetching the location. $e');
    }
  }

  // Helper method to decide if polyline needs updating
  bool _shouldUpdatePolyline(LatLng newLocation) {
    if (_lastPolylineUpdateLocation == null) return true;

    double distanceMoved = Geolocator.distanceBetween(
      newLocation.latitude,
      newLocation.longitude,
      _lastPolylineUpdateLocation!.latitude,
      _lastPolylineUpdateLocation!.longitude,
    );

    // check if the distance moved is greater than the minimum distance
    if (kDebugMode && distanceMoved > _minDistanceForPolylineUpdate) {
      // Don't call getRouteCoordinates() here - it's too frequent and causes issues
      debugPrint('Distance moved: $distanceMoved meters - updating polyline');
    }

    return distanceMoved > _minDistanceForPolylineUpdate;
  }

  // Helper method to check if destination is reached
  void _checkDestinationReached(LatLng currentPos) {
    double distanceInMeters = Geolocator.distanceBetween(
      currentPos.latitude,
      currentPos.longitude,
      EndingLocation.latitude,
      EndingLocation.longitude,
    );

    if (kDebugMode) {
      print('Distance to end: $distanceInMeters meters');
    }

    // If distance is less than 40 meters, consider it reached
    if (distanceInMeters < 40 && mounted) {
      context.read<MapProvider>().changeRouteLocation(context);
    }
  }

  // <<-- UPDATE LOCATION TO DATABASE -->>
  Future<void> _updateDriverLocationToDB(String driverID, LocationData newLocation) async {
    try {
      // Convert LocationData to WKT (Well-Known Text) Point format
      final wktPoint = 'POINT(${newLocation.longitude} ${newLocation.latitude})';

      final response = await Supabase.instance.client
          .from('driverTable')
          .update({
            'current_location': wktPoint,
          })
          .eq('driver_id', driverID)
          .select('current_location');

      if (kDebugMode) {
        print('Location updated to DB (WKT sent): ${response[0]['current_location']}');
      }
    } catch (e) {
      Fluttertoast.showToast(msg: 'Error updating location to DB: $e');
      if (kDebugMode) {
        print('Error updating location to DB: $e');
      }
    }
  }

  // <<-- ANIMATION -->>
  // animate yung camera papunta sa current location ng user
  Future<void> animateToLocation(LatLng target) async {
    final GoogleMapController controller = await _mapControllerCompleter.future;
    controller.animateCamera(
      CameraUpdate.newCameraPosition(CameraPosition(
        target: target,
        zoom: 16,
      )),
    );
  }

  // <<-- POLYLINES -->>
  Future<void> generatePolylineBetween(LatLng start, LatLng intermediate1, LatLng intermediate2, LatLng destination) async {
    try {
      final String apiKey = dotenv.env['ANDROID_MAPS_API_KEY']!;
      final polylinePoints = PolylinePoints();

      // routes API request
      final uri = Uri.parse('https://routes.googleapis.com/directions/v2:computeRoutes');
      final headers = {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': apiKey,
        'X-Goog-FieldMask': 'routes.polyline.encodedPolyline',
      };
      final body = jsonEncode({
        'origin': {
          'location': {
            'latLng': {
              'latitude': start.latitude,
              'longitude': start.longitude,
            },
          },
        },
        "intermediates": [
          {
            "location": {
              "latLng": {"latitude": intermediate1.latitude, "longitude": intermediate1.longitude}
            }
          },
          {
            "location": {
              "latLng": {"latitude": intermediate2.latitude, "longitude": intermediate2.longitude}
            }
          },
        ],
        'destination': {
          'location': {
            'latLng': {
              'latitude': destination.latitude,
              'longitude': destination.longitude,
            },
          },
        },
        'travelMode': 'DRIVE',
        'polylineEncoding': 'ENCODED_POLYLINE',
        'computeAlternativeRoutes': true,
        'routingPreference': 'TRAFFIC_AWARE_OPTIMAL',
      });

      debugPrint('Request Body: $body');

      // ito naman na yung gagamitin yung NetworkUtility
      final response = await NetworkUtility.postUrl(uri, headers: headers, body: body);

      if (response == null) {
        ShowMessage().showToast('No response from the server');
        if (kDebugMode) {
          print('No response from the server');
        }
        return;
      }

      final data = json.decode(response);

      // add ng response validation
      if (data['routes'] == null || data['routes'].isEmpty) {
        ShowMessage().showToast('No routes found');
        if (kDebugMode) {
          print('No routes found');
        }
        return;
      }

      // null checking for nested properties
      final polyline = data['routes'][0]['polyline']?['encodedPolyline'];
      if (polyline == null) {
        ShowMessage().showToast('No polyline found in the response');
        if (kDebugMode) {
          print('No polyline found in the response');
        }
        return;
      }

      List<PointLatLng> decodedPolyline = polylinePoints.decodePolyline(polyline);
      List<LatLng> polylineCoordinates = decodedPolyline.map((point) => LatLng(point.latitude, point.longitude)).toList();

      if (mounted) {
        setState(() {
          polylines = {
            const PolylineId('route'): Polyline(
              polylineId: const PolylineId('route'),
              points: polylineCoordinates,
              color: const Color.fromARGB(255, 255, 35, 35),
              width: 8,
            )
          };
        });
      }

      if (kDebugMode) {
        print('Route generated successfully');
      }
    } catch (e) {
      ShowMessage().showToast('Error: ${e.toString()}');
      if (kDebugMode) {
        print('Error generating polyline: $e');
      }
    }
  }

  // Initialize markers with the route points
  void _initializeMarkers() {
    setState(() {
      markers.clear();

      // Add starting location marker
      markers.add(
        Marker(
          markerId: const MarkerId('StartingLocation'),
          position: StartingLocation,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: 'Starting Point'),
          zIndex: 1,
        ),
      );

      // // Add intermediate location 1 marker
      // markers.add(
      //   Marker(
      //     markerId: const MarkerId('IntermediateLocation1'),
      //     position: IntermediateLocation1,
      //     icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      //     infoWindow: const InfoWindow(title: 'Stop 1'),
      //     zIndex: 1,
      //   ),
      // );

      // // Add intermediate location 2 marker
      // markers.add(
      //   Marker(
      //     markerId: const MarkerId('IntermediateLocation2'),
      //     position: IntermediateLocation2,
      //     icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      //     infoWindow: const InfoWindow(title: 'Stop 2'),
      //     zIndex: 1,
      //   ),
      // );

      // Add ending location marker
      markers.add(
        Marker(
          markerId: const MarkerId('EndingLocation'),
          position: EndingLocation,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          infoWindow: const InfoWindow(title: 'Destination'),
          zIndex: 1,
        ),
      );

      // Add pickup location marker if available
      final mapProvider = context.read<MapProvider>();

      debugPrint('Pickup Location in _initializeMarkers: ${mapProvider.pickupLocation}');

      if (mapProvider.pickupLocation != null) {
        debugPrint('Adding pickup location marker: ${mapProvider.pickupLocation}');
        markers.add(
          Marker(
            markerId: const MarkerId('Pickup'),
            position: mapProvider.pickupLocation!,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
            infoWindow: const InfoWindow(title: 'Pickup Location'),
            zIndex: 1,
          ),
        );
      }
    });

    debugPrint('Markers initialized: ${markers.length}');
  }

  Set<Marker> buildMarkers() {
    final markers = <Marker>{};

    // Pickup marker
    if (widget.initialLocation != null) {
      markers.add(Marker(
        markerId: const MarkerId('pickup'),
        position: widget.initialLocation!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ));
    }

    // Dropoff marker
    if (widget.finalLocation != null) {
      markers.add(Marker(
        markerId: const MarkerId('dropoff'),
        position: widget.finalLocation!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ));
    }
    return markers;
  }

  @override
  Widget build(BuildContext context) {
    // Ensure route coordinates are loaded
    if (!_routeCoordinatesLoaded) {
      getRouteCoordinates();
    }

    // // Check if pickup location is available and refresh markers if needed
    // final mapProvider = Provider.of<MapProvider>(context);
    // if (mapProvider.pickupLocation != null) {
    //   debugPrint('Pickup Location in build: ${mapProvider.pickupLocation}');
    //   // Refresh markers to include pickup location
    //   _initializeMarkers();
    // }
    // getPickUpLocation();
    // debugPrint('Pickup Location in build: ${mapProvider.pickupLocation}');

    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
        body: Stack(
      children: [
        RepaintBoundary(
          child: currentLocation == null
              ? const Center(
                  child: CircularProgressIndicator(),
                )
              : GoogleMap(
                  onMapCreated: (controller) => _mapControllerCompleter.complete(controller),
                  initialCameraPosition: CameraPosition(
                    target: currentLocation!,
                    zoom: 15,
                    tilt: 45.0,
                  ),
                  markers: markers,
                  polylines: Set<Polyline>.of(polylines.values),
                  mapType: MapType.normal,
                  buildingsEnabled: false,
                  myLocationButtonEnabled: false,
                  indoorViewEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  trafficEnabled: false,
                  rotateGesturesEnabled: true,
                  myLocationEnabled: true,
                  padding: EdgeInsets.only(bottom: widget.bottomPadding),
                ),
        ),

        // CUSTOM MY LOCATION BUTTON
        Positioned(
          bottom: screenHeight * 0.025,
          right: screenWidth * 0.05,
          child: SizedBox(
            width: 50,
            height: 50,
            child: FloatingActionButton(
              onPressed: () {
                if (currentLocation != null) {
                  animateToLocation(currentLocation!);
                }
              },
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Icon(Icons.my_location, color: Colors.black, size: 26),
            ),
          ),
        ),
      ],
    ));
  }
}
