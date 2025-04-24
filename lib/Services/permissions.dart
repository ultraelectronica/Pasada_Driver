import 'package:location/location.dart';

class CheckPermissions {
  final Location location = Location();

  Future<bool> checkPermissions() async {
    bool locationServicesEnabled = await _checkLocationServices();
    bool locationPermissionGranted = await _checkLocationPermissions();
    return locationServicesEnabled && locationPermissionGranted;
  }

  Future<bool> _checkLocationServices() async {
    bool serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
    }
    return serviceEnabled;
  }

  Future<bool> _checkLocationPermissions() async {
    PermissionStatus permissionGranted = await location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
    }
    return permissionGranted == PermissionStatus.granted;
  }
}
