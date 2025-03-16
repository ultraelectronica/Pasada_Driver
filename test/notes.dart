// GoogleMap(
            //   onMapCreated: _onMapCreated,
            //   initialCameraPosition: CameraPosition(
            //     target: LatLng(
            //       _currentLocation!.latitude!,
            //       _currentLocation!.longitude!,
            //     ),
            //     zoom: 15,
            //   ),
            //   markers: {
            //     Marker(
            //       markerId: const MarkerId('StartingLocation'),
            //       position: StartingLocation,
            //       icon: BitmapDescriptor.defaultMarkerWithHue(
            //           BitmapDescriptor.hueGreen),
            //     ),
            //     Marker(
            //       markerId: const MarkerId('EndingLocation'),
            //       position: EndingLocation,
            //       icon: BitmapDescriptor.defaultMarkerWithHue(
            //           BitmapDescriptor.hueGreen),
            //     ),
            //   },
            //   myLocationEnabled: true,
            //   myLocationButtonEnabled: false, // there will be a custom button
            //   mapType: MapType.normal,
            //   zoomControlsEnabled: false,
            //   trafficEnabled:
            //       true, // i just found this kaya try to uncomment this
            // ),

            // // CUSTOM MY LOCATION BUTTON
            // Positioned(
            //   bottom: screenHeight * 0.025,
            //   right: screenWidth * 0.05,
            //   child: SizedBox(
            //     width: 50,
            //     height: 50,
            //     child: FloatingActionButton(
            //       onPressed: () {
            //         mapController.animateCamera(
            //           CameraUpdate.newCameraPosition(
            //             CameraPosition(
            //               target: LatLng(
            //                 _currentLocation!.latitude!,
            //                 _currentLocation!.longitude!,
            //               ),
            //               zoom: 15,
            //             ),
            //           ),
            //         );
            //       },
            //       backgroundColor: Colors.white,
            //       shape: RoundedRectangleBorder(
            //         borderRadius: BorderRadius.circular(15),
            //       ),
            //       child: const Icon(Icons.my_location,
            //           color: Colors.black, size: 26),
            //     ),
            //   ),
            // ),
