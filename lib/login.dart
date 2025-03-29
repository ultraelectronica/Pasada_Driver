import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:pasada_driver_side/Messages/message.dart';
import 'package:pasada_driver_side/NavigationPages/main_page.dart';
import 'package:pasada_driver_side/Database/driver_provider.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LogIn extends StatefulWidget {
  const LogIn({super.key});

  @override
  State<LogIn> createState() => _LogInState();
}

class _LogInState extends State<LogIn> {
  final inputDriverIDController = TextEditingController();
  final inputPasswordController = TextEditingController();
  final String passwordSample = '';
  final String emailSample = '';
  bool isPasswordVisible = false;
  String errorMessage = '';
  final bool _loading = false;

  @override
  void dispose() {
    inputDriverIDController.dispose();
    inputPasswordController.dispose();
    super.dispose();
  }

  Future<void> _logIn() async {
    final enteredDriverID = inputDriverIDController.text.trim();
    final enteredPassword = inputPasswordController.text.trim();

    if (enteredDriverID.isEmpty || enteredPassword.isEmpty) {
      ShowMessage().showSnackBar(context, 'Please fill in all fields');
      return;
    }

    try {
      //Query to get the driverID and password from the driverTable
      final response = await Supabase.instance.client
          .from('driverTable')
          .select(
              'driver_id, vehicle_id') // Only retrieve driverID and vehicleID
          .eq('driver_id', enteredDriverID) // Match driverID
          .eq('driver_password', enteredPassword) // Match password
          .select('first_name, driver_id, vehicle_id')
          .single();

      // Saves driver data to the provider
      if (mounted) {
        //Saves driver_id to the provider
        context
            .read<DriverProvider>()
            .setDriverID(response['driver_id'].toString());

        // Saves the driver's vehicle ID to the provider
        context
            .read<DriverProvider>()
            .setVehicleID(response['vehicle_id'].toString());

        context.read<DriverProvider>().getPassengerCapacity(context);

        context.read<DriverProvider>().setDriverStatus('Online');
        if (kDebugMode) {
          print('Vehicle ID: ${response['vehicle_id']}');
        }
      }

      // move to the main page once the driver successfuly logs in
      if (mounted) {
        // _setStatusToOnline(enteredDriverID);
        context.read<DriverProvider>().updateStatusToDB('Online', context);

        ShowMessage().showToastTop('Welcome Manong ${response['first_name']}!');

        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (context) => const MainPage()));
      }
    } catch (e) {
      ShowMessage().showToast('Invalid credentials. Please try again.');
      // _debugQuery();
    }
  }

  // // Update the driver's status to 'Online' in the database when they log in
  // Future<void> _setStatusToOnline(String enteredDriverID) async {
  //   try {
  //     final response = await Supabase.instance.client
  //         .from('driverTable')
  //         .update({'driving_status': 'Online'})
  //         .eq('driver_id', enteredDriverID)
  //         .select('driving_status')
  //         .single();

  //     ShowMessage().showToast(
  //         'status updated to ${response['driving_status'].toString()}');
  //   } catch (e) {
  //     ShowMessage().showToast('Error: $e');

  //     if (kDebugMode) {
  //       print('Error: $e');
  //     }
  //   }
  // }

// // CHECK THIS BEFORE FINALIZING
//   Future<void> _debugQuery() async {
//     try {
//       final response = await Supabase.instance.client
//           .from('driverTable')
//           .select(); // Fetch all rows

//       final vehicleResponse =
//           await Supabase.instance.client.from('vehicleTable').select();

//       if (kDebugMode) {
//         print('DriverTable Response: $response');
//         print('VehicleTable Response $vehicleResponse');
//       }
//     } catch (e) {
//       if (kDebugMode) {
//         print('Error: $e');
//       }
//     }
//   }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.all(50),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,

            //CONTENTS
            children: [
              _buildHeader(), //HEADER

              _buildDriverIDText(), //Enter your Driver ID text

              _buildDriverIDInput(), //DRIVER ID INPUT

              _buildPasswordText(), //Enter your Password text

              _buildPasswordInput(), //PASSWORD INPUT

              _buildForgotPasswordButton(), //FORGOT PASSWORD BUTTON

              _buildLogInButton(), //LOG IN BUTTON
            ],
          ),
        ),
      ),
    );
  }

  Flexible _buildLogInButton() {
    return Flexible(
      child: Container(
        margin: const EdgeInsets.only(top: 120),
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _logIn,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color.fromARGB(255, 0, 0, 0),
            minimumSize: const Size(240, 45),
            shadowColor: Colors.black,
            elevation: 5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15.0),
            ),
          ),
          child: _loading
              ? const CircularProgressIndicator()
              : Text(
                  'Log in',
                  style: textStyle(20, FontWeight.w600).copyWith(
                    color: const Color(0xFFF2F2F2),
                  ),
                ),
        ),
      ),
    );
  }

  Container _buildForgotPasswordButton() {
    return Container(
      margin: const EdgeInsets.only(top: 5),
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: () {},
        child: Text(
          'Forgot Password?',
          style: textStyle(14, FontWeight.w700),
        ),
      ),
    );
  }

  Container _buildPasswordInput() {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      child: SizedBox(
        width: double.infinity,
        height: 45,
        child: TextField(
          controller: inputPasswordController,
          obscureText: !isPasswordVisible,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(7.0),
            ),
            errorText: errorMessage.isNotEmpty ? errorMessage : null,
            suffixIcon: IconButton(
              color: const Color(0xFF121212),
              onPressed: () {
                setState(() {
                  isPasswordVisible = !isPasswordVisible;
                });
              },
              icon: Icon(
                isPasswordVisible ? Icons.visibility : Icons.visibility_off,
              ),
            ),
            labelText: 'Enter your Password here',
            labelStyle: const TextStyle(
              fontSize: 14,
            ),
            filled: true,
            fillColor: Colors.grey.shade200,
            contentPadding: const EdgeInsets.fromLTRB(15, 0, 115, 0),
          ),
        ),
      ),
    );
  }

  Container _buildPasswordText() {
    return Container(
      margin: EdgeInsets.only(top: MediaQuery.of(context).size.height * 0.03),
      child: Row(
        children: [
          Text(
            'Enter your ',
            style: textStyle(14, FontWeight.normal),
          ),
          Text(
            'Password',
            style: textStyle(14, FontWeight.w700),
          ),
        ],
      ),

      //INPUT
    );
  }

  Container _buildDriverIDText() {
    return Container(
      margin: EdgeInsets.only(top: MediaQuery.of(context).size.height * 0.1),
      child: Row(
        children: [
          Text(
            'Enter your ',
            style: textStyle(14, FontWeight.normal),
          ),
          Text(
            'Driver ID',
            style: textStyle(14, FontWeight.w700),
          ),
          // Text(
          //   ' to continue',
          //   style: textStyle(14, FontWeight.normal),
          // )
        ],
      ),
    );
  }

  Container _buildDriverIDInput() {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      child: SizedBox(
        width: double.infinity,
        height: 45,
        child: TextField(
          controller: inputDriverIDController,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(7.0),
            ),
            labelText: 'Enter your Driver ID here',
            labelStyle: const TextStyle(
              fontSize: 14,
            ),
            errorText: errorMessage.isNotEmpty ? errorMessage : null,
            filled: true,
            fillColor: Colors.grey.shade200,
            contentPadding: const EdgeInsets.fromLTRB(15, 0, 115, 0),
          ),
        ),
      ),
    );
  }

  Column _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          alignment: Alignment.center,
          // margin: const EdgeInsets.only(top: 60),
          width: 70,
          height: 70,
          child: SvgPicture.asset('assets/svg/Ellipse.svg'),
        ),
        Container(
          margin: const EdgeInsets.only(top: 30),
          child: Text(
            'Log-in to your account',
            style: textStyle(18, FontWeight.w700),
          ),
        ),
      ],
    );
  }

  TextStyle textStyle(double size, FontWeight weight) {
    return TextStyle(
        fontSize: size,
        fontFamily: 'Inter',
        fontWeight: weight,
        color: Colors.black87);
  }
}
