import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
// import 'package:pasada_driver_side/NavigationPages/home_page.dart';
import 'package:pasada_driver_side/NavigationPages/main_page.dart';
import 'package:pasada_driver_side/driver_provider.dart';
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
  bool _loading = false;
  String _driver_status = 'Offline';

  @override
  void dispose() {
    inputDriverIDController.dispose();
    inputPasswordController.dispose();
    super.dispose();
  }

  Future<void> _LogIn() async {
    final enteredDriverID = inputDriverIDController.text.trim();
    final enteredPassword = inputPasswordController.text.trim();

    if (enteredDriverID.isEmpty || enteredPassword.isEmpty) {
      _showMessage('Please fill in all fields');
      return;
    }

    try {
      final response = await Supabase.instance.client
          .from('driverTable')
          .select('driverID') // Only retrieve driverID
          .eq('driverID', enteredDriverID) // Match driverID
          .eq('driverPassword', enteredPassword) // Match password
          .single(); // Expect one result

      if (response != null) {
        context.read<DriverProvider>().setDriverID(response['driverID'].toString());

        _showMessage('Login successful! Welcome Manong!, $enteredDriverID');
        // Proceed to next screen or perform other actions
        Navigator.push(
            context, MaterialPageRoute(builder: (context) => const MainPage()));
      }
    } catch (e) {
      _showMessage('Invalid credentials. Please try again.');
      _debugQuery();
    }
  }

// CHECK THIS BEFORE FINALIZING
  Future<void> _debugQuery() async {
    try {
      final response = await Supabase.instance.client
          .from('driverTable')
          .select(); // Fetch all rows

      print('Raw Response: $response');
    } catch (e) {
      print('Error: $e');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // Future<void> _getDriverStatus() async {
  //   final supabaseUser = Supabase.instance.client.auth.currentUser;

  //   if (supabaseUser != null) {
  //     try {
  //       final response = await Supabase.instance.client
  //           .from('driverTable')
  //           .select('driverStatus')
  //           .eq('email', supabaseUser.email)
  //           .single();

  //       if (response.data != null) {
  //         setState(() {
  //           _driver_status = response.data.toString();
  //           print('Current driver status in the db: $_driver_status');
  //         });
  //       } else {
  //         ScaffoldMessenger.of(context).showSnackBar(
  //           SnackBar(
  //               content: Text('Error occured: ${response.data.toString()}')),
  //         );
  //       }
  //     } catch (e) {
  //       print(e);
  //     }
  //   }
  // }

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
          onPressed: _LogIn,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF5F3FC4),
            minimumSize: const Size(240, 45),
            shadowColor: Colors.black,
          ),
          child: _loading
              ? const CircularProgressIndicator()
              : const Text(
                  'Log in',
                  style: TextStyle(
                    color: Color(0xFFF2F2F2),
                    fontWeight: FontWeight.w600,
                    fontSize: 20,
                    fontFamily: 'Inter',
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
        child: const Text('Forgot Password?'),
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
      child: const Row(
        children: [
          Text(
            'Enter your ',
          ),
          Text(
            'Password',
            style: TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),

      //INPUT
    );
  }

  Container _buildDriverIDText() {
    return Container(
      margin: EdgeInsets.only(top: MediaQuery.of(context).size.height * 0.1),
      child: const Row(
        children: [
          Text(
            'Enter your ',
          ),
          Text(
            'Driver ID',
            style: TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(' to continue')
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
      children: [
        Container(
          alignment: Alignment.centerLeft,
          // margin: const EdgeInsets.only(top: 60),
          width: 60,
          height: 60,
          child: SvgPicture.asset('assets/svg/Ellipse.svg'),
        ),
        Container(
          margin: const EdgeInsets.only(top: 30),
          child: const Text(
            'Log-in to your account',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
