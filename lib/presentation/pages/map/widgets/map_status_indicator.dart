import 'package:flutter/material.dart';
import 'package:pasada_driver_side/presentation/pages/map/utils/map_constants.dart';

/// Status indicator widget that shows the current map initialization state
/// Displays loading messages during map setup
class MapStatusIndicator extends StatelessWidget {
  final MapInitState initState;
  final bool isVisible;

  const MapStatusIndicator({
    super.key,
    required this.initState,
    this.isVisible = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible ||
        initState == MapInitState.initialized ||
        initState == MapInitState.error) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: MapConstants.statusIndicatorTop,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: MapConstants.statusIndicatorPadding,
            vertical: MapConstants.statusIndicatorVerticalPadding,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(MapConstants.statusBackgroundAlpha),
            borderRadius:
                BorderRadius.circular(MapConstants.statusIndicatorBorderRadius),
          ),
          child: Text(
            MapUtils.getStatusMessage(initState),
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }
}
