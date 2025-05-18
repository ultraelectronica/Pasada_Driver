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

// Enum to track the initialization state
enum MapInitState {
  uninitialized,
  loadingLocation,
  locationLoaded,
  loadingRouteData,
  routeDataLoaded,
  loadingPickupData,
  initialized,
  error
}

class MapScreenState extends State<MapScreen> {
  // State tracking
  MapInitState _initState = MapInitState.uninitialized;
  String? _errorMessage;

  LatLng? currentLocation;
  LocationData? locationData;
  final Location location = Location();
  LatLng? _lastPolylineUpdateLocation;
  final GlobalKey<MapScreenState> mapScreenKey = GlobalKey<MapScreenState>();

  // <<-- POLYLINES -->>
  Map<PolylineId, Polyline> polylines = {};

  // <<-- MARKERS -->>
  Set<Marker> markers = {};

  // Route locations
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
    if (kDebugMode) {
      debugPrint('MapScreen: Starting initialization sequence');
    }

    // Start the initialization sequence
    _initializeMap();
  }

  // Single controlled initialization flow
  Future<void> _initializeMap() async {
    try {
      // Step 1: Get current location
      _updateInitState(MapInitState.loadingLocation);
      await _getCurrentLocation();

      // Step 2: Load route data
      _updateInitState(MapInitState.loadingRouteData);
      await _loadRouteData();

      // Step 3: Initialize markers
      await _initializeMarkers();

      // Step 4: Generate initial polyline
      await _generateInitialPolyline();

      // Step 5: Load pickup data
      _updateInitState(MapInitState.loadingPickupData);
      await _loadPickupData();

      // Step 6: Start location tracking
      _startLocationTracking();

      // Initialization complete
      _updateInitState(MapInitState.initialized);

      if (kDebugMode) {
        debugPrint('MapScreen: Initialization sequence completed successfully');
      }
    } catch (e) {
      _updateInitState(MapInitState.error, errorMessage: e.toString());
      ShowMessage().showToast('Error initializing map: ${e.toString()}');
    }
  }

  // Update initialization state with logging
  void _updateInitState(MapInitState newState, {String? errorMessage}) {
    if (!mounted) return;

    setState(() {
      _initState = newState;
      _errorMessage = errorMessage;
    });

    if (kDebugMode) {
      debugPrint('MapScreen: State changed to ${newState.toString()}');
      if (errorMessage != null) {
        debugPrint('MapScreen ERROR: $errorMessage');
      }
    }
  }

  // Step 1: Get current location once
  Future<void> _getCurrentLocation() async {
    try {
      if (kDebugMode) {
        debugPrint('MapScreen: Getting current location');
      }

      LocationData locationData = await location.getLocation();

      if (!mounted) return;

      setState(() {
        currentLocation =
            LatLng(locationData.latitude!, locationData.longitude!);
      });

      // Update MapProvider with current location
      if (mounted && currentLocation != null) {
        context.read<MapProvider>().setCurrentLocation(currentLocation!);
      }

      _updateInitState(MapInitState.locationLoaded);

      if (kDebugMode) {
        debugPrint('MapScreen: Current location loaded: $currentLocation');
      }
    } catch (e) {
      throw Exception('Error: Failed to get current location: $e');
    }
  }

  // Step 2: Load route data once
  Future<void> _loadRouteData() async {
    try {
      if (kDebugMode) {
        debugPrint('MapScreen: Loading route data');
      }

      final mapProvider = context.read<MapProvider>();
      final driverProvider = context.read<DriverProvider>();

      // Make sure we have a valid route ID
      // if (driverProvider.routeID <= 0) {
      //   await driverProvider.getDriverRoute();

      //   if (driverProvider.routeID <= 0) {
      //     if (kDebugMode) {
      //       debugPrint('No valid route ID available, using default fallback');
      //     }
      //     driverProvider.setRouteID(1);
      //   }
      // }

      // Load route data ONCE - this is crucial
      await mapProvider.getRouteCoordinates(driverProvider.routeID);

      // Store route data locally
      _startingLocation = mapProvider.originLocation;
      _intermediateLocation1 = mapProvider.intermediateLoc1;
      _intermediateLocation2 = mapProvider.intermediateLoc2;
      _endingLocation = mapProvider.endingLocation;

      // Log the loaded route data
      if (kDebugMode) {
        debugPrint('MapScreen: Route data loaded');
        debugPrint('  Starting location: $_startingLocation');
        debugPrint('  Ending location: $_endingLocation');
        debugPrint('  RouteID: ${driverProvider.routeID}');
      }

      _routeCoordinatesLoaded = true;
    } catch (e) {
      throw Exception('Failed to load route data: $e');
    }
  }

  // Step 3: Initialize markers once with complete data
  Future<void> _initializeMarkers() async {
    if (!mounted || currentLocation == null) return;

    if (kDebugMode) {
      debugPrint('MapScreen: Initializing markers');
    }

    setState(() {
      // Clear existing markers
      markers.clear();

      // Add current location marker
      markers.add(createMarker(
        id: 'CurrentLocation',
        position: currentLocation!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
        title: 'Current Location',
        zIndex: 2.0,
      ));

      // Add starting location marker
      if (_startingLocation != null) {
        markers.add(createMarker(
          id: 'StartingLocation',
          position: _startingLocation!,
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          title: 'Starting Point (Route Origin)',
        ));
      }

      // Add ending location marker
      if (_endingLocation != null) {
        markers.add(createMarker(
          id: 'EndingLocation',
          position: _endingLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          title: 'Destination',
        ));
      }

      // Add intermediate markers if available
      if (_intermediateLocation1 != null) {
        markers.add(createMarker(
          id: 'Intermediate1',
          position: _intermediateLocation1!,
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
          title: 'Waypoint 1',
        ));
      }

      if (_intermediateLocation2 != null) {
        markers.add(createMarker(
          id: 'Intermediate2',
          position: _intermediateLocation2!,
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
          title: 'Waypoint 2',
        ));
      }
    });

    if (kDebugMode) {
      debugPrint('MapScreen: ${markers.length} markers initialized');
    }
  }

  // Step 4: Generate initial polyline
  Future<void> _generateInitialPolyline() async {
    if (_startingLocation != null &&
        _endingLocation != null &&
        currentLocation != null) {
      if (kDebugMode) {
        debugPrint('MapScreen: Generating initial polyline');
      }

      List<LatLng> waypoints = [];

      // Add original route waypoints
      if (_intermediateLocation1 != null) {
        waypoints.add(_intermediateLocation1!);
      }

      if (_intermediateLocation2 != null) {
        waypoints.add(_intermediateLocation2!);
      }

      // Use current location as start point instead of original route start
      await generatePolyline(currentLocation!, _endingLocation!,
          waypoints: waypoints.isNotEmpty ? waypoints : null);

      _lastPolylineUpdateLocation = currentLocation;
    }
  }

  // Step 5: Load pickup data
  Future<void> _loadPickupData() async {
    try {
      if (kDebugMode) {
        debugPrint('MapScreen: Loading pickup location data');
      }

      if (!mounted) return;

      await context.read<PassengerProvider>().getBookingRequestsID(context);

      final mapProvider = context.read<MapProvider>();
      _pickupLocation = mapProvider.pickupLocation;

      if (_pickupLocation != null) {
        if (kDebugMode) {
          debugPrint('MapScreen: Pickup location loaded: $_pickupLocation');
        }

        setState(() {
          markers.add(createMarker(
            id: 'Pickup',
            position: _pickupLocation!,
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueViolet),
            title: 'Pickup Location',
            zIndex: 3.0,
          ));
        });
      } else {
        if (kDebugMode) {
          debugPrint('MapScreen: No pickup location available');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('MapScreen: Error loading pickup data: $e');
      }
      // Continue initialization even if pickup data fails
    }
  }

  // Step 6: Start continuous location tracking
  void _startLocationTracking() {
    if (kDebugMode) {
      debugPrint('MapScreen: Starting location tracking');
    }

    location.onLocationChanged.listen((LocationData newLocation) {
      if (!mounted) return;
      if (newLocation.latitude == null || newLocation.longitude == null) return;

      final newLatLng = LatLng(newLocation.latitude!, newLocation.longitude!);

      // Update driver location in database
      final String driverId = context.read<DriverProvider>().driverID;
      _updateDriverLocationToDB(driverId, newLocation);

      // Update UI if moved significantly
      if (_shouldUpdateUI(newLatLng)) {
        setState(() {
          currentLocation = newLatLng;

          // Update current location marker
          markers.removeWhere(
              (marker) => marker.markerId == const MarkerId('CurrentLocation'));
          markers.add(createMarker(
            id: 'CurrentLocation',
            position: newLatLng,
            icon:
                BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
            title: 'Current Location',
            zIndex: 2.0,
          ));
        });
      }

      // Only update polyline if moved significantly AND we're initialized
      if (_shouldUpdatePolyline(newLatLng) &&
          _initState == MapInitState.initialized &&
          _endingLocation != null) {
        List<LatLng> waypoints = [];
        if (_intermediateLocation1 != null)
          waypoints.add(_intermediateLocation1!);
        if (_intermediateLocation2 != null)
          waypoints.add(_intermediateLocation2!);

        // IMPORTANT: Use current location as start point for better user experience
        generatePolyline(newLatLng, _endingLocation!,
            waypoints: waypoints.isNotEmpty ? waypoints : null);

        _lastPolylineUpdateLocation = newLatLng;
      }

      // Move camera if not manually positioned
      if (!isAnimatingLocation) {
        animateToLocation(newLatLng);
      }

      // Check if near destination
      if (_endingLocation != null) {
        _checkDestinationReached(newLatLng);
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

        if (kDebugMode) {
          debugPrint(
              'getPickUpLocation called, previous: $previousPickupLocation, new: $_pickupLocation');
        }

        if (_pickupLocation != null) {
          // We have a valid pickup location
          if (kDebugMode) {
            debugPrint(
                'VALID PICKUP FOUND: Setting from MapProvider: $_pickupLocation');
          }

          // Only update UI if pickup location is different
          if (previousPickupLocation == null ||
              previousPickupLocation.latitude != _pickupLocation!.latitude ||
              previousPickupLocation.longitude != _pickupLocation!.longitude) {
            if (kDebugMode) {
              debugPrint('Pickup location changed, updating UI');
            }
            setState(() {});
            _initializeMarkers();
          }
        } else {
          if (kDebugMode) {
            debugPrint('WARNING: No pickup location found in MapProvider');
          }
          // If we previously had a pickup location but now it's null, don't overwrite
          if (previousPickupLocation != null) {
            if (kDebugMode) {
              debugPrint(
                  'Keeping previous pickup location: $previousPickupLocation');
            }
            _pickupLocation = previousPickupLocation;
          }

          // Still update UI in case other markers need to be refreshed
          setState(() {});
          _initializeMarkers();
        }
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

      // Store original route information to detect changes
      final int originalRouteID = driverProvider.routeID;
      if (kDebugMode) {
        debugPrint('ROUTE INIT: Starting with route ID: $originalRouteID');
      }

      // Make sure we have a valid route ID
      if (driverProvider.routeID <= 0) {
        // Try to get the driver's route first
        await driverProvider.getDriverRoute();

        // If still invalid, fall back to a default route or handle the error
        if (driverProvider.routeID <= 0) {
          if (kDebugMode) {
            debugPrint('No valid route ID available, using default fallback');
          }
          // Use a default route ID if none available (fallback for stored sessions)
          driverProvider.setRouteID(1); // Set to a default route ID that exists
        }
      }

      // Wait for the route coordinates to be fetched
      try {
        await mapProvider.getRouteCoordinates(driverProvider.routeID);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Error fetching route coordinates: $e');
        }
        // If coordinates fetch failed, try with default route ID
        if (driverProvider.routeID != 1) {
          if (kDebugMode) {
            debugPrint('Trying fallback route ID: 1');
          }
          driverProvider.setRouteID(1);
          await mapProvider.getRouteCoordinates(1);
        }
      }

      // Always prioritize route origin location and never mix with current location
      // This is critical to prevent pin swapping issues
      _startingLocation = mapProvider.originLocation;

      // Only use current location as fallback if absolutely no origin location
      if (_startingLocation == null && mapProvider.originLocation == null) {
        if (kDebugMode) {
          debugPrint(
              'WARNING: No origin location found, using current location as fallback');
        }
        _startingLocation = currentLocation;
      }

      _intermediateLocation1 = mapProvider.intermediateLoc1;
      _intermediateLocation2 = mapProvider.intermediateLoc2;
      _endingLocation = mapProvider.endingLocation;

      // IMPORTANT: Verify we have all required locations before proceeding
      if (_startingLocation == null || _endingLocation == null) {
        if (kDebugMode) {
          debugPrint(
              'ERROR: Missing critical location data - Start: $_startingLocation, End: $_endingLocation');
        }

        // Force a reload if we're missing critical data
        if (mapProvider.originLocation != null &&
            mapProvider.endingLocation != null) {
          _startingLocation = mapProvider.originLocation;
          _endingLocation = mapProvider.endingLocation;
          if (kDebugMode) {
            debugPrint(
                'RECOVERED: Using provider locations - Start: $_startingLocation, End: $_endingLocation');
          }
        }
      }

      // Restore pickup location or get new one
      _pickupLocation = mapProvider.pickupLocation ?? existingPickupLocation;

      // Debug logging to verify pin locations
      if (kDebugMode) {
        debugPrint('PIN LOCATIONS - Loading Complete:');
        debugPrint('  Starting location: $_startingLocation');
        debugPrint('  Current location: $currentLocation');
        debugPrint('  Ending location: $_endingLocation');
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

        // Use consolidated polyline generator - always from start to end (not current location)
        // This ensures route direction is consistent
        await generatePolyline(_startingLocation!, _endingLocation!,
            waypoints: waypoints.isNotEmpty ? waypoints : null);

        _lastPolylineUpdateLocation = currentLocation;

        // Log the final route details for debugging
        if (kDebugMode) {
          debugPrint(
              'ROUTE SETUP COMPLETE: ${_startingLocation!.latitude},${_startingLocation!.longitude} to ${_endingLocation!.latitude},${_endingLocation!.longitude}');
          debugPrint('Route ID: ${driverProvider.routeID}');
        }
      } else {
        if (kDebugMode) {
          debugPrint('Missing start/end coordinates for polyline generation');
        }
      }

      _routeCoordinatesLoaded = true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error loading route coordinates: $e');
      }
      _routeCoordinatesLoaded = false;
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
      String driverId, LocationData newLocation) async {
    try {
      // Convert LocationData to WKT (Well-Known Text) Point format
      final wktPoint =
          'POINT(${newLocation.longitude} ${newLocation.latitude})';

      final response = await Supabase.instance.client
          .from('driverTable')
          .update({
            'current_location': wktPoint,
          })
          .eq('driver_id', driverId)
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
      if (kDebugMode) {
        debugPrint('Error generating polyline: $e');
      }
    }
  }

  // Consolidated polyline generation method that handles any number of waypoints
  Future<void> generatePolyline(LatLng start, LatLng end,
      {List<LatLng>? waypoints, LatLng? currentLocation}) async {
    try {
      if (kDebugMode) {
        debugPrint(
            'Generating polyline from ${start.latitude},${start.longitude} to ${end.latitude},${end.longitude}');
        if (waypoints != null && waypoints.isNotEmpty) {
          debugPrint('With ${waypoints.length} waypoints');
        }
        if (currentLocation != null) {
          debugPrint(
              'Current location: ${currentLocation.latitude},${currentLocation.longitude}');
        }
      }

      final String apiKey = dotenv.env['ANDROID_MAPS_API_KEY']!;
      if (apiKey.isEmpty) {
        if (kDebugMode) {
          debugPrint('ERROR: API key is empty');
        }
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
      List<Map<String, dynamic>> intermediates = [];

      // First add the current location as a via point if provided
      if (currentLocation != null) {
        intermediates.add({
          'location': {
            'latLng': {
              'latitude': currentLocation.latitude,
              'longitude': currentLocation.longitude,
            }
          },
          'routeModifiers': {'avoidTurnsByHighwayClass': true}
        });
      }

      // Then add the route waypoints
      if (waypoints != null && waypoints.isNotEmpty) {
        for (var point in waypoints) {
          intermediates.add({
            'location': {
              'latLng': {
                'latitude': point.latitude,
                'longitude': point.longitude,
              }
            }
          });
        }
      }

      // Only add intermediates if we have any
      if (intermediates.isNotEmpty) {
        requestBody['intermediates'] = intermediates;
      }

      final response = await NetworkUtility.postUrl(uri,
          headers: headers, body: jsonEncode(requestBody));

      if (response == null) {
        ShowMessage().showToast('Could not get route');
        return;
      }

      _processRouteResponse(response, polylinePoints);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error generating polyline: $e');
      }
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
      if (kDebugMode) {
        debugPrint('Error processing route response: $e');
      }
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

  // Helper method to check if two locations are approximately equal
  bool _areLocationsEqual(LatLng loc1, LatLng loc2,
      {double threshold = 0.0001}) {
    return (loc1.latitude - loc2.latitude).abs() < threshold &&
        (loc1.longitude - loc2.longitude).abs() < threshold;
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
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
        body: Stack(
      children: [
        // Show loading indicator if location not yet available
        if (currentLocation == null)
          const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text("Loading map...",
                    style: TextStyle(fontWeight: FontWeight.bold))
              ],
            ),
          )
        // Show error message if initialization failed
        else if (_initState == MapInitState.error)
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, color: Colors.red, size: 48),
                SizedBox(height: 16),
                Text("Error loading map: $_errorMessage",
                    style: TextStyle(color: Colors.red),
                    textAlign: TextAlign.center),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _initializeMap,
                  child: Text("Retry"),
                )
              ],
            ),
          )
        // Show map when location is available
        else
          RepaintBoundary(
            child: GoogleMap(
              onMapCreated: (controller) {
                _mapControllerCompleter.complete(controller);

                if (kDebugMode) {
                  debugPrint('MapScreen: Google Map created');
                }
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

        // CUSTOM MY LOCATION BUTTON - always show this on top of map
        if (currentLocation != null)
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
                child: const Icon(Icons.my_location,
                    color: Colors.black, size: 26),
              ),
            ),
          ),

        // Optional status indicator during initialization
        if (_initState != MapInitState.initialized &&
            _initState != MapInitState.error)
          Positioned(
            top: 60,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _getStatusMessage(),
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
      ],
    ));
  }

  // Helper to get user-friendly status message
  String _getStatusMessage() {
    switch (_initState) {
      case MapInitState.loadingLocation:
        return "Getting your location...";
      case MapInitState.loadingRouteData:
        return "Loading route...";
      case MapInitState.loadingPickupData:
        return "Checking for passengers...";
      default:
        return "Loading...";
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
