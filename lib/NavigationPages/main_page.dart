import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pasada_driver_side/UI/message.dart';
import 'package:pasada_driver_side/NavigationPages/activity_page.dart';
import 'package:pasada_driver_side/NavigationPages/home_page.dart';
import 'package:pasada_driver_side/NavigationPages/profile_page.dart';
// import 'package:pasada_driver_side/tester_files/profile_page.dart';
// import 'package:pasada_driver_side/NavigationPages/settings_page.dart';
import 'package:pasada_driver_side/Database/driver_provider.dart';
import 'package:pasada_driver_side/UI/text_styles.dart';
import 'package:provider/provider.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  MainPageState createState() => MainPageState();
}

class MainPageState extends State<MainPage> with WidgetsBindingObserver {
  int _currentIndex = 0;

  final List<Widget> pages = [
    const HomeScreen(),
    const ActivityPage(),
    const ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      // set driving status to Online
      context.read<DriverProvider>().updateStatusToDB(
          context.read<DriverProvider>().lastDriverStatus!, context);
      ShowMessage().showToast('App resumed');
    } else if (state == AppLifecycleState.paused) {
      // set driving status to idling
      context.read<DriverProvider>().updateStatusToDB('Idling', context);
      ShowMessage().showToast('App paused');
    }
  }

  void onTap(int newIndex) {
    setState(() {
      _currentIndex = newIndex;
    });
  }

  void isDriving(DriverProvider driverProvider) {
    if (driverProvider.isDriving == false && _currentIndex == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showStartDrivingDialog();
      });
    }
  }

  // START DRIVING DIALOG
  void _showStartDrivingDialog() {
    showDialog(
      context: context,
      barrierDismissible: true, // Enables dismissing dialog by tapping outside
      builder: (BuildContext context) {
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
                  onPressed: () {
                    context
                        .read<DriverProvider>()
                        .updateStatusToDB('Driving', context);
                    context.read<DriverProvider>().setDriverStatus('Driving');
                    context.read<DriverProvider>().setIsDriving(true);

                    Navigator.of(context).pop();
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
                  child: Text(
                    'Start Driving',
                    style: Styles()
                        .textStyle(16, Styles.normalWeight, Styles.customWhite),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final driverProvider = context.watch<DriverProvider>();

    isDriving(driverProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  BottomNavigationBar _buildBottomNavBar() {
    return BottomNavigationBar(
      backgroundColor: const Color(0xFFF2F2F2),
      currentIndex: _currentIndex,
      onTap: onTap,
      showSelectedLabels: true,
      showUnselectedLabels: false,
      selectedLabelStyle:
          Styles().textStyle(12, Styles.w700Weight, Styles.customBlack),
      unselectedLabelStyle:
          Styles().textStyle(12, Styles.w700Weight, Styles.customBlack),
      selectedItemColor: const Color(0xff067837),
      type: BottomNavigationBarType.fixed,
      items: [
        _buildNavItem(0, 'Home', 'homefilled.svg', 'home.svg'),
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
                  const ColorFilter.mode(Color(0xff067837), BlendMode.srcIn),
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
