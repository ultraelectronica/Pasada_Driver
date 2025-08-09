import 'package:flutter/material.dart';
import 'package:pasada_driver_side/presentation/pages/map/utils/map_constants.dart';

/// Error view displayed when map initialization fails
/// Shows error message and retry button
class MapErrorView extends StatelessWidget {
  final String? errorMessage;
  final VoidCallback? onRetry;

  const MapErrorView({
    super.key,
    this.errorMessage,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            color: Colors.red,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            "${MapConstants.initializationErrorPrefix}${errorMessage ?? 'Unknown error'}",
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text(MapConstants.retryButtonText),
            ),
          ],
        ],
      ),
    );
  }
}
