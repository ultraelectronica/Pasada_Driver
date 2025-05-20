import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_svg/flutter_svg.dart';
// import 'package:pasada_driver_side/NavigationPages/passenger_counter.dart';
import 'package:pasada_driver_side/UI/constants.dart';
import 'package:pasada_driver_side/UI/message.dart';
import 'package:pasada_driver_side/NavigationPages/activity_page.dart';
import 'package:pasada_driver_side/NavigationPages/home_page.dart';
import 'package:pasada_driver_side/NavigationPages/profile_page.dart';
import 'package:pasada_driver_side/Database/driver_provider.dart';
import 'package:pasada_driver_side/Database/passenger_provider.dart';
import 'package:pasada_driver_side/UI/text_styles.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  MainPageState createState() => MainPageState();
}

class MainPageState extends State<MainPage> with WidgetsBindingObserver {
  int _currentIndex = 0;
  Timer? _timer;
  bool isDialogShown = false;
  // Tracks if we've already shown the driving dialog in this session
  bool hasShownDrivingPrompt = true;

  final List<Widget> pages = [
    const HomeScreen(),
    // const PassengerCounter(),
    const ActivityPage(),
    const ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    _startTimer();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      // set driving status back to previous status
      final previousStatus = context.read<DriverProvider>().lastDriverStatus!;
      context.read<DriverProvider>().updateStatusToDB(previousStatus, context);
      ShowMessage().showToast('App resumed');

      // If returning to driving status, fetch bookings
      if (previousStatus == 'Driving') {
        // Use post-frame callback to avoid setState during build
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            context.read<PassengerProvider>().getBookingRequestsID(context);
          }
        });
      } else {
        // If not driving, we should show the prompt again when they go back to driving
        hasShownDrivingPrompt = false;
      }
    } else if (state == AppLifecycleState.paused) {
      // set driving status to idling
      final currentStatus = context.read<DriverProvider>().driverStatus;
      context.read<DriverProvider>().setLastDriverStatus(currentStatus);
      context.read<DriverProvider>().updateStatusToDB('Idling', context);

      // Reset the prompt flag if they were idling so they get prompted again
      if (currentStatus == 'Driving') {
        hasShownDrivingPrompt = false;
      }

      ShowMessage().showToast('App paused');
    }
  }

  void _startTimer() {
    // Update immediately when starting
    context.read<DriverProvider>().updateLastOnline(context);

    // Then update every 30 seconds
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) {
      context.read<DriverProvider>().updateLastOnline(context);
    });
  }

  void onTap(int newIndex) {
    setState(() {
      _currentIndex = newIndex;

      // Reset the dialog flag when user navigates away from home and back
      if (_currentIndex == 0) {
        // Only reset if driver is not in driving mode
        if (context.read<DriverProvider>().isDriving == false) {
          hasShownDrivingPrompt = false;
        }
      }
    });
  }

  void isDriving(DriverProvider driverProvider) {
    // We're no longer showing the dialog prompt as we're replacing it with a switch
    // Just set hasShownDrivingPrompt to true to avoid showing the dialog
    hasShownDrivingPrompt = true;

    // Old logic disabled:
    /*
    if (driverProvider.isDriving == false &&
        _currentIndex == 0 &&
        !hasShownDrivingPrompt) {
      if (!isDialogShown) {
        isDialogShown = true; // Set flag before showing dialog
        SchedulerBinding.instance.addPostFrameCallback((_) async {
          // Make callback async
          await _showStartDrivingDialog(); // Await the dialog
          // Mark that we've shown the prompt already
          hasShownDrivingPrompt = true;
        });
      }
    }
    */
  }

  // START DRIVING DIALOG
  Future<void> _showStartDrivingDialog() async {
    bool isStartingDrive = false;

    await showDialog(
      context: context,
      barrierDismissible: true, // Enables dismissing dialog by tapping outside
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: Text(
              'Welcome Manong!',
              textAlign: TextAlign.center,
              style:
                  Styles().textStyle(22, Styles.w600Weight, Styles.customBlack),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'To start getting passengers, start driving.',
                  textAlign: TextAlign.center,
                  style: Styles()
                      .textStyle(15, Styles.w500Weight, Styles.customBlack),
                ),
                const SizedBox(height: 20), // Add some spacing
                Center(
                  child: ElevatedButton(
                    onPressed: isStartingDrive
                        ? null // Disable while processing
                        : () async {
                            // Show loading state
                            setState(() {
                              isStartingDrive = true;
                            });

                            try {
                              // Capture the providers we need before async operations
                              final driverProvider =
                                  context.read<DriverProvider>();

                              // Update driver status to driving
                              await driverProvider.updateStatusToDB(
                                  'Driving', context);
                              driverProvider.setDriverStatus('Driving');
                              driverProvider.setIsDriving(true);

                              // Close the dialog first for better UX
                              Navigator.of(dialogContext).pop();

                              // Show a progress indicator in a snackbar
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Row(
                                    children: [
                                      SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                    Colors.white),
                                            strokeWidth: 2,
                                          )),
                                      SizedBox(width: 12),
                                      Text('Finding passengers...'),
                                    ],
                                  ),
                                  backgroundColor: Colors.black87,
                                  duration: Duration(seconds: 4),
                                ),
                              );

                              // Fetch bookings after dialog is closed
                              await Future.delayed(
                                  const Duration(milliseconds: 300));
                              if (context.mounted) {
                                try {
                                  final passengerProvider =
                                      context.read<PassengerProvider>();
                                  // Use stored driver ID instead of context for the booking fetch
                                  await passengerProvider
                                      .getBookingRequestsID(null);
                                } catch (e) {
                                  if (kDebugMode) {
                                    print(
                                        'Error during background booking fetch: $e');
                                  }
                                }
                              }
                            } catch (e) {
                              // Handle any errors
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error starting: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }

                              if (mounted) {
                                setState(() {
                                  isStartingDrive = false;
                                });
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 30, vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      elevation: 8,
                      backgroundColor: Colors.black,
                    ),
                    child: isStartingDrive
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Starting...',
                                style: Styles().textStyle(16,
                                    Styles.normalWeight, Styles.customWhite),
                              ),
                            ],
                          )
                        : Text(
                            'Start Driving',
                            style: Styles().textStyle(
                                16, Styles.normalWeight, Styles.customWhite),
                          ),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );

    // This runs after the dialog is dismissed by any means
    isDialogShown = false;
  }

  @override
  Widget build(BuildContext context) {
    final driverProvider = context.watch<DriverProvider>();

    isDriving(driverProvider);

    return Scaffold(
      backgroundColor: Constants.WHITE_COLOR,
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  BottomNavigationBar _buildBottomNavBar() {
    return BottomNavigationBar(
      backgroundColor: Constants.WHITE_COLOR,
      currentIndex: _currentIndex,
      onTap: onTap,
      showSelectedLabels: true,
      showUnselectedLabels: false,
      selectedLabelStyle:
          Styles().textStyle(12, Styles.w700Weight, Styles.customBlack),
      unselectedLabelStyle:
          Styles().textStyle(12, Styles.w700Weight, Styles.customBlack),
      selectedItemColor: Constants.GREEN_COLOR,
      type: BottomNavigationBarType.fixed,
      items: [
        _buildNavItem(0, 'Home', 'homefilled.svg', 'home.svg'),
        // _buildNavItem(1, 'Counter', 'listfilled.svg', 'list.svg'),
        _buildNavItem(1, 'Activity', 'recentfilled.svg', 'recent.svg'),
        _buildNavItem(2, 'Profile', 'profilefilled.svg', 'profile.svg'),
      ],

      // Old icons
      // items: [
      //   _buildNavItem(0, 'Home', 'homeSelectedIcon.svg', 'homeIcon.svg'),
      //   _buildNavItem(
      //       1, 'Activity', 'activitySelectedIcon.svg', 'activityIcon.svg'),
      //   _buildNavItem(
      //       2, 'Profile', 'accountSelectedIcon.svg', 'profileIcon.svg'),
      // ],
    );
  }

  BottomNavigationBarItem _buildNavItem(
      int index, String label, String selectedIcon, String unselectedIcon) {
    return BottomNavigationBarItem(
      label: label,
      icon: _currentIndex == index
          ? SvgPicture.asset(
              'assets/svg/$selectedIcon',
              colorFilter:
                  ColorFilter.mode(Constants.GREEN_COLOR, BlendMode.srcIn),
              width: 28,
              height: 28,
            )
          : SvgPicture.asset(
              'assets/svg/$unselectedIcon',
              width: 24,
              height: 24,
            ),
    );
  }
}
