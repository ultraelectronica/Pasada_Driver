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
import 'package:pasada_driver_side/Database/passenger_provider.dart';

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
  LatLng? _lastPolylineUpdateLocation;
  final GlobalKey<MapScreenState> mapScreenKey = GlobalKey<MapScreenState>();

  // <<-- POLYLINES -->>
  Map<PolylineId, Polyline> polylines = {};

  // <<-- MARKERS -->>
  Set<Marker> markers = {};

  // Remove static default locations
  LatLng? _startingLocation;
  LatLng? _intermediateLocation1;
  LatLng? _intermediateLocation2;
  LatLng? _endingLocation;
  LatLng? _pickupLocation;

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
    // Reset the route coordinates loaded flag when initializing
    _routeCoordinatesLoaded = false;
    getLocationUpdates();

    // Add a small delay before checking for pickup location
    // Increase delay to ensure route data is loaded first
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        getRouteCoordinates().then((_) {
          // Get booking requests and pickup location directly
          if (mounted) {
            context
                .read<PassengerProvider>()
                .getBookingRequestsID(context)
                .then((_) {
              _fetchPickupLocation();
            });
          }
        });
      }
    });
  }

  void getPickUpLocation() {
    // Don't call setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final mapProvider = context.read<MapProvider>();
        final previousPickupLocation = _pickupLocation;
        _pickupLocation = mapProvider.pickupLocation;

        debugPrint(
            'getPickUpLocation called, previous: $previousPickupLocation, new: $_pickupLocation');

        if (_pickupLocation != null) {
          // We have a valid pickup location
          debugPrint(
              'VALID PICKUP FOUND: Setting from MapProvider: $_pickupLocation');

          // Only update UI if pickup location is different
          if (previousPickupLocation == null ||
              previousPickupLocation.latitude != _pickupLocation!.latitude ||
              previousPickupLocation.longitude != _pickupLocation!.longitude) {
            debugPrint('Pickup location changed, updating UI');
            setState(() {});
            _initializeMarkers();
          } else {
            debugPrint('Pickup location unchanged, skipping UI update');
          }
        } else {
          debugPrint('WARNING: No pickup location found in MapProvider');
          // If we previously had a pickup location but now it's null, don't overwrite
          if (previousPickupLocation != null) {
            debugPrint(
                'Keeping previous pickup location: $previousPickupLocation');
            _pickupLocation = previousPickupLocation;
          } else {
            debugPrint('No previous pickup location to fall back to');
          }

          // Still update UI in case other markers need to be refreshed
          setState(() {});
          _initializeMarkers();
        }
      } else {
        debugPrint('ERROR: getPickUpLocation called when widget not mounted');
      }
    });
  }

  Future<void> getRouteCoordinates() async {
    // Reset the flag if we don't have valid coordinates
    if (_routeCoordinatesLoaded &&
        (_startingLocation == null || _endingLocation == null)) {
      _routeCoordinatesLoaded = false;
    }

    if (_routeCoordinatesLoaded) return;

    try {
      final mapProvider = context.read<MapProvider>();
      final driverProvider = context.read<DriverProvider>();

      // Save existing pickup location if any
      final existingPickupLocation =
          _pickupLocation ?? mapProvider.pickupLocation;

      // Make sure we have a valid route ID
      if (driverProvider.routeID <= 0) {
        // Try to get the driver's route first
        await driverProvider.getDriverRoute();

        // If still invalid, fall back to a default route or handle the error
        if (driverProvider.routeID <= 0) {
          debugPrint('No valid route ID available, using default fallback');
          // Use a default route ID if none available (fallback for stored sessions)
          driverProvider.setRouteID(1); // Set to a default route ID that exists
        }
      }

      // Wait for the route coordinates to be fetched
      try {
        await mapProvider.getRouteCoordinates(driverProvider.routeID);
      } catch (e) {
        debugPrint('Error fetching route coordinates: $e');
        // If coordinates fetch failed, try with default route ID
        if (driverProvider.routeID != 1) {
          debugPrint('Trying fallback route ID: 1');
          driverProvider.setRouteID(1);
          await mapProvider.getRouteCoordinates(1);
        }
      }

      // IMPORTANT: Always use current location as starting point if available
      _startingLocation = currentLocation ??
          mapProvider.originLocation ??
          mapProvider.currentLocation;
      _intermediateLocation1 = mapProvider.intermediateLoc1;
      _intermediateLocation2 = mapProvider.intermediateLoc2;
      _endingLocation = mapProvider.endingLocation;

      // Restore pickup location or get new one
      _pickupLocation = mapProvider.pickupLocation ?? existingPickupLocation;

      // Debug pickup status
      if (_pickupLocation != null) {
        debugPrint('Route loaded with pickup: $_pickupLocation');
      } else {
        debugPrint('Route loaded but no pickup location available');
      }

      // Initialize markers with all locations
      _initializeMarkers();

      // Generate polyline based on available waypoints
      if (_startingLocation != null && _endingLocation != null) {
        List<LatLng> waypoints = [];

        // Add available intermediate points to waypoints
        if (_intermediateLocation1 != null) {
          waypoints.add(_intermediateLocation1!);
        }

        if (_intermediateLocation2 != null) {
          waypoints.add(_intermediateLocation2!);
        }

        // Use consolidated polyline generator
        await generatePolyline(_startingLocation!, _endingLocation!,
            waypoints: waypoints.isNotEmpty ? waypoints : null);

        _lastPolylineUpdateLocation = currentLocation;
      } else {
        debugPrint('Missing start/end coordinates for polyline generation');
      }

      _routeCoordinatesLoaded = true;
    } catch (e) {
      debugPrint('Error loading route coordinates: $e');
      _routeCoordinatesLoaded = false;
    }
  }

  // Optimize the location update logic to be more efficient
  Future<void> getLocationUpdates() async {
    try {
      // Get current location first
      LocationData locationData = await location.getLocation();

      if (mounted) {
        setState(() {
          currentLocation =
              LatLng(locationData.latitude!, locationData.longitude!);
        });

        // Update MapProvider with current location
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && currentLocation != null) {
            context.read<MapProvider>().setCurrentLocation(currentLocation!);
          }
        });
      }

      // Load route coordinates
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (mounted) {
            await getRouteCoordinates();
            // After getting route coordinates, also try to get the pickup location
            _fetchPickupLocation();
          }
        });
      }

      // Listen to location updates
      location.onLocationChanged.listen((LocationData newLocation) {
        if (!mounted) return;
        if (newLocation.latitude != null && newLocation.longitude != null) {
          // Convert LocationData to LatLng
          final newLatLng =
              LatLng(newLocation.latitude!, newLocation.longitude!);

          // Update driver location in database
          final String driverID = context.read<DriverProvider>().driverID;
          _updateDriverLocationToDB(driverID, newLocation);

          // Only update UI if location changed significantly
          if (_shouldUpdateUI(newLatLng)) {
            setState(() {
              currentLocation = newLatLng;

              // Update current location marker
              markers.removeWhere((marker) =>
                  marker.markerId == const MarkerId('CurrentLocation'));
              markers.add(
                Marker(
                  markerId: const MarkerId('CurrentLocation'),
                  position: newLatLng,
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueCyan),
                  infoWindow: const InfoWindow(title: 'Current Location'),
                  zIndex: 2,
                ),
              );
            });
          }

          // Check if polyline needs updating
          if (_shouldUpdatePolyline(newLatLng) &&
              _startingLocation != null &&
              _endingLocation != null) {
            // Create list of available waypoints
            List<LatLng> waypoints = [];
            if (_intermediateLocation1 != null)
              waypoints.add(_intermediateLocation1!);
            if (_intermediateLocation2 != null)
              waypoints.add(_intermediateLocation2!);

            // Update polyline using current location as start
            generatePolyline(newLatLng, _endingLocation!,
                waypoints: waypoints.isNotEmpty ? waypoints : null);
            _lastPolylineUpdateLocation = newLatLng;
          }

          // Move the camera to new location if not manually panned
          if (!isAnimatingLocation) {
            animateToLocation(newLatLng);
          }

          // Check if near destination
          if (_endingLocation != null) {
            _checkDestinationReached(newLatLng);
          }
        }
      });
    } catch (e) {
      ShowMessage().showToast('Location service error');
      debugPrint('Error getting location: $e');
    }
  }

  // Helper method to check if destination is reached
  void _checkDestinationReached(LatLng currentPos) {
    if (_endingLocation == null) return;

    double distanceInMeters = Geolocator.distanceBetween(
      currentPos.latitude,
      currentPos.longitude,
      _endingLocation!.latitude,
      _endingLocation!.longitude,
    );

    if (kDebugMode) {
      print('Distance to end: $distanceInMeters meters');
    }

    // If distance is less than 40 meters, consider it reached
    if (distanceInMeters < 40 && mounted) {
      // Use post-frame callback to avoid state updates during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<MapProvider>().changeRouteLocation(context);
        }
      });
    }
  }

  // <<-- UPDATE LOCATION TO DATABASE -->>
  Future<void> _updateDriverLocationToDB(
      String driverID, LocationData newLocation) async {
    try {
      // Convert LocationData to WKT (Well-Known Text) Point format
      final wktPoint =
          'POINT(${newLocation.longitude} ${newLocation.latitude})';

      final response = await Supabase.instance.client
          .from('driverTable')
          .update({
            'current_location': wktPoint,
          })
          .eq('driver_id', driverID)
          .select('current_location');

      if (kDebugMode) {
        print(
            'Location updated to DB (WKT sent): ${response[0]['current_location']}');
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
        zoom: 17.5,
      )),
    );
  }

  // <<-- POLYLINES -->>
  Future<void> generatePolylineBetween(LatLng start, LatLng intermediate1,
      LatLng intermediate2, LatLng destination) async {
    try {
      // Create a list of intermediate points
      List<LatLng> waypoints = [intermediate1, intermediate2];

      // Use the consolidated method
      await generatePolyline(start, destination, waypoints: waypoints);
    } catch (e) {
      ShowMessage().showToast('Error: ${e.toString()}');
      debugPrint('Error generating polyline: $e');
    }
  }

  // Consolidated polyline generation method that handles any number of waypoints
  Future<void> generatePolyline(LatLng start, LatLng end,
      {List<LatLng>? waypoints}) async {
    try {
      debugPrint(
          'Generating polyline from ${start.latitude},${start.longitude} to ${end.latitude},${end.longitude}');
      if (waypoints != null && waypoints.isNotEmpty) {
        debugPrint('With ${waypoints.length} waypoints');
      }

      final String apiKey = dotenv.env['ANDROID_MAPS_API_KEY']!;
      if (apiKey.isEmpty) {
        debugPrint('ERROR: API key is empty');
        return;
      }

      final polylinePoints = PolylinePoints();
      final uri = Uri.parse(
          'https://routes.googleapis.com/directions/v2:computeRoutes');
      final headers = {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': apiKey,
        'X-Goog-FieldMask': 'routes.polyline.encodedPolyline',
      };

      // Build request body with dynamic waypoints
      final Map<String, dynamic> requestBody = {
        'origin': {
          'location': {
            'latLng': {
              'latitude': start.latitude,
              'longitude': start.longitude,
            },
          },
        },
        'destination': {
          'location': {
            'latLng': {
              'latitude': end.latitude,
              'longitude': end.longitude,
            },
          },
        },
        'travelMode': 'DRIVE',
        'polylineEncoding': 'ENCODED_POLYLINE',
        'computeAlternativeRoutes': true,
        'routingPreference': 'TRAFFIC_AWARE_OPTIMAL',
      };

      // Add waypoints if provided
      if (waypoints != null && waypoints.isNotEmpty) {
        requestBody['intermediates'] = waypoints
            .map((point) => {
                  'location': {
                    'latLng': {
                      'latitude': point.latitude,
                      'longitude': point.longitude,
                    }
                  }
                })
            .toList();
      }

      final response = await NetworkUtility.postUrl(uri,
          headers: headers, body: jsonEncode(requestBody));

      if (response == null) {
        ShowMessage().showToast('Could not get route');
        return;
      }

      _processRouteResponse(response, polylinePoints);
    } catch (e) {
      debugPrint('Error generating polyline: $e');
      ShowMessage().showToast('Error generating route');
    }
  }

  // Helper method to process route responses - simplified
  void _processRouteResponse(String response, PolylinePoints polylinePoints) {
    try {
      final data = json.decode(response);

      // Check for routes
      if (data['routes'] == null || data['routes'].isEmpty) {
        ShowMessage().showToast('No route found');
        return;
      }

      // Get polyline
      final polyline = data['routes'][0]['polyline']?['encodedPolyline'];
      if (polyline == null) {
        ShowMessage().showToast('No route data found');
        return;
      }

      // Decode polyline
      List<PointLatLng> decodedPolyline =
          polylinePoints.decodePolyline(polyline);
      List<LatLng> polylineCoordinates = decodedPolyline
          .map((point) => LatLng(point.latitude, point.longitude))
          .toList();

      // Update the UI only if component is still mounted
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
    } catch (e) {
      debugPrint('Error processing route response: $e');
      ShowMessage().showToast('Error processing route');
    }
  }

  // Add marker creation helper
  Marker createMarker({
    required String id,
    required LatLng position,
    required BitmapDescriptor icon,
    required String title,
    double zIndex = 1.0,
  }) {
    return Marker(
      markerId: MarkerId(id),
      position: position,
      icon: icon,
      infoWindow: InfoWindow(title: title),
      zIndex: zIndex,
    );
  }

  @override
  void dispose() {
    // Clean up resources
    location.onLocationChanged.drain();
    super.dispose();
  }

  // Initialize markers with the route points
  void _initializeMarkers() {
    if (!mounted) return;

    debugPrint('Initializing markers');
    debugPrint('Current location: $currentLocation');
    debugPrint('Starting location: $_startingLocation');
    debugPrint('Ending location: $_endingLocation');
    debugPrint('Pickup location: $_pickupLocation');

    // Get pickup location from provider first
    final mapProvider = context.read<MapProvider>();
    final providerPickupLocation = mapProvider.pickupLocation;

    if (providerPickupLocation != null && _pickupLocation == null) {
      debugPrint(
          'INIT: Found pickup location in provider: $providerPickupLocation');
      _pickupLocation = providerPickupLocation;
    }

    setState(() {
      // Clear existing markers first
      markers.clear();

      // Add current location marker if available
      if (currentLocation != null) {
        markers.add(
          createMarker(
            id: 'CurrentLocation',
            position: currentLocation!,
            icon:
                BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
            title: 'Current Location',
            zIndex: 2.0, // Higher z-index to stay on top
          ),
        );
        debugPrint('Added CurrentLocation marker: $currentLocation');
      }

      // Add starting location marker if available
      if (_startingLocation != null) {
        markers.add(
          createMarker(
            id: 'StartingLocation',
            position: _startingLocation!,
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueGreen),
            title: 'Starting Point',
          ),
        );
        debugPrint('Added StartingLocation marker: $_startingLocation');
      }

      // Add ending location marker if available
      if (_endingLocation != null) {
        markers.add(
          createMarker(
            id: 'EndingLocation',
            position: _endingLocation!,
            icon:
                BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            title: 'Destination',
          ),
        );
        debugPrint('Added EndingLocation marker: $_endingLocation');
      }

      // Add pickup location marker if available (with highest z-index)
      if (_pickupLocation != null) {
        markers.add(
          createMarker(
            id: 'Pickup',
            position: _pickupLocation!,
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueViolet),
            title: 'Pickup Location',
            zIndex: 3.0, // Highest z-index to ensure visibility
          ),
        );
        debugPrint('Added Pickup marker: $_pickupLocation');

        // Also add a debug marker at a slight offset to verify pin placement
        markers.add(
          createMarker(
            id: 'DebugPickup',
            position: LatLng(
              _pickupLocation!.latitude + 0.0001,
              _pickupLocation!.longitude + 0.0001,
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueAzure),
            title: 'Debug Pickup Marker',
            zIndex: 2.5,
          ),
        );
      } else {
        // Try to fetch pickup location from provider one more time
        debugPrint(
            'No pickup location in local state, checking provider again...');
        // If no pickup location in this class but available in provider, get it immediately
        final providerPickupLocation = mapProvider.pickupLocation;
        if (providerPickupLocation != null) {
          _pickupLocation = providerPickupLocation;
          debugPrint(
              'INIT (Retry): Got pickup from provider: $_pickupLocation');

          // Add the pickup marker
          markers.add(
            createMarker(
              id: 'Pickup',
              position: providerPickupLocation,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueViolet),
              title: 'Pickup Location',
              zIndex: 3.0,
            ),
          );
          debugPrint('Added Pickup marker from provider: $_pickupLocation');

          // Also add debug marker
          markers.add(
            createMarker(
              id: 'DebugPickup',
              position: LatLng(
                providerPickupLocation.latitude + 0.0001,
                providerPickupLocation.longitude + 0.0001,
              ),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueAzure),
              title: 'Debug Pickup Marker',
              zIndex: 2.5,
            ),
          );
        } else {
          debugPrint('INIT: No pickup location available in provider');
        }
      }

      // Debug output about markers
      debugPrint('Total markers after initialization: ${markers.length}');
      markers.forEach((marker) => debugPrint(
          '  - Marker: ${marker.markerId.value} at ${marker.position}'));
    });

    // Force a marker refresh after a short delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _fetchPickupLocation();
      }
    });
  }

  Set<Marker> buildMarkers() {
    final markers = <Marker>{};

    // Pickup marker
    if (widget.initialLocation != null) {
      markers.add(
        createMarker(
          id: 'pickup',
          position: widget.initialLocation!,
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          title: 'Pickup',
        ),
      );
    }

    // Dropoff marker
    if (widget.finalLocation != null) {
      markers.add(
        createMarker(
          id: 'dropoff',
          position: widget.finalLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          title: 'Dropoff',
        ),
      );
    }
    return markers;
  }

  @override
  Widget build(BuildContext context) {
    // Don't call getRouteCoordinates directly during build
    if (!_routeCoordinatesLoaded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          getRouteCoordinates();
        }
      });
    }

    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    // Debug info - log all markers in current state
    debugPrint('BUILD: Current marker count: ${markers.length}');
    if (markers.isNotEmpty) {
      markers.forEach((marker) => debugPrint(
          '  - Marker: ${marker.markerId.value} at ${marker.position}'));
    }

    return Scaffold(
        body: Stack(
      children: [
        RepaintBoundary(
          child: currentLocation == null
              ? const Center(
                  child: CircularProgressIndicator(),
                )
              : GoogleMap(
                  onMapCreated: (controller) {
                    _mapControllerCompleter.complete(controller);
                    // Initialize markers when map is created
                    _initializeMarkers();
                  },
                  initialCameraPosition: CameraPosition(
                    target: currentLocation!,
                    zoom: 15,
                    tilt: 45.0,
                  ),
                  markers: markers,
                  polylines: Set<Polyline>.of(polylines.values),
                  mapType: MapType.normal,
                  //buildings
                  buildingsEnabled: true,

                  //there will be a custom button
                  myLocationButtonEnabled: false,

                  indoorViewEnabled: false,
                  mapToolbarEnabled: false,

                  //traffic data
                  trafficEnabled: false,

                  //gestures
                  rotateGesturesEnabled: true,
                  tiltGesturesEnabled: true,
                  scrollGesturesEnabled: true,
                  zoomGesturesEnabled: true,
                  zoomControlsEnabled: false,

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
              child:
                  const Icon(Icons.my_location, color: Colors.black, size: 26),
            ),
          ),
        ),
      ],
    ));
  }

  // Helper method to fetch pickup location
  void _fetchPickupLocation() {
    if (mounted) {
      final mapProvider = context.read<MapProvider>();
      // Check if pickup location is available in the provider
      final pickupLocation = mapProvider.pickupLocation;

      debugPrint(
          '_fetchPickupLocation called, MapProvider pickup location: $pickupLocation');

      if (pickupLocation != null) {
        debugPrint(
            'FOUND PICKUP: Got pickup location from MapProvider: $pickupLocation');

        setState(() {
          _pickupLocation = pickupLocation;

          // Debug current markers before removal
          debugPrint('Markers before update: ${markers.length}');
          markers.forEach((m) =>
              debugPrint(' - Marker: ${m.markerId.value} at ${m.position}'));

          // Update markers if pickup location is set
          markers.removeWhere((m) =>
              m.markerId == const MarkerId('Pickup') ||
              m.markerId == const MarkerId('DebugPickup'));

          // Create pickup marker with distinctive appearance
          final pickupMarker = createMarker(
            id: 'Pickup',
            position: pickupLocation,
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueViolet),
            title: 'Pickup Location',
            zIndex: 3.0, // Higher z-index to ensure visibility
          );

          markers.add(pickupMarker);

          // Add debug marker (different color) to verify position is correct
          markers.add(
            createMarker(
              id: 'DebugPickup',
              position: LatLng(
                pickupLocation.latitude +
                    0.0001, // Slightly offset for visibility
                pickupLocation.longitude + 0.0001,
              ),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueAzure),
              title: 'Debug Pickup',
              zIndex: 2.0,
            ),
          );

          debugPrint('Updated pickup location marker: $_pickupLocation');
          debugPrint('Current markers: ${markers.length}');
          markers.forEach((marker) => debugPrint(
              '  - Marker: ${marker.markerId.value} at ${marker.position}'));
        });
      } else {
        debugPrint('No pickup location available from MapProvider');
        // If we have a local pickup location but MapProvider doesn't, synchronize back
        if (_pickupLocation != null) {
          debugPrint('Synchronizing local pickup location to MapProvider');
          mapProvider.setPickUpLocation(_pickupLocation!);
        }
        debugPrint(
            'MapProvider state: routeState=${mapProvider.routeState}, errorMessage=${mapProvider.errorMessage}');
      }
    } else {
      debugPrint('ERROR: _fetchPickupLocation called when widget not mounted');
    }
  }

  // Helper method to decide if UI needs updating for a location change
  bool _shouldUpdateUI(LatLng newLocation) {
    if (currentLocation == null) return true;

    double distanceMoved = Geolocator.distanceBetween(
      newLocation.latitude,
      newLocation.longitude,
      currentLocation!.latitude,
      currentLocation!.longitude,
    );

    // Update UI if moved at least 2 meters
    return distanceMoved > 2;
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

    // Only update polyline when significant movement has occurred
    return distanceMoved > _minDistanceForPolylineUpdate;
  }
}
