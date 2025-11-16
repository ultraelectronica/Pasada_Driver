import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pasada_driver_side/common/constants/constants.dart';
import 'package:pasada_driver_side/presentation/pages/activity/activity_page.dart';
import 'package:pasada_driver_side/presentation/pages/home/home_page.dart';
import 'package:pasada_driver_side/presentation/pages/profile/profile_page.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:pasada_driver_side/presentation/providers/driver/driver_provider.dart';
import 'package:provider/provider.dart';
import 'package:pasada_driver_side/domain/services/presence_service.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  MainPageState createState() => MainPageState();
}

class MainPageState extends State<MainPage> with WidgetsBindingObserver {
  int _currentIndex = 0;
  // Timer? _timer;
  Timer? _inactiveDebounceTimer;
  bool hasShownDrivingPrompt = true;
  AppLifecycleState? _lastLifecycleState;
  DateTime? _lastBackPressAt;

  final List<Widget> pages = const [
    HomeScreen(),
    ActivityPage(),
    ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    // _startTimer();
    WidgetsBinding.instance.addObserver(this);
    // Start presence heartbeat only when on MainPage and logged in
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final bool isLoggedIn =
          context.read<DriverProvider>().driverID.isNotEmpty;
      if (isLoggedIn && !PresenceService.instance.isRunning) {
        PresenceService.instance
            .start(context, interval: const Duration(seconds: 10));
      }
    });
  }

  @override
  void dispose() {
    // _timer?.cancel();
    _inactiveDebounceTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    // Stop presence when leaving MainPage
    if (PresenceService.instance.isRunning) {
      PresenceService.instance.stop();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final driverProv = context.read<DriverProvider>();

    if (kDebugMode) {
      print('[Lifecycle] State changed from $_lastLifecycleState to $state');
    }

    // Ensure presence is running on resume if logged in
    if (state == AppLifecycleState.resumed) {
      final bool isLoggedIn = driverProv.driverID.isNotEmpty;
      if (isLoggedIn && !PresenceService.instance.isRunning) {
        PresenceService.instance
            .start(context, interval: const Duration(seconds: 10));
      }
    }

    // Handle transitions to inactive state (notification opened, app switching, etc.)
    if (state == AppLifecycleState.inactive) {
      // Only save status and go to Idling if coming from resumed state
      if (_lastLifecycleState == AppLifecycleState.resumed) {
        final String currentStatus = driverProv.driverStatus;
        // Only save and update if not already Idling
        if (currentStatus != 'Idling') {
          // Save the status immediately
          driverProv.setLastDriverStatus(currentStatus);

          // Debounce: Only update to Idling if inactive for more than 400ms
          // This prevents quick accidental taps from changing status
          _inactiveDebounceTimer?.cancel();
          _inactiveDebounceTimer = Timer(const Duration(minutes: 5), () {
            // _inactiveDebounceTimer = Timer(const Duration(milliseconds: 400), () {
            // Only update if still inactive/not resumed
            if (mounted && _lastLifecycleState == AppLifecycleState.inactive) {
              driverProv.updateStatusToDB('Idling', preserveLastStatus: true);
              if (kDebugMode) {
                print('[Lifecycle] Inactive (debounced) - Updated to Idling');
              }
            }
          });

          if (kDebugMode) {
            print(
                '[Lifecycle] Inactive - Scheduled Idling update (400ms delay)');
          }
        }
      }
    }
    // Handle app fully going to background
    else if (state == AppLifecycleState.paused) {
      // Cancel any pending inactive timer since we're going to background
      // _inactiveDebounceTimer?.cancel();

      // final String currentStatus = driverProv.driverStatus;
      // // Save and update if not already Idling
      // if (currentStatus != 'Idling') {
      //   driverProv.setLastDriverStatus(currentStatus);
      //   driverProv.updateStatusToDB('Idling', preserveLastStatus: true);
      //   if (currentStatus == 'Driving') {
      //     hasShownDrivingPrompt = false;
      //   }
      //   ShowMessage().showToast('App paused - Saved status: $currentStatus');
      // }
    }
    // Handle app resuming to foreground
    else if (state == AppLifecycleState.resumed) {
      // Cancel any pending inactive timer since we're resuming
      // _inactiveDebounceTimer?.cancel();

      // // Only restore status if we have a saved one and it's different from Idling
      // final String? savedStatus = driverProv.lastDriverStatus;
      // if (savedStatus != null &&
      //     savedStatus != 'Idling' &&
      //     driverProv.driverStatus == 'Idling') {
      //   driverProv.updateStatusToDB(savedStatus);
      //   ShowMessage().showToast('App resumed - Status: $savedStatus');
      //   if (savedStatus == 'Driving') {
      //     SchedulerBinding.instance.addPostFrameCallback((_) {
      //       if (mounted) {
      //         context.read<PassengerProvider>().getBookingRequestsID(context);
      //       }
      //     });
      //   } else {
      //     hasShownDrivingPrompt = false;
      //   }
      // } else if (savedStatus != null && savedStatus != 'Idling') {
      //   // If we resumed before the debounce timer fired, status was never changed
      //   // Just log this for debugging
      //   if (kDebugMode) {
      //     print(
      //         '[Lifecycle] Resumed quickly - Status unchanged (debounce worked!)');
      //   }
      // }
    }
    // Handle hidden state (Flutter 3.13+)
    else if (state == AppLifecycleState.hidden) {
      // Cancel any pending inactive timer
      // _inactiveDebounceTimer?.cancel();

      // final String currentStatus = driverProv.driverStatus;
      // if (currentStatus != 'Idling') {
      //   driverProv.setLastDriverStatus(currentStatus);
      //   driverProv.updateStatusToDB('Idling', preserveLastStatus: true);
      //   if (kDebugMode) {
      //     print('[Lifecycle] Hidden - Saved status: $currentStatus');
      //   }
      // }
    }

    _lastLifecycleState = state;
  }

  // void _startTimer() {
  //   context.read<DriverProvider>().updateLastOnline(context);
  //   _timer = Timer.periodic(const Duration(seconds: 30), (_) {
  //     context.read<DriverProvider>().updateLastOnline(context);
  //   });
  // }

  void _onTap(int idx) {
    setState(() {
      _currentIndex = idx;
      if (_currentIndex == 0 &&
          context.read<DriverProvider>().driverStatus != 'Driving') {
        hasShownDrivingPrompt = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          // Double-back-to-exit: first back shows toast, second back within 2s exits.
          () async {
            final now = DateTime.now();
            if (_lastBackPressAt == null ||
                now.difference(_lastBackPressAt!) >
                    const Duration(seconds: 2)) {
              _lastBackPressAt = now;
              Fluttertoast.showToast(msg: 'Press back again to exit');
              return;
            }
            // Second back within window: exit app
            await SystemNavigator.pop();
          }();
        }
      },
      child: Scaffold(
        // backgroundColor: Constants.BLACK_COLOR,
        body: IndexedStack(index: _currentIndex, children: pages),
        bottomNavigationBar: _buildBottomNavBar(),
      ),
    );
  }

  final Map<int, Map<String, String>> navigation = const {
    0: {
      'Label': 'Home',
      'SelectedIcon': 'homefilled.svg',
      'UnselectedIcon': 'home.svg',
    },
    1: {
      'Label': 'Activity',
      'SelectedIcon': 'recentfilled.svg',
      'UnselectedIcon': 'recent.svg',
    },
    2: {
      'Label': 'Profile',
      'SelectedIcon': 'profilefilled.svg',
      'UnselectedIcon': 'profile.svg',
    },
  };

  // Per-tab background colors for the curved nav
  final List<Color> _navColors = <Color>[
    Constants.GREEN_COLOR, // Home
    Constants.YELLOW_COLOR, // Activity
    Constants.RED_COLOR, // Profile
  ];

  CurvedNavigationBar _buildBottomNavBar() {
    return CurvedNavigationBar(
      backgroundColor: _navColors[_currentIndex],
      color: Colors.white,
      buttonBackgroundColor: Constants.WHITE_COLOR,
      height: 60,
      index: _currentIndex,
      onTap: _onTap,
      animationDuration: const Duration(milliseconds: 400),
      items: navigation.entries
          .map((e) => _buildNavItem(
              e.key, e.value['UnselectedIcon']!, e.value['SelectedIcon']!))
          .toList(),
    );
  }

  Widget _buildNavItem(int idx, String unselectedIcon, String selectedIcon) {
    final isSelected = _currentIndex == idx;
    return SvgPicture.asset(
      'assets/svg/${isSelected ? selectedIcon : unselectedIcon}',
      width: 28,
      height: 28,
      colorFilter: ColorFilter.mode(
        isSelected ? _navColors[idx] : Constants.BLACK_COLOR,
        BlendMode.srcIn,
      ),
    );
  }
}
