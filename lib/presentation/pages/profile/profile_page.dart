import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:pasada_driver_side/Services/auth_service.dart';
import 'package:pasada_driver_side/presentation/providers/driver/driver_provider.dart';
import 'package:pasada_driver_side/presentation/providers/map_provider.dart';
import 'package:pasada_driver_side/common/constants/text_styles.dart';
import 'package:provider/provider.dart';
import 'package:pasada_driver_side/presentation/widgets/error_retry_widget.dart';
import 'package:pasada_driver_side/presentation/pages/profile/utils/profile_constants.dart';
import 'package:pasada_driver_side/common/constants/constants.dart';

// --- Custom Clipper for Background Shape ---
class ProfileBackgroundClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();

    // Start at top-left
    path.lineTo(0, size.height * 0.85); // Go down most of the left side

    // Create a quadratic bezier curve for the bottom edge
    // Control point is centered horizontally and at the bottom vertically
    // End point is at the bottom-right corner, adjusted height
    path.quadraticBezierTo(
      size.width / 2, // Control point X (center)
      size.height, // Control point Y (bottom)
      size.width, // End point X (right edge)
      size.height * 0.85, // End point Y (matching the start height)
    );

    path.lineTo(size.width, 0); // Go up the right side
    path.close(); // Close the path back to the top-left origin

    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) {
    return false; // The shape is static
  }
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<StatefulWidget> createState() => ProfilePageState();
}

class ProfilePageState extends State<ProfilePage> {
  // String currentStatus = 'Online'; // Keep driverProvider.driverStatus
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
    // final double paddingValue = MediaQuery.of(context).size.width * 0.05; // Use specific padding values
    final double profilePictureSize = MediaQuery.of(context).size.width *
        ProfileConstants.profilePictureFraction;

    // Provider reactive values
    final driverName =
        context.select<DriverProvider, String?>((p) => p.driverFullName);
    final driverStatus =
        context.select<DriverProvider, String>((p) => p.driverStatus);
    final driverNumber =
        context.select<DriverProvider, String>((p) => p.driverNumber);
    final plateNumber =
        context.select<DriverProvider, String>((p) => p.plateNumber);
    final vehicleId =
        context.select<DriverProvider, String>((p) => p.vehicleID);
    final routeId = context.select<DriverProvider, int>((p) => p.routeID);
    final routeNameDrv =
        context.select<DriverProvider, String>((p) => p.routeName);

    final mapRouteName =
        context.select<MapProvider, String?>((m) => m.routeName);
    final mapRouteId = context.select<MapProvider, int>((m) => m.routeID);

    final isLoading = context.select<DriverProvider, bool>((p) => p.isLoading);
    final errorMsg =
        context.select<DriverProvider, String?>((p) => p.error?.message);

    // Derive colors and display strings
    final Color statusColor = statusColors[driverStatus] ?? Colors.grey;
    final String routeDisplay = _composeRouteDisplay(
      mapRouteName: mapRouteName,
      mapRouteId: mapRouteId,
      driverRouteName: routeNameDrv,
      driverRouteId: routeId,
    );

    // Define colors based on the image
    const Color primaryColor = Color(0xff067837);

    // 3-state rendering
    Widget bodyContent;
    if (isLoading) {
      bodyContent = const Center(child: CircularProgressIndicator());
    } else if (errorMsg != null) {
      bodyContent = ErrorRetryWidget(
        message: errorMsg,
        onRetry: _refreshProfile,
      );
    } else {
      bodyContent = Stack(
        children: [
          // --- Top Gradient Background ---
          ClipPath(
            // Wrap the container with ClipPath
            clipper: ProfileBackgroundClipper(), // Apply the custom clipper
            child: Container(
              height: MediaQuery.of(context).size.height *
                  ProfileConstants.headerHeightFraction, // header height
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryColor, primaryColor],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                // Removed bottom curves for simplicity, add if needed
              ),
            ),
          ),

          // --- Main Content ---
          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: MediaQuery.of(context).size.width *
                        ProfileConstants.horizontalPaddingFraction),
                child: Column(
                  children: [
                    SizedBox(
                        height: MediaQuery.of(context).size.height *
                            ProfileConstants.topSpacerFraction), // top spacer

                    // --- Profile Picture ---
                    _buildProfilePicture(profilePictureSize),
                    const SizedBox(height: 12),

                    // --- Driver Name ---
                    _buildDriverName(driverName ?? ''),
                    const SizedBox(height: 8),

                    // --- Driver Status Button ---
                    _buildStatusChip(driverStatus, statusColor),
                    SizedBox(
                        height: MediaQuery.of(context).size.height *
                            ProfileConstants.statusSpacerFraction),

                    // --- Driver Info Card ---
                    _buildInfoCard(
                        driverNumber, plateNumber, vehicleId, routeDisplay),
                    SizedBox(
                        height: MediaQuery.of(context).size.height *
                            ProfileConstants.infoCardSpacerFraction),

                    // --- Actions Card ---
                    // _buildActionsCard(),
                    // const SizedBox(height: 30),

                    // --- Log Out Button ---
                    _buildLogoutButton(),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Scaffold(backgroundColor: Constants.WHITE_COLOR, body: bodyContent);
  }

  // --- Helper Widgets ---

  Widget _buildDriverName(String driverName) {
    return Text(
      driverName,
      style: Styles().textStyle(22, Styles.bold, Constants.WHITE_COLOR),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildStatusChip(String driverStatus, Color statusColor) {
    return InkWell(
      onTap: () => _showStatusOption(),
      borderRadius: BorderRadius.circular(20), // Make it pill-shaped
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Constants.WHITE_COLOR, // White background for the chip
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Colors.grey,
              blurRadius: 4,
              offset: Offset(0, 2),
            )
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 10,
              width: 10,
              decoration: BoxDecoration(
                color: statusColor, // Use the determined status color
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              driverStatus,
              style: Styles().textStyle(14, Styles.medium,
                  Styles.customBlackFont // Dark text for status
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String driverNumber, String plateNumber,
      String vehicleID, String routeDisplay) {
    return Card(
      elevation: 4,
      shadowColor: Colors.black38,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 20.0),
        child: Column(
          children: [
            _buildInfoRow(
              icon: Icons.phone_android, // Use Material Icons
              text: driverNumber.isNotEmpty
                  ? 'Phone: \t\t\t\t$driverNumber'
                  : 'No phone number', // Handle empty number
            ),
            const SizedBox(height: 15),
            _buildInfoRow(
              icon: Icons.directions_car, // Use Material Icons
              text: 'Vehicle:\t\t\t$plateNumber | $vehicleID',
            ),
            const SizedBox(height: 15),
            _buildInfoRow(
              icon: Icons.route_outlined,
              text: routeDisplay,
            ),
          ],
        ),
      ),
    );
  }

  // Compose route label from provided values
  String _composeRouteDisplay({
    String? mapRouteName,
    int? mapRouteId,
    String? driverRouteName,
    int? driverRouteId,
  }) {
    if (mapRouteName != null && mapRouteName.isNotEmpty) {
      return 'Route: \t\t\t\t$mapRouteName | $mapRouteId';
    }
    if (driverRouteName != null &&
        driverRouteName != 'N/A' &&
        (driverRouteId ?? 0) > 0) {
      return 'Route: \t\t\t\t$driverRouteName | $driverRouteId';
    }
    if ((driverRouteId ?? 0) > 0) {
      return 'Route: \t\t\t\tRoute #$driverRouteId';
    }
    return 'Route: \t\t\t\tNot assigned';
  }

  // Trigger a manual refresh of driver data
  Future<void> _refreshProfile() async {
    final prov = context.read<DriverProvider>();
    prov.clearError();
    prov.setLoading(true);
    await prov.loadFromSecureStorage(context);
    prov.setLoading(false);
  }

  Widget _buildInfoRow({required IconData icon, required String text}) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xff067837), size: 20),
        const SizedBox(width: 15),
        Expanded(
          // Allow text to wrap if needed
          child: Text(
            text,
            style:
                Styles().textStyle(14, Styles.normal, Styles.customBlackFont),
          ),
        ),
      ],
    );
  }

  // TODO: unused_element
  // ignore: unused_element
  Widget _buildActionsCard() {
    return Card(
      elevation: 4,
      shadowColor: Colors.black38,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      color: Colors.white,
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: 0), // Padding around the list
        child: Column(
          children: [
            // _buildActionTile(
            //   icon: Icons.edit_note, // Material Icon
            //   text: 'Update Information',
            //   onTap: () {/* TODO: Implement navigation */},
            // ),
            // _buildDivider(),
            // _buildActionTile(
            //   icon: Icons.settings_outlined, // Material Icon
            //   text: 'Settings',
            //   onTap: () {/* TODO: Implement navigation */},
            // ),
            // _buildDivider(),
            // _buildActionTile(
            //   icon: Icons.help_outline, // Material Icon
            //   text: 'Help & Support',
            //   onTap: () {/* TODO: Implement navigation */},
            // ),
            // _buildDivider(),
            // _buildActionTile(
            //   icon: Icons.info_outline, // Material Icon
            //   text: 'About',
            //   onTap: () {/* TODO: Implement navigation */},
            // ),
          ],
        ),
      ),
    );
  }

  // Widget _buildActionTile(
  //     {required IconData icon,
  //     required String text,
  //     required VoidCallback onTap}) {
  //   return ListTile(
  //     minTileHeight: 50,
  //     leading: Icon(icon, color: const Color(0xff067837), size: 20),
  //     title: Text(
  //       text,
  //       style: Styles().textStyle(14, Styles.w500Weight, Styles.customBlack),
  //     ),
  //     trailing: const Icon(Icons.chevron_right, color: Colors.grey),
  //     onTap: onTap,
  //   );
  // }

  // Widget _buildDivider() {
  //   return const Padding(
  //     padding:
  //         EdgeInsets.symmetric(horizontal: 15.0), // Indent divider slightly
  //     child: Divider(height: 1, thickness: 0.5, color: Colors.grey),
  //   );
  // }

  Widget _buildLogoutButton() {
    return OutlinedButton.icon(
      icon: const Icon(Icons.logout, color: Colors.red),
      label: Text(
        'Log out',
        style: Styles().textStyle(16, Styles.semiBold, Colors.red),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.red,
        side: const BorderSide(color: Colors.red, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
      ),
      onPressed: () {
        _showLogoutConfirmationDialog();
      },
    );
  }

  void _showLogoutConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Confirm Log out',
            style:
                Styles().textStyle(20, Styles.semiBold, Styles.customBlackFont),
          ),
          content: Text(
            'Are you sure you want to log out?',
            style:
                Styles().textStyle(16, Styles.normal, Styles.customBlackFont),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
              },
              child: Text(
                'Cancel',
                style: Styles().textStyle(16, Styles.medium, Colors.grey[700]!),
              ),
            ),
            TextButton(
              onPressed: () {
                AuthService.deleteSession();
                // Close the application
                Navigator.of(context).pop(); // Close dialog
                // Exit the app
                Future.delayed(const Duration(milliseconds: 300), () {
                  SystemNavigator.pop(); // Close the app
                  // If you prefer navigation to login screen instead of closing:
                  // Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                });
              },
              child: Text(
                'Confirm',
                style: Styles().textStyle(16, Styles.medium, Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  // Keep existing methods like _showStatusOption, statusOption, divider (local divider)
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
                      .textStyle(18, Styles.semiBold, Styles.customBlackFont),
                ),
              ),
              statusOption('Online'),
              _buildModalDivider(),
              statusOption('Driving'),
              _buildModalDivider(),
              statusOption('Idling'),
              _buildModalDivider(),
              // statusOption('Offline'),
              // _buildModalDivider(),
              const SizedBox(height: 20)
            ],
          )); // Add a non-nullable widget here
        });
  }

  // Rename the old divider to avoid conflict
  Padding _buildModalDivider() {
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
          style: Styles().textStyle(16, Styles.medium, Styles.customBlackFont)),
      onTap: () async {
        await context.read<DriverProvider>().updateStatusToDB(status);
        Navigator.of(context).pop();
      },
    );
  }

  Widget _buildProfilePicture(double size) {
    // Add a Container with white background and padding for the circular border effect
    return Container(
        padding: const EdgeInsets.all(
            4.0), // Padding creates the white border effect
        decoration: const BoxDecoration(
          color: Colors.white, // White background circle
          shape: BoxShape.circle,
          boxShadow: [
            // Optional: Add subtle shadow like in the image
            BoxShadow(
              color: Colors.black26,
              blurRadius: 5,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: ClipOval(
          // Clip the inner content (SVG)
          child: SizedBox(
            height: size,
            width: size,
            child: SvgPicture.asset(
              'assets/svg/Ellipse.svg', // Keep user-updated SVG (assuming this is the placeholder)
              fit: BoxFit.cover, // Ensure SVG fills the circle
              placeholderBuilder: (_) => Container(
                // Placeholder if SVG fails
                height: size,
                width: size,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.person,
                    size: size * 0.6, color: Colors.grey[600]),
              ),
            ),
          ),
        ));
  }

  // Remove or comment out old/unused helper widgets if no longer needed
  /*
  Widget _buildDriverDetails(
      DriverProvider driverProvider, MapProvider mapProvider) {
    // ... Now handled directly in build method ...
  }

  Widget _buildAdditionalDriverInfo(
      DriverProvider driverProvider, double paddingValue) {
    // ... Replaced by _buildInfoCard and _buildInfoRow ...
  }

  Widget _buildSectionTitle(String title, double paddingValue) {
    // ... Not directly used in the new structure ...
  }

  Widget _buildProfileListItem({ ... }) {
     // ... Replaced by _buildActionTile ...
  }

  Widget _buildProfileSection({ ... }) {
    // ... Replaced by individual cards ...
  }
  */
}
