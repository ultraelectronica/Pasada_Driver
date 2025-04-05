import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:pasada_driver_side/Database/AuthService.dart';
import 'package:pasada_driver_side/Database/driver_provider.dart';
import 'package:pasada_driver_side/Database/map_provider.dart';
import 'package:pasada_driver_side/UI/text_styles.dart';
// import 'package:pasada_driver_side/Database/global.dart';
import 'package:provider/provider.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<StatefulWidget> createState() => ProfilePageState();
}

class ProfilePageState extends State<ProfilePage> {
  String currentStatus = 'Online';
  final Map<String, Color> statusColors = {
    "Online": Colors.green,
    "Driving": Colors.red,
    "Idling": Colors.orange,
    "Offline": Colors.grey,
  };

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final double paddingValue = MediaQuery.of(context).size.width * 0.05;
    final double profilePictureSize = MediaQuery.of(context).size.width * 0.25;
    final driverProvider = context.watch<DriverProvider>();
    final mapProvider = context.watch<MapProvider>();

    return Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: paddingValue),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // --- Row for Profile Picture and Details ---
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Profile Picture
                  _buildProfilePicture(profilePictureSize),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildDriverDetails(driverProvider, mapProvider),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ],
              ),
              // Driver Status Button
              InkWell(
                onTap: () {
                  _showStatusOption();
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: paddingValue * 0.5),
                  height: 30,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.black87,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        height: 10,
                        width: 10,
                        decoration: BoxDecoration(
                          color: statusColors[driverProvider.driverStatus],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        driverProvider.driverStatus,
                        style: Styles().textStyle(
                            14, Styles.normalWeight, Styles.customBlack),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 30), // Space after status button

              _buildProfileSection(
                title: 'Additional Driver Info',
                paddingValue: paddingValue,
                items: [
                  _buildAdditionalDriverInfo(driverProvider, paddingValue * 2),
                ],
              ),

              const SizedBox(height: 30),

              // MY ACCOUNT SECTION
              _buildProfileSection(
                title: 'My Account',
                paddingValue: paddingValue,
                items: [
                  _buildProfileListItem(
                      paddingValue: paddingValue,
                      button_name: 'Edit profile',
                      onPressed: () {}),
                  _buildProfileListItem(
                      paddingValue: paddingValue,
                      button_name: 'Log out',
                      highlightColor: Colors.red,
                      onPressed: () {
                        AuthService.deleteSession();
                      }),
                ],
              ),
              const SizedBox(height: 30),

              // SETTINGS SECTION
              _buildProfileSection(
                title: 'Settings',
                paddingValue: paddingValue,
                items: [
                  _buildProfileListItem(
                      paddingValue: paddingValue,
                      button_name: 'Preferences',
                      onPressed: () {
                        // TODO: Navigate to preferences page
                      }),
                  _buildProfileListItem(
                      paddingValue: paddingValue,
                      button_name: 'Contact Support',
                      onPressed: () {
                        // TODO: Navigate to contact support page
                      }),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showStatusOption() {
    showModalBottomSheet(
        context: context,
        builder: (BuildContext context) {
          return SafeArea(
              child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 5,
                margin: const EdgeInsets.only(top: 16.0, bottom: 16.0),
                decoration: BoxDecoration(
                    color: Colors.grey[600],
                    borderRadius: BorderRadius.circular(10)),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: Text(
                  'Change Status',
                  style: Styles()
                      .textStyle(18, Styles.w600Weight, Styles.customBlack),
                ),
              ),
              statusOption('Online'),
              divider(),
              statusOption('Driving'),
              divider(),
              statusOption('Idling'),
              divider(),
              statusOption('Offline'),
              divider(),
              const SizedBox(height: 20)
            ],
          )); // Add a non-nullable widget here
        });
  }

  Padding divider() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.0),
      child: Divider(
        thickness: 1.0,
        color: Colors.grey,
        height: 1.0,
      ),
    );
  }

  ListTile statusOption(String status) {
    return ListTile(
      leading: Icon(Icons.circle, color: statusColors[status]),
      title: Text(status,
          style: Styles().textStyle(16, Styles.w500Weight, Styles.customBlack)),
      onTap: () {
        setState(() {
          if (status != 'Driving') {
            context.read<DriverProvider>().setIsDriving(false);
            // ShowMessage()
            //     .showToast(context.read<DriverProvider>().isDriving.toString());
          }
          context.read<DriverProvider>().updateStatusToDB(status, context);
          context.read<DriverProvider>().setDriverStatus(status);
        });

        Navigator.of(context).pop();
      },
    );
  }

  Widget _buildProfilePicture(double size) {
    // Add a Container with border decoration
    return Container(
      padding: const EdgeInsets.all(2.0), // Space between border and picture
      decoration: BoxDecoration(
        color: Colors.grey[300], // Border color
        shape: BoxShape.circle,
      ),
      child: SizedBox(
          height: size,
          width: size,
          child: ClipOval(
            // Clip the SVG to the circle
            child: SvgPicture.asset(
              'assets/svg/Ellipse.svg', // Keep user-updated SVG
              fit: BoxFit.cover, // Ensure SVG fills the circle
              placeholderBuilder: (_) => const CircularProgressIndicator(),
            ),
          )),
    );

    // Old SizedBox implementation
    //  return SizedBox(
    //    height: size,
    //    width: size,
    //    child: SvgPicture.asset(
    //      'assets/svg/Ellipse.svg', // Keep user-updated SVG
    //      placeholderBuilder: (_) => const CircularProgressIndicator(),
    //    ),
    //  );
  }

  Widget _buildDriverDetails(
      DriverProvider driverProvider, MapProvider mapProvider) {
    return Text(
      '${driverProvider.driverFirstName} ${driverProvider.driverLastName}',
      style: Styles().textStyle(24, Styles.w700Weight, Styles.customBlack),
    );
  }

  Widget _buildAdditionalDriverInfo(
      DriverProvider driverProvider, double paddingValue) {
    TextStyle detailStyle =
        Styles().textStyle(14, Styles.normalWeight, Styles.customBlack);
    return Padding(
      padding:
          EdgeInsets.symmetric(horizontal: paddingValue * 0.75, vertical: 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Driver Number: ${driverProvider.driverNumber}',
              style: detailStyle,
            ),
            const SizedBox(height: 8),
            Text(
              'Vehicle ID: ${driverProvider.vehicleID}',
              style: detailStyle,
            ),
            const SizedBox(height: 8),
            Text(
              'Route: ${driverProvider.routeName} (ID: ${driverProvider.routeID})',
              style: detailStyle,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, double paddingValue) {
    return Text(
      title,
      style: Styles().textStyle(18, Styles.w600Weight, Styles.customBlack),
    );
  }

  Widget _buildProfileListItem({
    required double paddingValue,
    required String button_name,
    required VoidCallback onPressed,
    Color? highlightColor,
  }) {
    final double itemHorizontalPadding = paddingValue * 0.5;

    return Column(
      children: [
        ListTile(
          contentPadding:
              EdgeInsets.symmetric(horizontal: itemHorizontalPadding),
          title: Text(
            button_name,
            style: Styles().textStyle(
              16,
              Styles.normalWeight,
              highlightColor ?? Styles.customBlack,
            ),
          ),
          trailing: SvgPicture.asset('assets/svg/rightArrow.svg', height: 15),
          onTap: onPressed,
          dense: true,
          visualDensity: VisualDensity.compact,
        ),
        Divider(
          height: 1,
          thickness: 1,
          indent: itemHorizontalPadding,
          endIndent: itemHorizontalPadding,
          color: Colors.grey,
        ),
      ],
    );
  }

  // New helper method to build a section with title and items
  Widget _buildProfileSection({
    required String title,
    required double paddingValue,
    required List<Widget> items,
  }) {
    final double titleHorizontalPadding = paddingValue * 0.5;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Padding for the title
        Padding(
          padding: EdgeInsets.only(
              top: 0,
              bottom: 4.0,
              left: titleHorizontalPadding,
              right: titleHorizontalPadding),
          child: _buildSectionTitle(title, paddingValue),
        ),
        // Add the list items directly
        ...items,
      ],
    );
  }
}
