import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pasada_driver_side/NavigationPages/Map/google_map.dart';

class NewHomePage extends StatelessWidget {
  const NewHomePage({super.key});

  NewHomePageState createState() => NewHomePageState();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF2F2F2),
        fontFamily: 'Inter',
        useMaterial3: true,
      ),
      home: const NewHomePage(),
      routes: <String, WidgetBuilder>{
        'map': (BuildContext context) => const MapScreen(),
      },
    );
  }
}

class HomeScrenStateful extends StatefulWidget {
  const HomeScrenStateful({super.key});

  @override
  State<HomeScrenStateful> createState() => NewHomePageState();
}

class NewHomePageState extends State<HomeScrenStateful> {
  final GlobalKey<MapScreenState> mapScreenKey = GlobalKey<MapScreenState>();
  DriverRoute? startingLocation;
  DriverRoute? endingLocation;

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      body: LayoutBuilder(builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final responsivePadding = screenWidth * 0.05;
        const bottomNavBarHeight = 20.0;

        return Stack(
          children: [
            MapScreen(
              key: mapScreenKey,
              initialLocation: startingLocation?.coordinates,
              finalLocation: endingLocation?.coordinates,
            ),

            Positioned(
              bottom: bottomNavBarHeight,
              left: responsivePadding,
              right: responsivePadding,
              // ignore: prefer_const_constructors
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                // ignore: prefer_const_literals_to_create_immutables
                children: [
                  // Location FAB
                  // LocationFAB(
                  //   heroTag: "homeLocationFAB",
                  //   onPressed: () => mapScreenKey.currentState,
                  //   iconSize: iconSize,
                  //   buttonSize: screenWidth * 0.12,
                  // ),
                  // SizedBox(height: fabVerticalSpacing),
                  // // Location Container
                  // Container(
                  //   key: containerKey,
                  //   child: buildL ocationContainer(
                  //     context,
                  //     screenWidth,
                  //     responsivePadding,
                  //     iconSize,
                  //   ),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }
}

class DriverRoute {
  final String address;
  final LatLng coordinates;

  DriverRoute({
    required this.address,
    required this.coordinates,
  });
}
