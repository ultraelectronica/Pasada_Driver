import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Displays a user-friendly error screen when the application fails during
/// the bootstrap phase (e.g. env load, Supabase init, permissions).
///
///  • [error] – human-readable error message.
///  • [stackTrace] – optional stack trace shown only in debug mode.
///  • [onRetry] – optional callback to retry the initialization.
class AppBootstrapErrorScreen extends StatelessWidget {
  final String error;
  final String stackTrace;
  final VoidCallback? onRetry;

  const AppBootstrapErrorScreen({
    super.key,
    required this.error,
    this.stackTrace = '',
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Pasada Driver - Error',
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        primaryColor: Colors.red,
        useMaterial3: true,
      ),
      home: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.red,
          title: const Text('Initialization Error',
              style: TextStyle(color: Colors.white)),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'The app encountered an error during startup:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(error, style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 24),
              if (kDebugMode) ...[
                const Text(
                  'Stack Trace:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.grey[200],
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Text(stackTrace,
                        style: const TextStyle(fontFamily: 'monospace')),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              if (onRetry != null)
                Center(
                  child: ElevatedButton(
                    onPressed: onRetry,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Retry'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
