import 'dart:async';
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
  bool hasShownDrivingPrompt = true;

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
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final driverProv = context.read<DriverProvider>();
    if (state == AppLifecycleState.resumed) {
      final String statusToRestore =
          driverProv.lastDriverStatus ?? driverProv.driverStatus;
      driverProv.updateStatusToDB(statusToRestore);
      ShowMessage().showToast('App resumed');
      if (driverProv.lastDriverStatus == 'Driving') {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            context.read<PassengerProvider>().getBookingRequestsID(context);
          }
        });
      } else {
        hasShownDrivingPrompt = false;
      }
    } else if (state == AppLifecycleState.paused) {
      driverProv.setLastDriverStatus(driverProv.driverStatus);
      driverProv.updateStatusToDB('Idling');
      if (driverProv.driverStatus == 'Driving') {
        hasShownDrivingPrompt = false;
      }
      ShowMessage().showToast('App paused');
    }
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
