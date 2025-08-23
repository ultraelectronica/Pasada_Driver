import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:pasada_driver_side/Services/auth_service.dart';
import 'package:pasada_driver_side/UI/message.dart';
import 'package:pasada_driver_side/presentation/pages/main/main_page.dart';
import 'package:pasada_driver_side/main.dart'
    show AuthPagesView; // Re-use existing AuthPagesView
import 'package:pasada_driver_side/presentation/providers/driver/driver_provider.dart';
import 'package:pasada_driver_side/presentation/providers/map_provider.dart';
import 'package:pasada_driver_side/presentation/providers/passenger/passenger_provider.dart';
import 'package:pasada_driver_side/presentation/widgets/error_retry_widget.dart';
import 'package:pasada_driver_side/common/utils/result.dart';
import 'package:pasada_driver_side/common/logging.dart';

/// A gatekeeper widget that decides which tree to show: the authenticated
/// application (`MainPage`) or the authentication flow (`AuthPagesView`). It
/// also handles loading driver data from secure storage and exposes retry logic
/// when initialization fails.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool? _hasSession;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<bool> _hasValidSession() async {
    final sessionData = await AuthService.getSession();
    return sessionData.isNotEmpty;
  }

  Future<void> _checkSession() async {
    final hasSession = await _hasValidSession();
    if (!mounted) return;

    setState(() {
      _hasSession = hasSession;
      _isLoading = false;
    });

    if (!hasSession && kDebugMode) {
      ShowMessage().showToast('No local session data detected');
      logDebug('No local session data detected');
    }

    // User is still logged in, load additional data
    if (hasSession) {
      await _loadUserData();
    }
  }

  Future<void> _loadUserData() async {
    try {
      // Load driver data
      await context.read<DriverProvider>().loadFromSecureStorage(context);

      // Continue after first frame to ensure providers are ready
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;

        final driverProvider = context.read<DriverProvider>();
        final mapProvider = context.read<MapProvider>();
        final passengerProvider = context.read<PassengerProvider>();

        // Validate route id
        if (driverProvider.routeID > 0) {
          logDebug(
              'Fetching route coordinates for route: ${driverProvider.routeID}');

          await mapProvider.getRouteCoordinates(driverProvider.routeID);
          mapProvider.setRouteID(driverProvider.routeID);
          await passengerProvider.getBookingRequestsID(context);
        } else {
          logDebug('No valid route ID found: ${driverProvider.routeID}');
        }
      });
    } catch (e) {
      logDebug('Error loading user data: $e');
      ShowMessage().showToast('Error loading data. Please restart the app.');

      if (mounted) {
        context.read<DriverProvider>().setError(
              Failure(
                  message: 'Failed to load data: $e', type: 'load_user_data'),
            );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final driverFailure =
        context.select<DriverProvider, Failure?>((provider) => provider.error);

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (driverFailure != null) {
      return Scaffold(
        body: ErrorRetryWidget(
          message: driverFailure.message,
          onRetry: _loadUserData,
        ),
      );
    }

    if (_hasSession == true) {
      return const MainPage();
    } else {
      return AuthPagesView();
    }
  }
}
