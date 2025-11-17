import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:pasada_driver_side/Services/auth_service.dart';
import 'package:pasada_driver_side/common/constants/message.dart';
import 'package:pasada_driver_side/presentation/pages/main/main_page.dart';
import 'package:pasada_driver_side/main.dart'
    show AuthPagesView; // Re-use existing AuthPagesView
import 'package:pasada_driver_side/presentation/providers/driver/driver_provider.dart';
import 'package:pasada_driver_side/presentation/providers/map_provider.dart';
import 'package:pasada_driver_side/presentation/providers/passenger/passenger_provider.dart';
import 'package:pasada_driver_side/presentation/widgets/error_retry_widget.dart';
import 'package:pasada_driver_side/common/utils/result.dart';
import 'package:pasada_driver_side/common/logging.dart';
import 'package:pasada_driver_side/presentation/pages/route_setup/route_selection_sheet.dart';
import 'package:pasada_driver_side/domain/services/background_location_service.dart';
import 'package:pasada_driver_side/domain/services/booking_background_service.dart';

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

  /// Determine if we have a locally stored driver context that can be used to
  /// restore a logged-in session. This no longer relies on Supabase Auth and
  /// only checks secure storage via [AuthService] / [DriverProvider].
  Future<bool> _hasValidSession() async {
    try {
      // First try to hydrate the provider from secure storage.
      final driverProv = context.read<DriverProvider>();
      final restored = await driverProv.loadFromSecureStorage(context);
      if (restored && driverProv.driverID.isNotEmpty) {
        return true;
      }

      // As a fallback, inspect raw driver context directly from storage.
      final ctx = await AuthService.getDriverContext();
      final driverId = ctx[AuthService.keyDriverId] ?? ctx['driver_id'];
      if (driverId != null && driverId.toString().isNotEmpty) {
        driverProv.setDriverID(driverId.toString());
        final vehicleId = ctx[AuthService.keyVehicleId] ?? ctx['vehicle_id'];
        if (vehicleId != null && vehicleId.toString().isNotEmpty) {
          driverProv.setVehicleID(vehicleId.toString());
        }
        final routeIdRaw = ctx[AuthService.keyRouteId] ?? ctx['route_id'];
        final routeId = int.tryParse(routeIdRaw?.toString() ?? '0') ?? 0;
        if (routeId > 0) {
          driverProv.setRouteID(routeId);
        }
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _checkSession() async {
    final hasSession = await _hasValidSession();
    if (!mounted) return;

    setState(() {
      _hasSession = hasSession;
      _isLoading = false;
    });

    if (!hasSession && kDebugMode) {
      logDebug('No local session data detected');
    }

    // User is still logged in, load additional data
    if (hasSession) {
      await _loadUserData();
      // Ensure background booking watcher is active while "logged in"
      if (mounted) {
        BookingBackgroundService.instance.start(context);
      }
    }
  }

  Future<void> _loadUserData() async {
    try {
      // Load driver data purely from local driver context / provider.
      final driverProv = context.read<DriverProvider>();

      // Ensure provider is hydrated from secure storage if needed.
      if (driverProv.driverID.isEmpty || driverProv.vehicleID.isEmpty) {
        await driverProv.loadFromSecureStorage(context);
      }

      // Start foreground service to keep app running in background
      await BackgroundLocationService.instance.start();
      if (kDebugMode) {
        logDebug('Background foreground service started on app restart');
      }

      // Continue after first frame to ensure providers are ready
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;

        final driverProvider = context.read<DriverProvider>();
        final mapProvider = context.read<MapProvider>();
        final passengerProvider = context.read<PassengerProvider>();

        // Log login time once we are sure session and provider are loaded
        await driverProvider.writeLoginTime(context);

        // Validate route id
        if (driverProvider.routeID > 0) {
          logDebug(
              'Fetching route coordinates for route: ${driverProvider.routeID}');

          await mapProvider.getRouteCoordinates(driverProvider.routeID);

          mapProvider.setRouteID(driverProvider.routeID);

          // Load and cache allowed stops for the route
          await driverProvider.loadAndCacheAllowedStops();

          await passengerProvider.getBookingRequestsID(context);
        } else {
          logDebug('No valid route ID found: ${driverProvider.routeID}');
          if (mounted) {
            final selected = await RouteSelectionSheet.show(context);
            if (selected != null) {
              await mapProvider.getRouteCoordinates(selected);
              debugPrint(
                  'AuthGate: Updating status to Online (after selection)');
              await driverProvider.updateStatusToDB('Online');
              // Ensure the new status is preserved if app is backgrounded immediately
              driverProvider.setLastDriverStatus('Online');
              mapProvider.setRouteID(selected);

              // Load and cache allowed stops for the newly selected route
              await driverProvider.loadAndCacheAllowedStops();

              await passengerProvider.getBookingRequestsID(context);
            }
          }
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
      return const AuthPagesView();
    }
  }
}
