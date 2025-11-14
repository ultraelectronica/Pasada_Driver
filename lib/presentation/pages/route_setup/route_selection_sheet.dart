import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:pasada_driver_side/presentation/providers/driver/driver_provider.dart';
import 'package:pasada_driver_side/presentation/providers/map_provider.dart';
import 'package:pasada_driver_side/presentation/providers/passenger/passenger_provider.dart';
import 'package:pasada_driver_side/common/constants/message.dart';
import 'package:pasada_driver_side/common/constants/constants.dart';
import 'package:pasada_driver_side/common/constants/text_styles.dart';
import 'package:pasada_driver_side/presentation/pages/home/utils/snackbar_utils.dart';
import 'package:cherry_toast/resources/arrays.dart';

class RouteSelectionSheet {
  static Future<int?> show(BuildContext context,
      {bool isMandatory = false}) async {
    // Guard: require a vehicle assigned before showing routes
    final driverProv = context.read<DriverProvider>();
    final vehicleId = driverProv.vehicleID;
    final normalizedVehicleId = vehicleId.trim().toLowerCase();
    final hasVehicle = normalizedVehicleId.isNotEmpty &&
        normalizedVehicleId != 'n/a' &&
        normalizedVehicleId != 'null';

    if (!hasVehicle) {
      SnackBarUtils.show(
        context,
        'Vehicle required to select a route',
        'Your account has no vehicle assigned. Please contact your admin before selecting a route.',
        duration: const Duration(seconds: 3),
        backgroundColor: Colors.red,
        position: Position.top,
        animationType: AnimationType.fromTop,
      );
      return null;
    }

    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      isDismissible: !isMandatory,
      enableDrag: !isMandatory,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => const _RouteSelectionContent(),
    );
  }
}

class _RouteSelectionContent extends StatefulWidget {
  const _RouteSelectionContent();

  @override
  State<_RouteSelectionContent> createState() => _RouteSelectionContentState();
}

class _RouteSelectionContentState extends State<_RouteSelectionContent> {
  final SupabaseClient _supabase = Supabase.instance.client;
  late Future<List<_OfficialRoute>> _routesFuture;
  int? _savingRouteId;

  @override
  void initState() {
    super.initState();
    _routesFuture = _fetchRoutes();
  }

  Future<List<_OfficialRoute>> _fetchRoutes() async {
    final resp = await _supabase
        .from('official_routes')
        .select('officialroute_id, route_name')
        .eq('status', 'active')
        .order('route_name');

    final List<_OfficialRoute> routes = [];
    for (final item in resp as List<dynamic>) {
      final map = item as Map<String, dynamic>;
      final id = map['officialroute_id'];
      final name = map['route_name']?.toString() ?? 'Route $id';
      if (id is int) {
        routes.add(_OfficialRoute(id: id, name: name));
      } else if (id is String) {
        final parsed = int.tryParse(id);
        if (parsed != null) routes.add(_OfficialRoute(id: parsed, name: name));
      }
    }
    return routes;
  }

  Future<void> _selectRoute(_OfficialRoute route) async {
    if (_savingRouteId != null) return;
    setState(() => _savingRouteId = route.id);

    try {
      final driverProv = context.read<DriverProvider>();
      final passengerProv = context.read<PassengerProvider?>();
      final bool hasActiveBooking = passengerProv?.bookings.any(
            (b) => b.rideStatus == 'accepted' || b.rideStatus == 'ongoing',
          ) ??
          false;
      if (driverProv.driverStatus == 'Driving' || hasActiveBooking) {
        if (mounted) {
          ShowMessage().showToast(
              'Cannot change route while Driving or with active booking');
        }
        setState(() => _savingRouteId = null);
        return;
      }
      final mapProv = context.read<MapProvider>();

      await _supabase.from('vehicleTable').update({'route_id': route.id}).eq(
          'vehicle_id', driverProv.vehicleID);

      await _supabase.from('driverTable').update(
          {'currentroute_id': route.id}).eq('driver_id', driverProv.driverID);

      driverProv.setRouteID(route.id);
      await mapProv.getRouteCoordinates(route.id);
      mapProv.setRouteID(route.id);

      // Load and cache allowed stops for the newly selected route
      await driverProv.loadAndCacheAllowedStops();

      // Trigger polyline refresh
      if (mapProv.currentLocation != null && mapProv.endingLocation != null) {
        final waypoints = <LatLng>[];
        if (mapProv.intermediateLoc1 != null) {
          waypoints.add(mapProv.intermediateLoc1!);
        }
        if (mapProv.intermediateLoc2 != null) {
          waypoints.add(mapProv.intermediateLoc2!);
        }
        await mapProv.generatePolyline(
          start: mapProv.currentLocation!,
          end: mapProv.endingLocation!,
          waypoints: waypoints.isEmpty ? null : waypoints,
        );
      }

      if (mounted) {
        ShowMessage().showToast('Route set to ${route.name}');
        Navigator.of(context).pop<int>(route.id);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('RouteSelectionSheet: error setting route $e');
      }
      if (mounted) {
        ShowMessage().showToast('Failed to set route: $e');
      }
    } finally {
      if (mounted) setState(() => _savingRouteId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final currentRouteId =
        context.select<DriverProvider, int>((p) => p.routeID);
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Select Route',
              style: Styles()
                  .textStyle(18, Styles.semiBold, Styles.customBlackFont),
            ),
            const SizedBox(height: 8),
            FutureBuilder<List<_OfficialRoute>>(
              future: _routesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(24.0),
                    child: CircularProgressIndicator(),
                  );
                }
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        const Text('Failed to load routes'),
                        const SizedBox(height: 8),
                        Text(snapshot.error.toString(),
                            textAlign: TextAlign.center),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _routesFuture = _fetchRoutes();
                            });
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                final routes = snapshot.data ?? const <_OfficialRoute>[];
                if (routes.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Text('No routes available'),
                  );
                }

                return Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: routes.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final route = routes[index];
                      final bool isCurrent = route.id == currentRouteId;
                      return ListTile(
                        tileColor: isCurrent
                            ? Constants.GREEN_COLOR.withValues(alpha: 0.1)
                            : null,
                        leading: Icon(
                          Icons.route,
                          color: Constants.GREEN_COLOR,
                          size: 24,
                        ),
                        title: Text(
                          route.name,
                          style: Styles().textStyle(
                              16, Styles.semiBold, Styles.customBlackFont),
                        ),
                        subtitle: Text(isCurrent
                            ? 'Current route • ID: ${route.id}'
                            : 'Route ID: ${route.id}'),
                        trailing: (_savingRouteId == route.id)
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : isCurrent
                                ? Icon(Icons.check_circle,
                                    color: Constants.GREEN_COLOR, size: 22)
                                : const Icon(Icons.chevron_right),
                        onTap: (_savingRouteId != null || isCurrent)
                            ? null
                            : () => _selectRoute(route),
                      );
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _OfficialRoute {
  final int id;
  final String name;
  const _OfficialRoute({required this.id, required this.name});
}
