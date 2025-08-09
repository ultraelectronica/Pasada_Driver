import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pasada_driver_side/presentation/pages/map/utils/map_constants.dart';

/// Custom location button widget
/// Handles animating the camera to the user's current location
class CustomLocationButton extends StatelessWidget {
  final LatLng? currentLocation;
  final VoidCallback? onPressed;
  final bool isVisible;

  const CustomLocationButton({
    super.key,
    this.currentLocation,
    this.onPressed,
    this.isVisible = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible || currentLocation == null) {
      return const SizedBox.shrink();
    }

    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Positioned(
      bottom: screenHeight * MapConstants.locationButtonBottomFraction,
      right: screenWidth * MapConstants.locationButtonRightFraction,
      child: SizedBox(
        width: MapConstants.locationButtonSize,
        height: MapConstants.locationButtonSize,
        child: FloatingActionButton(
          onPressed: onPressed,
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          child: const Icon(
            Icons.my_location,
            color: Colors.black,
            size: 26,
          ),
        ),
      ),
    );
  }
}
