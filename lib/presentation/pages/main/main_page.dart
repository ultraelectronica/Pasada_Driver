import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pasada_driver_side/common/constants/constants.dart';
import 'package:pasada_driver_side/common/constants/message.dart';
import 'package:pasada_driver_side/presentation/pages/activity/activity_page.dart';
import 'package:pasada_driver_side/presentation/pages/home/home_page.dart';
import 'package:pasada_driver_side/presentation/pages/profile/profile_page.dart';
import 'package:pasada_driver_side/presentation/providers/driver/driver_provider.dart';
import 'package:pasada_driver_side/presentation/providers/passenger/passenger_provider.dart';
import 'package:pasada_driver_side/common/constants/text_styles.dart';
import 'package:provider/provider.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  MainPageState createState() => MainPageState();
}

class MainPageState extends State<MainPage> with WidgetsBindingObserver {
  int _currentIndex = 0;
  Timer? _timer;
  Timer? _inactiveDebounceTimer;
  bool hasShownDrivingPrompt = true;
  AppLifecycleState? _lastLifecycleState;

  final List<Widget> pages = const [
    HomeScreen(),
    ActivityPage(),
    ProfilePage(),
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
    _inactiveDebounceTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final driverProv = context.read<DriverProvider>();

    if (kDebugMode) {
      print('[Lifecycle] State changed from $_lastLifecycleState to $state');
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
          _inactiveDebounceTimer = Timer(const Duration(milliseconds: 400), () {
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
      _inactiveDebounceTimer?.cancel();

      final String currentStatus = driverProv.driverStatus;
      // Save and update if not already Idling
      if (currentStatus != 'Idling') {
        driverProv.setLastDriverStatus(currentStatus);
        driverProv.updateStatusToDB('Idling', preserveLastStatus: true);
        if (currentStatus == 'Driving') {
          hasShownDrivingPrompt = false;
        }
        ShowMessage().showToast('App paused - Saved status: $currentStatus');
      }
    }
    // Handle app resuming to foreground
    else if (state == AppLifecycleState.resumed) {
      // Cancel any pending inactive timer since we're resuming
      _inactiveDebounceTimer?.cancel();

      // Only restore status if we have a saved one and it's different from Idling
      final String? savedStatus = driverProv.lastDriverStatus;
      if (savedStatus != null &&
          savedStatus != 'Idling' &&
          driverProv.driverStatus == 'Idling') {
        driverProv.updateStatusToDB(savedStatus);
        ShowMessage().showToast('App resumed - Status: $savedStatus');
        if (savedStatus == 'Driving') {
          SchedulerBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              context.read<PassengerProvider>().getBookingRequestsID(context);
            }
          });
        } else {
          hasShownDrivingPrompt = false;
        }
      } else if (savedStatus != null && savedStatus != 'Idling') {
        // If we resumed before the debounce timer fired, status was never changed
        // Just log this for debugging
        if (kDebugMode) {
          print(
              '[Lifecycle] Resumed quickly - Status unchanged (debounce worked!)');
        }
      }
    }
    // Handle hidden state (Flutter 3.13+)
    else if (state == AppLifecycleState.hidden) {
      // Cancel any pending inactive timer
      _inactiveDebounceTimer?.cancel();

      final String currentStatus = driverProv.driverStatus;
      if (currentStatus != 'Idling') {
        driverProv.setLastDriverStatus(currentStatus);
        driverProv.updateStatusToDB('Idling', preserveLastStatus: true);
        if (kDebugMode) {
          print('[Lifecycle] Hidden - Saved status: $currentStatus');
        }
      }
    }

    _lastLifecycleState = state;
  }

  void _startTimer() {
    context.read<DriverProvider>().updateLastOnline(context);
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      context.read<DriverProvider>().updateLastOnline(context);
    });
  }

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
    return Scaffold(
      // backgroundColor: Constants.BLACK_COLOR,
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: _buildBottomNavBar(),
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

  BottomNavigationBar _buildBottomNavBar() {
    return BottomNavigationBar(
      backgroundColor: Constants.WHITE_COLOR,
      currentIndex: _currentIndex,
      onTap: _onTap,
      showSelectedLabels: true,
      showUnselectedLabels: false,
      selectedLabelStyle:
          Styles().textStyle(12, Styles.bold, Styles.customBlackFont),
      unselectedLabelStyle:
          Styles().textStyle(12, Styles.bold, Styles.customBlackFont),
      selectedItemColor: Constants.GREEN_COLOR,
      type: BottomNavigationBarType.fixed,
      items: navigation.entries
          .map((e) => _buildNavItem(e.key, e.value['Label']!,
              e.value['SelectedIcon']!, e.value['UnselectedIcon']!))
          .toList(),
    );
  }

  BottomNavigationBarItem _buildNavItem(
      int idx, String label, String selectedIcon, String unselectedIcon) {
    final isSelected = _currentIndex == idx;
    return BottomNavigationBarItem(
      label: label,
      icon: SvgPicture.asset(
        'assets/svg/${isSelected ? selectedIcon : unselectedIcon}',
        width: isSelected ? 28 : 24,
        height: isSelected ? 28 : 24,
        colorFilter: isSelected
            ? ColorFilter.mode(Constants.GREEN_COLOR, BlendMode.srcIn)
            : null,
      ),
    );
  }
}
