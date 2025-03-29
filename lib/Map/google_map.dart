// ignore_for_file: non_constant_identifier_names

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:pasada_driver_side/Map/network_utility.dart';
import 'package:pasada_driver_side/Database/driver_provider.dart';
import 'package:pasada_driver_side/Messages/message.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  LatLng? currentLocation; // Location Data
  LocationData? locationData;
  final Location location = Location();

  final GlobalKey<MapScreenState> mapScreenKey = GlobalKey<MapScreenState>();

  // <<-- POLYLINES -->>
  Map<PolylineId, Polyline> polylines = {};

  // <<-- DEFAULT LOCATIONS -->>

  // Novaliches to Malinta
  // LatLng StartingLocation = const LatLng(
  //     14.721957951314671, 121.03660698876655); // savemore novaliches
  // LatLng MiddleLocation =
  //     const LatLng(14.711095415234702, 120.99311060642324); // VGC bus terminal
  // LatLng IntermediateLocation =
  //     const LatLng(14.701160828529744, 120.98308262221344);
  // LatLng EndingLocation = const LatLng(
  //     14.693028415325333, 120.96837623290318); // valenzuela peoples park

  // Malinta to Novaliches
  LatLng StartingLocation =
      const LatLng(14.694370509154878, 120.97003705410779);

  LatLng MiddleLocation = const LatLng(14.7111498286728, 120.99310735112863);

  LatLng IntermediateLocation =
      const LatLng(14.71772512210624, 121.00429667924092);

  LatLng EndingLocation = const LatLng(14.721876764899815, 121.0366831829442);

  final Completer<GoogleMapController> _mapControllerCompleter = Completer();
  final String apiKey = dotenv.env['ANDROID_MAPS_API_KEY']!;

  // <<-- DRIVER ROUTE -->>
  LatLng? initialLocation, finalLocation;
  Marker? initialMarker, finalMarker;

  // animation ng location to kapag pinindot yung custom my location button
  bool isAnimatingLocation = false;

  @override
  void initState() {
    super.initState();

    getLocationUpdates();
    generatePolylineBetween(
        StartingLocation, MiddleLocation, IntermediateLocation, EndingLocation);
    // generatePolylineBetween(MiddleLocation, EndingLocation);
  }

  // <<-- LOCATION SERVICES -->>
  // Future<void> initLocation() async {
  //   await location.getLocation().then((location) {
  //     setState(() =>
  //         currentLocation = LatLng(location.latitude!, location.longitude!));
  //   });
  //   location.onLocationChanged.listen((location) {
  //     setState(() =>
  //         currentLocation = LatLng(location.latitude!, location.longitude!));
  //   });
  // }

  Future<void> getLocationUpdates() async {
    try {
      // check if yung location services ay available
      bool serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
        if (!serviceEnabled) {
          showAlertDialog(
            'Enable Location Services',
            'Location services are disabled. Please enable them to use this feature.',
          );
          return;
        }
      }

      // check ng location permissions
      PermissionStatus permissionGranted = await location.hasPermission();
      if (permissionGranted == PermissionStatus.denied) {
        permissionGranted = await location.requestPermission();
        if (permissionGranted != PermissionStatus.granted) {
          showAlertDialog(
            'Permission Required',
            'This app needs location permission to work. Please allow it in your settings.',
          );
          return;
        }
      }

      // kuha ng current location
      LocationData locationData = await location.getLocation();

      // Fluttertoast.showToast(
      //   msg:
      //       'Location fetched successfully: ${locationData.latitude}, ${locationData.longitude}',
      //   toastLength: Toast.LENGTH_LONG,
      //   backgroundColor: Colors.black87,
      //   textColor: Colors.white,
      // );

      setState(() {
        currentLocation =
            LatLng(locationData.latitude!, locationData.longitude!);
      });
      // listen sa location updates
      location.onLocationChanged.listen((LocationData newLocation) {
        if (newLocation.latitude != null && newLocation.longitude != null) {
          //save location to DB
          final String vehicleID = context.read<DriverProvider>().vehicleID!;

          _updateVehicleLocationToDB(vehicleID, newLocation);

          // Fluttertoast.showToast(
          //   msg:
          //       'Location updated: ${newLocation.latitude}, ${newLocation.longitude}',
          //   toastLength: Toast.LENGTH_LONG,
          //   backgroundColor: Colors.black87,
          //   textColor: Colors.white,
          // );
          setState(() {
            currentLocation =
                LatLng(newLocation.latitude!, newLocation.longitude!);
          });
        }
      });
    } catch (e) {
      showError('An error occurred while fetching the location.');
    }
  }

  // <<-- UPDATE LOCATOIN TO DATABASE -->>
  Future<void> _updateVehicleLocationToDB(
      String vehicleID, LocationData newLocation) async {
    try {
      final response = await Supabase.instance.client
          .from('vehicleTable')
          .update({
            'vehicle_location':
                '${newLocation.latitude}, ${newLocation.longitude}'
          })
          .eq('vehicle_id', vehicleID)
          .select('vehicle_location');

      if (kDebugMode) {
        // Fluttertoast.showToast(
        //   msg: 'Location updated to: ${response[0]['vehicleLocation']}',
        //   toastLength: Toast.LENGTH_SHORT,
        // );
        print('Location updated to: ${response[0]['vehicle_location']}');
      }
    } catch (e) {
      Fluttertoast.showToast(msg: 'Error: $e');
    }
  }

  // <<-- ERROR HANDLING & TOAST -->>
  // helper function for showing alert dialogs to reduce repetition
  void showAlertDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  // specific error dialog using the helper function
  void showLocationErrorDialog() {
    showAlertDialog(
      'Location Error',
      'Unable to fetch the current location. Please try again later.',
    );
  }

  // generic error dialog using the helper function
  void showError(String message) {
    showAlertDialog('Error', message);
  }

  // <<-- ANIMATION -->>
  // animate yung camera papunta sa current location ng user
  Future<void> animateToLocation(LatLng target) async {
    final GoogleMapController controller =
        await _mapControllerCompleter.future; // Changed here
    controller.animateCamera(
      CameraUpdate.newCameraPosition(CameraPosition(
        target: target,
        zoom: 16.0,
      )),
    );
  }

  // <<-- LOCATION -->>

  // @override
  // void didUpdateWidget(MapScreen oldWidget) {
  //   super.didUpdateWidget(oldWidget);
  //   if (widget.initialLocation != oldWidget.initialLocation ||
  //       widget.finalLocation != oldWidget.finalLocation) {
  //     handleLocationUpdates();
  //   }
  // }

  // void handleLocationUpdates() {
  //   if (widget.initialLocation != null && widget.finalLocation != null) {
  //     // generatePolylineBetween(widget.initialLocation!, widget.finalLocation!);
  //     showDebugToast('Generating route');
  //   }
  // }

  // ito yung method para sa pick-up and drop-off location
  void updateLocations({LatLng? pickup, LatLng? dropoff}) {
    if (pickup != null) StartingLocation = pickup;

    if (dropoff != null) EndingLocation = dropoff;

    generatePolylineBetween(
        StartingLocation, MiddleLocation, IntermediateLocation, EndingLocation);
  }

  // <<-- POLYLINES -->>

  Future<void> generatePolylineBetween(LatLng start, LatLng intermediate1,
      LatLng intermediate2, LatLng destination) async {
    try {
      final String apiKey = dotenv.env['ANDROID_MAPS_API_KEY']!;

      final polylinePoints = PolylinePoints();

      // routes API request
      final uri = Uri.parse(
          'https://routes.googleapis.com/directions/v2:computeRoutes');
      final headers = {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': apiKey,
        'X-Goog-FieldMask': 'routes.polyline.encodedPolyline',
        // 'X-Goog-FieldMask': 'routes.distanceMeters',
        // 'X-Goog-FieldMask': 'routes.duration',
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
              "latLng": {
                "latitude": intermediate1.latitude,
                "longitude": intermediate1.longitude
              }
            }
          },
          {
            "location": {
              "latLng": {
                "latitude": intermediate2.latitude,
                "longitude": intermediate2.longitude
              }
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
      final response =
          await NetworkUtility.postUrl(uri, headers: headers, body: body);

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

      // ignore: unnecessary_null_comparison
      if (response != null) {
        final data = json.decode(response);
        if (data['routes']?.isNotEmpty ?? false) {
          final polyline = data['routes'][0]['polyline']['encodedPolyline'];
          List<PointLatLng> decodedPolyline =
              polylinePoints.decodePolyline(polyline);
          List<LatLng> polylineCoordinates = decodedPolyline
              .map((point) => LatLng(point.latitude, point.longitude))
              .toList();

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

          ShowMessage().showToast('Route generated successfully');
          return;
        }
      }
      ShowMessage().showToast('Failed to generate route');
      if (kDebugMode) {
        print('Failed to generate route: $response');
      }
    } catch (e) {
      ShowMessage().showToast('Error: ${e.toString()}');
    }
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

  // late final CameraPosition _initialCameraPosition;
  // final Completer<GoogleMapController> _controllerCompleter = Completer();

  @override
  Widget build(BuildContext context) {
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
                  onMapCreated: (controller) =>
                      _mapControllerCompleter.complete(controller),
                  initialCameraPosition: CameraPosition(
                    target: currentLocation!,
                    zoom: 15,
                  ),
                  markers: {
                    Marker(
                      markerId: const MarkerId('StartingLocation'),
                      position: StartingLocation,
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueGreen),
                    ),
                    Marker(
                      markerId: const MarkerId('MiddleLocation'),
                      position: MiddleLocation,
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueGreen),
                    ),
                    Marker(
                      markerId: const MarkerId('EndingLocation'),
                      position: EndingLocation,
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueOrange),
                    ),
                  },
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
                animateToLocation(currentLocation!);
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
}
