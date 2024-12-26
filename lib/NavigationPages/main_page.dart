import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
// import 'package:flutter_svg/flutter_svg.dart';
import 'package:pasada_driver_side/NavigationPages/activity_page.dart';
import 'package:pasada_driver_side/NavigationPages/home_page.dart';
import 'package:pasada_driver_side/NavigationPages/notification_page.dart';
import 'package:pasada_driver_side/NavigationPages/profile_page.dart';
import 'package:pasada_driver_side/NavigationPages/settings_page.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  MainPageState createState() => MainPageState();
}

class MainPageState extends State<MainPage> {
  List pages = [
    const HomeScreen(),
    const ActivityPage(),
    const NotificationPage(),
    const ProfilePage(),
    const SettingsPage(),
  ];

  int currentIndex = 0;
  void onTap(int index) {
    setState(() {
      currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pages[currentIndex],

      //BOTTOM NAVIGATION
      bottomNavigationBar: BottomNavigationBar(
        // type: BottomNavigationBarType.fixed,
        onTap: onTap,
        currentIndex: currentIndex,
        unselectedItemColor: Colors.grey.withOpacity(.8),
        selectedItemColor: const Color(0xFF5F3FC4),
        showSelectedLabels: true,
        showUnselectedLabels: true,

        selectedFontSize: 14,
        unselectedFontSize: 0,
        items: [
          BottomNavigationBarItem(
              icon: currentIndex == 0
                  ? SvgPicture.asset(
                      'assets/svg/homeSelectedIcon.svg',
                      height: 24,
                      width: 24,
                    )
                  : SvgPicture.asset(
                      'assets/svg/homeIcon.svg',
                      height: 24,
                      width: 24,
                    ),
              label: 'Home'),
          BottomNavigationBarItem(
              icon: currentIndex == 1
                  ? SvgPicture.asset(
                      'assets/svg/activitySelectedIcon.svg',
                      height: 24,
                      width: 24,
                    )
                  : SvgPicture.asset(
                      'assets/svg/activityIcon.svg',
                      height: 24,
                      width: 24,
                    ),
              label: 'Activity'),
          BottomNavigationBarItem(
              icon: currentIndex == 2
                  ? SvgPicture.asset(
                      'assets/svg/notificationSelectedIcon.svg',
                      height: 24,
                      width: 24,
                    )
                  : SvgPicture.asset(
                      'assets/svg/notificationIcon.svg',
                      height: 24,
                      width: 24,
                    ),
              label: 'Notification'),
          BottomNavigationBarItem(
              icon: currentIndex == 3
                  ? SvgPicture.asset(
                      'assets/svg/profileSelectedIcon.svg',
                      height: 24,
                      width: 24,
                    )
                  : SvgPicture.asset(
                      'assets/svg/profileIcon.svg',
                      height: 24,
                      width: 24,
                    ),
              label: 'Profile'),
          BottomNavigationBarItem(
              icon: currentIndex == 4
                  ? SvgPicture.asset(
                      'assets/svg/settingsSelectedIcon.svg',
                      height: 24,
                      width: 24,
                    )
                  : SvgPicture.asset(
                      'assets/svg/settingsIcon.svg',
                      height: 24,
                      width: 24,
                    ),
              label: 'Settings'),
        ],
      ),
    );
  }
}
