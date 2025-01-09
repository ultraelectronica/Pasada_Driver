import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pasada_driver_side/global.dart';

class ProfilePage extends StatefulWidget {
  final String driverStatus;

  const ProfilePage({super.key, required this.driverStatus});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late String currentStatus;

  @override
  void initState() {
    super.initState();
    currentStatus = widget.driverStatus; // method to initialize the status
  }

  // Colors for different statuses
  static const Map<String, Color> statusColors = {
    "Online": Colors.green,
    "Driving": Colors.red,
    "Idling": Colors.orange,
    "Offline": Colors.grey,
  };

  // Function to show a bottom sheet with status options
  void _showStatusOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              //Line which indicates that the pop up screen is swipeable
              Container(
                width: 40,
                height: 5,
                margin: const EdgeInsets.only(top: 16.0, bottom: 16.0),
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              // Title
              const Padding(
                padding: EdgeInsets.only(bottom: 10.0),
                child: Text(
                  'Change Status',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ...statusColors.keys.map((status) {
                return Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.circle, color: statusColors[status]),
                      title: Text(status),
                      onTap: () => _updateStatus(status),
                    ),
                    // line below the choices
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20.0),
                      child: Divider(
                        thickness: 1.0,
                        color: Colors.grey,
                        height: 1.0,
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
        );
      },
    );
  }

  // Update driver status and close bottom sheet
  void _updateStatus(String newStatus) async {
    try {
      setState(() {
        currentStatus = newStatus;
        GlobalVar().updateStatus(GlobalVar().driverStatus.indexOf(newStatus));
      });
      // await _updateStatusInDatabase(newStatus);
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update status: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final double paddingValue = MediaQuery.of(context).size.width * 0.05;
    final double profilePictureSize = MediaQuery.of(context).size.width * 0.3;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: paddingValue),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Profile Picture
              _buildProfilePicture(profilePictureSize),
              const SizedBox(height: 20),

              // Driver Status
              _buildDriverStatus(),
              const SizedBox(height: 25),

              // Driver Details
              _buildDriverDetails(),
              const SizedBox(height: 30),

              // Buttons
              ProfileButton('Update Information', onPressed: () {}),
              const SizedBox(height: 20),
              ProfileButton('Log Out', onPressed: () {}),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfilePicture(double size) {
    return SizedBox(
      height: size,
      width: size,
      child: SvgPicture.asset(
        'assets/svg/Ellipse.svg',
        placeholderBuilder: (_) => const CircularProgressIndicator(),
      ),
    );
  }

//driver status
  Widget _buildDriverStatus() {
    return ValueListenableBuilder<String>(
      valueListenable: GlobalVar().currentStatusNotifier,
      builder: (context, status, child) {
        return InkWell(
          onTap: _showStatusOptions,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            height: 30,
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).primaryColor,
                width: 2.0,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: statusColors[status],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(status),
              ],
            ),
          ),
        );
      },
    );
  }

//driver details
  Widget _buildDriverDetails() {
    return const Column(
      children: [
        Text(
          'Name',
          style: TextStyle(
            fontSize: 30,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 10),
        Text(
          'pasadadriver@example.com',
          style: TextStyle(
            fontSize: 16,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w400,
          ),
        ),
        SizedBox(height: 10),
        Text(
          '09123456789',
          style: TextStyle(
            fontSize: 16,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

//build all buttons
class ProfileButton extends StatelessWidget {
  final String buttonName;
  final VoidCallback onPressed;

  const ProfileButton(this.buttonName, {super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(30.0),
      onTap: onPressed,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          border: Border.all(
            color: const Color(0xFF5F3FC4),
            width: 2.0,
          ),
          borderRadius: BorderRadius.circular(30.0),
        ),
        alignment: Alignment.center,
        child: Text(
          buttonName,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
