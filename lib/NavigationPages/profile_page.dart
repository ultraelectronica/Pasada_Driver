import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart' show SvgPicture;
import 'package:pasada_driver_side/Database/driver_provider.dart';
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
    final double profilePictureSize = MediaQuery.of(context).size.width * 0.3;
    final driverProvider = context.watch<DriverProvider>();

    return Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: paddingValue),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildProfilePicture(profilePictureSize),
              const SizedBox(height: 20),
              _buildDriverDetails(driverProvider),
              const SizedBox(height: 20),

              //Driver Status Button
              InkWell(
                onTap: () {
                  _showStatusOption();
                  // setState(() {
                  //   currentStatus = 'Driving';
                  // });
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
                        style: textStyle(14, FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 50),

              //Buttons
              _buildProfileButtons(
                  paddingValue: paddingValue,
                  button_name: 'Update Information',
                  onPressed: () {}),
              const SizedBox(height: 10),

              _buildProfileButtons(
                  paddingValue: paddingValue,
                  button_name: 'Settings',
                  onPressed: () {}),
              const SizedBox(height: 10),

              _buildProfileButtons(
                  paddingValue: paddingValue,
                  button_name: 'Log out',
                  onPressed: () {}),
              const SizedBox(height: 10),
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
                padding: EdgeInsets.only(bottom: 10.0),
                child: Text(
                  'Change Status',
                  style: textStyle(18, FontWeight.bold),
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
      title: Text(status, style: textStyle(16, FontWeight.w500)),
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

  TextStyle textStyle(double size, FontWeight weight) {
    return TextStyle(
      fontSize: size,
      fontFamily: 'Inter',
      fontWeight: weight,
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

  Widget _buildDriverDetails(DriverProvider driverProvider) {
    return Column(
      children: [
        Text(
          '${driverProvider.driverFirstName} ${driverProvider.driverLastName}',
          // '$_firstName $_lastName',
          style: textStyle(38, FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Text(
          driverProvider.driverNumber,
          style: textStyle(16, FontWeight.w400),
        ),
        const SizedBox(height: 10),
        Text(
          'Vehicle ID: ${context.read<DriverProvider>().driverID}',
          style: textStyle(16, FontWeight.w400),
        ),
      ],
    );
  }
}

Widget _buildProfileButtons({
  required double paddingValue,
  required String button_name,
  required VoidCallback onPressed,
}) {
  return ProfileButton(
    paddingValue: paddingValue,
    buttonName: button_name,
    onPressed: onPressed,
  );
}

class ProfileButton extends StatelessWidget {
  final VoidCallback onPressed;
  final double paddingValue;
  final String buttonName;

  const ProfileButton({
    super.key,
    required this.paddingValue,
    required this.buttonName,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        height: 40,
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(width: 1),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: paddingValue * 0.5),

          // Contents
          child: Row(
            children: [
              Text(
                buttonName,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              SvgPicture.asset('assets/svg/rightArrow.svg', height: 18),
              // const Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
