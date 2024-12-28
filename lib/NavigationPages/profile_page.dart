import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ProfilePage extends StatefulWidget {
  final String driverStatus;

  const ProfilePage({super.key, required this.driverStatus});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // Method to assign color to the driver status
  Color _getStatusColor(String status) {
    switch (status) {
      case "Online":
        return Colors.green;
      case "Driving":
        return Colors.red;
      case "Idling":
        return Colors.orange;
      case "Offline":
      default:
        return Colors.grey;
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
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Driver Profile Picture
              SizedBox(
                height: profilePictureSize,
                width: profilePictureSize,
                child: SvgPicture.asset(
                  'assets/svg/Ellipse.svg',
                  placeholderBuilder: (_) => const CircularProgressIndicator(),
                ),
              ),
              const SizedBox(height: 20),

              // Driver Status
              _buildDriverStatus(),
              const SizedBox(height: 25),

              //Driver Name
              _getDriverName(),
              const SizedBox(height: 10),
              //Driver Email
              _getDriverEmail(),
              const SizedBox(height: 10),

              _getDriverNumber(),
              const SizedBox(height: 10),

              _updateInformationButton(),
              const SizedBox(height: 10),

              ProfileButton('Update Information', onPressed: () {}),
              const SizedBox(height: 20),

              ProfileButton('Log Out', onPressed: () {}),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDriverStatus() {
    return Container(
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
          // Colored dot
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: _getStatusColor(widget.driverStatus),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8), // Spacing between dot and text

          // Status text
          Text(widget.driverStatus),
        ],
      ),
    );
  }

  Widget _getDriverName() {
    return const Text(
      'Name',
      style: TextStyle(
        fontSize: 30,
        fontFamily: 'Inter',
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _getDriverEmail() {
    return const Text(
      'pasadadriver@example.com',
      style: TextStyle(
        fontSize: 16,
        fontFamily: 'Inter',
        fontWeight: FontWeight.w400,
      ),
    );
  }

  Widget _getDriverNumber() {
    return const Text(
      '09123456789',
      style: TextStyle(
        fontSize: 16,
        fontFamily: 'Inter',
        fontWeight: FontWeight.w400,
      ),
    );
  }

  Widget _updateInformationButton() {
    return const SizedBox();
  }
}

class ProfileButton extends StatelessWidget {
  final String buttonName;
  final VoidCallback onPressed;
  const ProfileButton(this.buttonName, {super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
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
