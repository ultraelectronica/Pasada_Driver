import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:pasada_driver_side/Database/AuthService.dart';
import 'package:pasada_driver_side/Database/driver_provider.dart';
import 'package:pasada_driver_side/UI/text_styles.dart';
// import 'package:pasada_driver_side/Database/global.dart';
import 'package:provider/provider.dart';

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
    final double profilePictureSize = MediaQuery.of(context).size.width * 0.25;
    final driverProvider = context.watch<DriverProvider>();
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    // Define colors based on the image
    const Color primaryColor = Color(0xff067837);
    final Color statusColor =
        statusColors[driverProvider.driverStatus] ?? Colors.grey;

    return Scaffold(
      backgroundColor: Styles.customWhite,
      body: Stack(
        children: [
          // --- Top Gradient Background ---
          ClipPath(
            // Wrap the container with ClipPath
            clipper: ProfileBackgroundClipper(), // Apply the custom clipper
            child: Container(
              height:
                  screenHeight * 0.42, // Adjust height if needed for the curve
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
                padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
                child: Column(
                  children: [
                    SizedBox(height: screenHeight * 0.08), // Space from top

                    // --- Profile Picture ---
                    _buildProfilePicture(profilePictureSize),
                    const SizedBox(height: 12),

                    // --- Driver Name ---
                    Text(
                      '${driverProvider.driverFirstName} ${driverProvider.driverLastName}',
                      style: Styles().textStyle(22, Styles.w700Weight,
                          Styles.customWhite), // White text on gradient
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),

                    // --- Driver Status Button ---
                    _buildStatusChip(driverProvider, statusColor),
                    SizedBox(height: screenHeight * 0.09),

                    // --- Driver Info Card ---
                    _buildInfoCard(driverProvider),
                    SizedBox(height: screenHeight * 0.02),

                    // --- Actions Card ---
                    _buildActionsCard(),
                    const SizedBox(height: 30),

                    // --- Log Out Button ---
                    _buildLogoutButton(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Helper Widgets ---

  Widget _buildStatusChip(DriverProvider driverProvider, Color statusColor) {
    return InkWell(
      onTap: () => _showStatusOption(),
      borderRadius: BorderRadius.circular(20), // Make it pill-shaped
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white, // White background for the chip
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
              driverProvider.driverStatus,
              style: Styles().textStyle(14, Styles.w500Weight,
                  Styles.customBlack // Dark text for status
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(DriverProvider driverProvider) {
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
              text: driverProvider.driverNumber.isNotEmpty
                  ? driverProvider.driverNumber
                  : 'No phone number', // Handle empty number
            ),
            const SizedBox(height: 15),
            _buildInfoRow(
              icon: Icons.directions_car, // Use Material Icons
              text: 'Vehicle ID: ${driverProvider.vehicleID}',
            ),
            const SizedBox(height: 15),
            _buildInfoRow(
              icon: Icons.route_outlined,
              text:
                  'Route: ${driverProvider.routeName} (${driverProvider.routeID})', // Combine Route name and ID
            ),
          ],
        ),
      ),
    );
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
                Styles().textStyle(14, Styles.normalWeight, Styles.customBlack),
          ),
        ),
      ],
    );
  }

  Widget _buildActionsCard() {
    return Card(
      elevation: 4,
      shadowColor: Colors.black38,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      color: Colors.white,
      child: Padding(
        padding:
            const EdgeInsets.symmetric(vertical: 0), // Padding around the list
        child: Column(
          children: [
            _buildActionTile(
              icon: Icons.edit_note, // Material Icon
              text: 'Update Information',
              onTap: () {/* TODO: Implement navigation */},
            ),
            _buildDivider(),
            _buildActionTile(
              icon: Icons.settings_outlined, // Material Icon
              text: 'Settings',
              onTap: () {/* TODO: Implement navigation */},
            ),
            _buildDivider(),
            _buildActionTile(
              icon: Icons.help_outline, // Material Icon
              text: 'Help & Support',
              onTap: () {/* TODO: Implement navigation */},
            ),
            _buildDivider(),
            _buildActionTile(
              icon: Icons.info_outline, // Material Icon
              text: 'About',
              onTap: () {/* TODO: Implement navigation */},
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile(
      {required IconData icon,
      required String text,
      required VoidCallback onTap}) {
    return ListTile(
      minTileHeight: 50,
      leading: Icon(icon, color: const Color(0xff067837), size: 20),
      title: Text(
        text,
        style: Styles().textStyle(14, Styles.w500Weight, Styles.customBlack),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }

  Widget _buildDivider() {
    return const Padding(
      padding:
          EdgeInsets.symmetric(horizontal: 15.0), // Indent divider slightly
      child: Divider(height: 1, thickness: 0.5, color: Colors.grey),
    );
  }

  Widget _buildLogoutButton() {
    return OutlinedButton.icon(
      icon: const Icon(Icons.logout, color: Colors.red),
      label: Text(
        'Log out',
        style: Styles().textStyle(16, Styles.w600Weight, Colors.red),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.red,
        side: const BorderSide(color: Colors.red, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
      ),
      onPressed: () {
        AuthService.deleteSession(); // Keep existing logout logic
        // Consider adding navigation back to login screen after logout
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
                      .textStyle(18, Styles.w600Weight, Styles.customBlack),
                ),
              ),
              statusOption('Online'),
              _buildModalDivider(),
              statusOption('Driving'),
              _buildModalDivider(),
              statusOption('Idling'),
              _buildModalDivider(),
              statusOption('Offline'),
              _buildModalDivider(),
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
