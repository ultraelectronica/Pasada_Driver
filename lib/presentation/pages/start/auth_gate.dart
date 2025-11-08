import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  Future<bool> _hasValidSession() async {
    final auth = Supabase.instance.client.auth;
    final session = auth.currentSession;
    if (session == null) return false;
    // Enforce client-side soft expiry window
    final softExpired = await AuthService.isSessionExpired();
    if (softExpired) {
      try {
        debugPrint('[SESSION] session expired, please log in again.');
        await auth.signOut();
      } catch (_) {}
      await AuthService.deleteSession();
      return false;
    }
    try {
      final expiresAtSec = session.expiresAt; // seconds since epoch (UTC)
      if (expiresAtSec != null) {
        final expiresAt = DateTime.fromMillisecondsSinceEpoch(
                expiresAtSec * 1000,
                isUtc: true)
            .toLocal();
        if (expiresAt
            .isBefore(DateTime.now().add(const Duration(minutes: 1)))) {
          // Proactively refresh if expiring
          final refreshed = await auth.refreshSession();
          return refreshed.session != null;
        }
      }
    } catch (_) {}
    return true;
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
      // Ensure background booking watcher is active while authenticated
      if (mounted) {
        BookingBackgroundService.instance.start(context);
      }
    }
  }

  Future<void> _loadUserData() async {
    try {
      // Load driver data
      final driverProv = context.read<DriverProvider>();
      final supa = Supabase.instance.client;

      // Attempt to restore domain context from secure storage
      await driverProv.loadFromSecureStorage(context);

      // Fallback: if context is missing, derive from auth user linkage
      if (driverProv.driverID.isEmpty || driverProv.vehicleID.isEmpty) {
        final uid = supa.auth.currentUser?.id;
        if (uid != null) {
          final resp = await supa
              .from('driverTable')
              .select('driver_id, vehicle_id')
              .eq('auth_user_id', uid)
              .maybeSingle();
          if (resp != null) {
            final driverId = resp['driver_id']?.toString() ?? '';
            final vehicleId = resp['vehicle_id']?.toString() ?? '';
            if (driverId.isNotEmpty) driverProv.setDriverID(driverId);
            if (vehicleId.isNotEmpty) driverProv.setVehicleID(vehicleId);
            // Fetch route and persist domain context
            await driverProv.getDriverRoute();
            await AuthService.saveDriverContext(
              driverId: driverProv.driverID,
              routeId: driverProv.routeID.toString(),
              vehicleId: driverProv.vehicleID,
            );
          }
        }
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
