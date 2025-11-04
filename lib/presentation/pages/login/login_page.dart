import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pasada_driver_side/Services/auth_service.dart';
import 'package:pasada_driver_side/Services/notification_service.dart';
import 'package:pasada_driver_side/domain/services/passenger_capacity.dart';
import 'package:pasada_driver_side/Services/password_util.dart';
import 'package:pasada_driver_side/common/constants/constants.dart';
import 'package:pasada_driver_side/common/constants/text_styles.dart';
import 'package:pasada_driver_side/common/constants/message.dart';
import 'package:pasada_driver_side/presentation/pages/main/main_page.dart';
import 'package:pasada_driver_side/presentation/providers/driver/driver_provider.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pasada_driver_side/presentation/providers/map_provider.dart';
import 'package:pasada_driver_side/presentation/providers/passenger/passenger_provider.dart';
import 'package:pasada_driver_side/presentation/widgets/error_retry_widget.dart';
import 'package:pasada_driver_side/common/utils/result.dart';
import 'package:pasada_driver_side/Services/encryption_service.dart';
import 'package:pasada_driver_side/domain/services/background_location_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class LogIn extends StatefulWidget {
  final PageController? pageController;

  const LogIn({super.key, this.pageController});

  @override
  State<LogIn> createState() => _LogInState();
}

class _LogInState extends State<LogIn> {
  final inputDriverIDController = TextEditingController();
  final inputPasswordController = TextEditingController();
  late final FocusNode driverIdFocusNode;
  late final FocusNode passwordFocusNode;
  bool isPasswordVisible = false;
  String driverIdError = '';
  String passwordError = '';
  // Loading/error handled by DriverProvider now

  @override
  void initState() {
    super.initState();
    driverIdFocusNode = FocusNode();
    passwordFocusNode = FocusNode();

    void clearErrorOnFocus() {
      if (driverIdFocusNode.hasFocus && driverIdError.isNotEmpty) {
        setState(() {
          driverIdError = '';
        });
      }
      if (passwordFocusNode.hasFocus && passwordError.isNotEmpty) {
        setState(() {
          passwordError = '';
        });
      }
    }

    driverIdFocusNode.addListener(clearErrorOnFocus);
    passwordFocusNode.addListener(clearErrorOnFocus);

    inputDriverIDController.addListener(() {
      if (driverIdError.isNotEmpty) {
        setState(() {
          driverIdError = '';
        });
      }
    });

    inputPasswordController.addListener(() {
      if (passwordError.isNotEmpty) {
        setState(() {
          passwordError = '';
        });
      }
    });
  }

  @override
  void dispose() {
    inputDriverIDController.dispose();
    inputPasswordController.dispose();
    driverIdFocusNode.dispose();
    passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _logIn() async {
    final driverProv = context.read<DriverProvider>();
    driverProv.clearError();

    final enteredDriverID = inputDriverIDController.text.trim();
    final enteredPassword = inputPasswordController.text.trim();

    if (enteredDriverID.isEmpty || enteredPassword.isEmpty) {
      setState(() {
        driverIdError = enteredDriverID.isEmpty ? 'Driver ID is required' : '';
        passwordError = enteredPassword.isEmpty ? 'Password is required' : '';
      });
      return;
    }

    // Clear any previous inline error before proceeding
    if (driverIdError.isNotEmpty || passwordError.isNotEmpty) {
      setState(() {
        driverIdError = '';
        passwordError = '';
      });
    }

    driverProv.setLoading(true);

    try {
      //Query to get the driverID and password from the driverTable
      final response = await Supabase.instance.client
          .from('driverTable')
          .select('full_name, driver_id, vehicle_id, driver_password')
          .eq('driver_id', enteredDriverID)
          .maybeSingle();

      // Handle case where no row was found (invalid driver ID)
      if (response == null) {
        if (mounted) {
          setState(() {
            // Unknown driver ID
            driverIdError = 'Invalid credentials. Please try again.';
            passwordError = 'Invalid credentials. Please try again.';
          });
          driverProv.setLoading(false);
        }
        return;
      }

      final storedHashedPassword = response['driver_password'] as String?;
      if (storedHashedPassword == null) {
        if (mounted) {
          setState(() {
            driverIdError = 'Invalid credentials. Please try again.';
            passwordError = 'Invalid credentials. Please try again.';
          });
          driverProv.setLoading(false);
        }
        return;
      }

      bool checkPassword =
          PasswordUtil().checkPassword(enteredPassword, storedHashedPassword);

      if (!checkPassword) {
        if (mounted) {
          setState(() {
            passwordError = 'Invalid credentials. Please try again.';
          });
          driverProv.setLoading(false);
        }
        return;
      }

      if (mounted) {
        // saves all the infos to the provider
        await _setDriverInfo(response);

        //saves the session token to the local storage
        await saveSession(enteredDriverID, response);

        // Save credentials for background location service
        final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
        final supabaseKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
        await BackgroundLocationService.saveCredentials(
          enteredDriverID,
          supabaseUrl,
          supabaseKey,
        );

        // Start background location service
        await BackgroundLocationService.instance.start();
        if (kDebugMode) {
          debugPrint(
              'Background location service started for driver: $enteredDriverID');
        }

        // Decrypt name if needed for user-facing text
        String displayName = response['full_name']?.toString() ?? '';
        try {
          final encryption = EncryptionService();
          // initializeApp() already initializes encryption; decrypt safely here
          displayName = await encryption.decryptUserData(displayName);
        } catch (_) {}

        //logs the login time of the driver
        await context.read<DriverProvider>().writeLoginTime(context);

        //shows the welcome notification
        NotificationService.instance.showBasicNotification(
            'Welcome Manong $displayName!', 'Welcome sa Pasada Driver.');
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
        driverProv.setLoading(false);
      }
    } catch (e, stackTrace) {
      driverProv.setError(Failure(message: 'Login failed: $e', type: 'login'));
      driverProv.setLoading(false);
      if (kDebugMode) {
        print('Error during login: $e');
        print('Error Login, Stack Trace: $stackTrace');
      }
      // Keep provider error for unexpected failures; no toast for invalid creds path.
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

      final driverProv = context.read<DriverProvider>();
      debugPrint('Basic driver info: DriverID: ${driverProv.driverID}');

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

        // Get driver credentials
        await context.read<DriverProvider>().getDriverCreds();

        // Update driver status
        // _updateStatusToDB();
        final driverProv = context.read<DriverProvider>();
        await driverProv.updateStatusToDB('Online');
        // Ensure the new status is preserved if app is backgrounded immediately
        driverProv.setLastDriverStatus('Online');
        debugPrint('Driver status updated');

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

    final isLoading = context.select<DriverProvider, bool>((p) => p.isLoading);
    final errorMsg =
        context.select<DriverProvider, String?>((p) => p.error?.message);

    Widget content;
    if (errorMsg != null) {
      content = ErrorRetryWidget(message: errorMsg, onRetry: _logIn);
    } else {
      content = LayoutBuilder(
        // Use LayoutBuilder to get constraints for centering
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Container(
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/png/log_in_page_bg.png'),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Center(
                  child: Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: horizontalPadding),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: screenHeight * 0.15),
                        _buildHeader(screenHeight * 0.15, 0),
                        SizedBox(height: screenHeight * 0.1),
                        _buildDriverIDText(),
                        SizedBox(height: screenHeight * 0.01),
                        _buildDriverIDInput(screenHeight * 0.06),
                        SizedBox(height: screenHeight * 0.02),
                        _buildPasswordText(),
                        SizedBox(height: screenHeight * 0.01),
                        _buildPasswordInput(screenHeight * 0.06),
                        SizedBox(height: screenHeight * 0.15),
                        _buildLogInButton(screenHeight * 0.06, isLoading),
                        SizedBox(height: screenHeight * 0.1),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    return Scaffold(body: content);
  }

  Widget _buildLogInButton(double buttonHeight, bool isLoading) {
    return SizedBox(
      width: double.infinity,
      height: buttonHeight,
      child: ElevatedButton(
        onPressed: isLoading ? null : _logIn,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          shadowColor: Colors.black,
          elevation: 5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15.0),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.4),
              )
            : Text(
                'Log in',
                style:
                    Styles().textStyle(20, Styles.bold, Constants.GREEN_COLOR),
              ),
      ),
    );
  }

  SizedBox _buildPasswordInput(double inputFieldHeight) {
    return SizedBox(
      width: double.infinity,
      height: inputFieldHeight,
      child: TextField(
        focusNode: passwordFocusNode,
        controller: inputPasswordController,
        obscureText: !isPasswordVisible,
        decoration: InputDecoration(
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
            borderSide: const BorderSide(color: Colors.grey, width: 2.0),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
            borderSide: const BorderSide(color: Colors.black, width: 2.0),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
            borderSide: const BorderSide(color: Colors.red, width: 2.0),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
            borderSide: const BorderSide(color: Colors.red, width: 2.0),
          ),
          errorText: passwordError.isNotEmpty ? passwordError : null,
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
    );
  }

  Row _buildPasswordText() {
    return Row(
      children: [
        Text(
          'Enter your  ',
          style:
              Styles().textStyle(15, Styles.semiBold, Styles.customWhiteFont),
        ),
        Text(
          'Password',
          style: Styles().textStyle(17, Styles.bold, Styles.customWhiteFont),
        ),
      ],
    );
  }

  Row _buildDriverIDText() {
    return Row(
      children: [
        Text(
          'Enter your  ',
          style:
              Styles().textStyle(15, Styles.semiBold, Styles.customWhiteFont),
        ),
        Text(
          'Driver ID',
          style: Styles().textStyle(17, Styles.bold, Styles.customWhiteFont),
        ),
      ],
    );
  }

  SizedBox _buildDriverIDInput(double inputFieldHeight) {
    return SizedBox(
      width: double.infinity,
      height: inputFieldHeight,
      child: TextField(
        focusNode: driverIdFocusNode,
        controller: inputDriverIDController,
        decoration: InputDecoration(
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
            borderSide: const BorderSide(color: Colors.grey, width: 2.0),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
            borderSide: const BorderSide(color: Colors.black, width: 2.0),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
            borderSide: const BorderSide(color: Colors.red, width: 2.0),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
            borderSide: const BorderSide(color: Colors.red, width: 2.0),
          ),
          hintText: 'Enter your Driver ID here',
          hintStyle: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w400,
          ),
          errorText: driverIdError.isNotEmpty ? driverIdError : null,
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
    );
  }

  Column _buildHeader(double iconSize, double topMargin) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          alignment: Alignment.center,
          width: iconSize,
          height: iconSize * .5,
          child: Image.asset(
            'assets/png/pasada_logo.png',
            color: Colors.white,
          ),
        ),
        Container(
          margin: EdgeInsets.only(top: topMargin),
          child: Text(
            'Log-in to your account',
            style: Styles().textStyle(18, Styles.bold, Styles.customWhiteFont),
          ),
        ),
      ],
    );
  }
}
