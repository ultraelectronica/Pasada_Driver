import 'package:flutter/material.dart';
import 'package:pasada_driver_side/presentation/pages/map/utils/map_constants.dart';

/// Loading view displayed while the map is initializing
/// Shows a loading spinner and message
class MapLoadingView extends StatelessWidget {
  const MapLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            MapConstants.mapLoadingMessage,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
