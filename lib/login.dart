import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pasada_driver_side/Database/AuthService.dart';
import 'package:pasada_driver_side/Database/passenger_capacity.dart';
import 'package:pasada_driver_side/Services/password_util.dart';
import 'package:pasada_driver_side/UI/text_styles.dart';
import 'package:pasada_driver_side/UI/message.dart';
import 'package:pasada_driver_side/NavigationPages/main_page.dart';
import 'package:pasada_driver_side/Database/driver_provider.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pasada_driver_side/Database/map_provider.dart';
import 'package:pasada_driver_side/Database/passenger_provider.dart';

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
          .select('first_name, driver_id, vehicle_id, driver_password')
          .eq('driver_id', enteredDriverID)
          .single();

      final storedHashedPassword = await response['driver_password'] as String;

      bool checkPassword =
          PasswordUtil().checkPassword(enteredPassword, storedHashedPassword);

      if (!checkPassword) {
        ShowMessage().showToast('Invalid credentials. Please try again.');
        throw Exception('Error: Invalid credentials $checkPassword');
      }

      if (mounted) {
        // saves all the infos to the provider
        await _setDriverInfo(response);

        await saveSession(enteredDriverID, response);

        ShowMessage().showToastTop('Welcome Manong ${response['first_name']}!');

        // move to the main page once the driver successfuly logs in
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const MainPage()),
          );
        }
        if (kDebugMode) {
          print('Vehicle ID: ${response['vehicle_id']}');
        }
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('Error during login: $e');
        print('Error Login, Stack Trace: $stackTrace');
      }
      ShowMessage().showToast('Invalid credentials. Please try again.');
    }
  }

  Future<void> saveSession(
      String enteredDriverID, PostgrestMap response) async {
    final sessionToken = AuthService.generateSecureToken();
    // final expirationTime =
    //     DateTime.now().add(const Duration(hours: 24)).toIso8601String();

    // int routeID = context.read<MapProvider>().routeID;
    int routeID = context.read<DriverProvider>().routeID;

    if (kDebugMode) {
      print('save session route ID: ${routeID.toString()}');
    }

    await AuthService.saveCredentials(
      sessionToken: sessionToken,
      driverId: enteredDriverID,
      routeId: context.read<DriverProvider>().routeID.toString(),
      vehicleId: response['vehicle_id'].toString(),
    );
  }

  Future<void> _setDriverInfo(PostgrestMap response) async {
    try {
      debugPrint('Starting driver info initialization...');

      // Set basic driver info first
      _setDriverID(response);
      _setVehicleID(response);
      debugPrint(
          'Basic driver info set - DriverID: ${response['driver_id']}, VehicleID: ${response['vehicle_id']}');

      // Wait for driver route to be set before proceeding
      await context.read<DriverProvider>().getDriverRoute();
      debugPrint('Initial route ID fetch completed');

      // Add retry logic for route ID
      int retryCount = 0;
      int maxRetries = 3;
      int currentRouteID = context.read<DriverProvider>().routeID;

      while (currentRouteID <= 0 && retryCount < maxRetries) {
        debugPrint(
            'Retrying to get route ID. Attempt ${retryCount + 1} of $maxRetries');
        await Future.delayed(const Duration(milliseconds: 500));
        await context.read<DriverProvider>().getDriverRoute();
        currentRouteID = context.read<DriverProvider>().routeID;
        debugPrint('Current route ID after retry: $currentRouteID');
        retryCount++;
      }

      // Only proceed with other operations if we have a valid route ID
      if (currentRouteID > 0) {
        debugPrint('Valid route ID obtained: $currentRouteID');

        // Set passenger capacity
        _setPassengerCapacity();
        debugPrint('Passenger capacity set');

        // Update driver status
        _updateStatusToDB();
        debugPrint('Driver status updated');

        // Get driver credentials
        await _setDriverCreds();
        debugPrint('Driver credentials fetched');

        // Get route coordinates using MapProvider
        debugPrint('Fetching route coordinates for route ID: $currentRouteID');
        await context.read<MapProvider>().getRouteCoordinates(currentRouteID);
        debugPrint('Route coordinates fetched');

        // Get booking requests
        await context.read<PassengerProvider>().getBookingRequestsID(context);
        debugPrint('Booking requests fetched');
      } else {
        debugPrint('Failed to get valid route ID after $maxRetries attempts');
        ShowMessage().showToast(
            'Warning: Could not load route information. Some features may be limited.');
      }
    } catch (e, stackTrace) {
      debugPrint('Error in _setDriverInfo: $e');
      debugPrint('Stack Trace: $stackTrace');
      ShowMessage()
          .showToast('Error initializing driver info. Please try again.');
    }
  }

  void _updateStatusToDB() {
    context.read<DriverProvider>().setDriverStatus('Online');
    context.read<DriverProvider>().updateStatusToDB('Online', context);
  }

  Future<void> _setDriverCreds() async {
    await context.read<DriverProvider>().getDriverCreds();
  }

  void _setPassengerCapacity() {
    // context.read<DriverProvider>().getPassengerCapacity();
    PassengerCapacity().getPassengerCapacityToDB(context);
  }

  void _setVehicleID(PostgrestMap response) {
    context
        .read<DriverProvider>()
        .setVehicleID(response['vehicle_id'].toString());
  }

  void _setDriverID(PostgrestMap response) {
    context
        .read<DriverProvider>()
        .setDriverID(response['driver_id'].toString());
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    // Define relative padding
    final horizontalPadding = screenWidth * 0.1;

    return Scaffold(
      body: LayoutBuilder(
        // Use LayoutBuilder to get constraints for centering
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              // Ensure the content area tries to fill the viewport height
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight,
              ),
              child: Center(
                // Center the content vertically
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                  ),
                  child: Column(
                    mainAxisAlignment:
                        MainAxisAlignment.center, // Center column content
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Use screenHeight/Width directly for spacing and sizing
                      SizedBox(height: screenHeight * 0.05),

                      _buildHeader(screenHeight * 0.15, screenHeight * 0.02),
                      SizedBox(height: screenHeight * 0.05),

                      _buildDriverIDText(),
                      SizedBox(height: screenHeight * 0.01),

                      _buildDriverIDInput(screenHeight * 0.06),
                      SizedBox(height: screenHeight * 0.03),

                      _buildPasswordText(),
                      SizedBox(height: screenHeight * 0.01),

                      _buildPasswordInput(screenHeight * 0.06),

                      _buildForgotPasswordButton(),
                      SizedBox(height: screenHeight * 0.08),

                      _buildLogInButton(screenHeight * 0.06),
                      SizedBox(height: screenHeight * 0.05),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLogInButton(double buttonHeight) {
    return SizedBox(
      width: double.infinity,
      height: buttonHeight,
      child: ElevatedButton(
        onPressed: _logIn,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color.fromARGB(255, 0, 0, 0),
          shadowColor: Colors.black,
          elevation: 5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15.0),
          ),
        ),
        child: _loading
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(
                'Log in',
                style: Styles()
                    .textStyle(20, Styles.w700Weight, Styles.customWhite),
              ),
      ),
    );
  }

  Container _buildForgotPasswordButton() {
    return Container(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: () {},
        child: Text(
          'Forgot Password?',
          style: Styles().textStyle(14, Styles.w700Weight, Styles.customBlack),
        ),
      ),
    );
  }

  Container _buildPasswordInput(double inputFieldHeight) {
    return Container(
      child: SizedBox(
        width: double.infinity,
        height: inputFieldHeight,
        child: TextField(
          controller: inputPasswordController,
          obscureText: !isPasswordVisible,
          decoration: InputDecoration(
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.0),
              borderSide: const BorderSide(color: Colors.grey, width: 1.0),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.0),
              borderSide: const BorderSide(color: Colors.black, width: 2.0),
            ),
            errorText: errorMessage.isNotEmpty ? errorMessage : null,
            suffixIcon: IconButton(
              color: Colors.black54,
              onPressed: () {
                setState(() {
                  isPasswordVisible = !isPasswordVisible;
                });
              },
              icon: Icon(
                isPasswordVisible
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
            hintText: 'Enter your Password here',
            hintStyle: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w400,
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
            prefixIcon: const Icon(
              Icons.lock_outline,
              color: Colors.black54,
            ),
            contentPadding:
                const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
          ),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Container _buildPasswordText() {
    return Container(
      child: Row(
        children: [
          Text(
            'Enter your ',
            style:
                Styles().textStyle(14, Styles.normalWeight, Styles.customBlack),
          ),
          Text(
            'Password',
            style:
                Styles().textStyle(14, Styles.w700Weight, Styles.customBlack),
          ),
        ],
      ),
    );
  }

  Container _buildDriverIDText() {
    return Container(
      child: Row(
        children: [
          Text(
            'Enter your ',
            style:
                Styles().textStyle(14, Styles.normalWeight, Styles.customBlack),
          ),
          Text(
            'Driver ID',
            style:
                Styles().textStyle(14, Styles.w700Weight, Styles.customBlack),
          ),
        ],
      ),
    );
  }

  Container _buildDriverIDInput(double inputFieldHeight) {
    return Container(
      child: SizedBox(
        width: double.infinity,
        height: inputFieldHeight,
        child: TextField(
          controller: inputDriverIDController,
          decoration: InputDecoration(
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.0),
              borderSide: const BorderSide(color: Colors.grey, width: 1.0),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.0),
              borderSide: const BorderSide(color: Colors.black, width: 2.0),
            ),
            hintText: 'Enter your Driver ID here',
            hintStyle: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w400,
            ),
            errorText: errorMessage.isNotEmpty ? errorMessage : null,
            filled: true,
            fillColor: Colors.grey.shade50,
            prefixIcon: const Icon(
              Icons.person_outline,
              color: Colors.black54,
            ),
            contentPadding:
                const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
          ),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Column _buildHeader(double iconSize, double topMargin) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          alignment: Alignment.center,
          width: iconSize,
          height: iconSize,
          child: SvgPicture.asset(
            'assets/svg/PasadaLogo.svg',
            colorFilter: const ColorFilter.mode(Colors.black, BlendMode.srcIn),
          ),
        ),
        Container(
          margin: EdgeInsets.only(top: topMargin),
          child: Text(
            'Log-in to your account',
            style:
                Styles().textStyle(18, Styles.w700Weight, Styles.customBlack),
          ),
        ),
      ],
    );
  }
}
