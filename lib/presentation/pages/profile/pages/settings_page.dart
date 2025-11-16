import 'package:flutter/material.dart';
import 'package:pasada_driver_side/common/constants/constants.dart';
import 'package:pasada_driver_side/common/constants/text_styles.dart';
import 'package:pasada_driver_side/common/config/app_config.dart';
import 'package:pasada_driver_side/domain/services/background_location_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _backgroundLocationEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadBackgroundLocationPreference();
  }

  Future<void> _loadBackgroundLocationPreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _backgroundLocationEnabled =
          prefs.getBool('background_location_enabled') ?? true;
    });
  }

  Future<void> _toggleBackgroundLocation(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('background_location_enabled', value);

    setState(() {
      _backgroundLocationEnabled = value;
    });

    if (value) {
      await BackgroundLocationService.instance.start();
    } else {
      await BackgroundLocationService.instance.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Constants.WHITE_COLOR,
      appBar: AppBar(
        backgroundColor: Constants.WHITE_COLOR,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Constants.BLACK_COLOR),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Settings',
          style:
              Styles().textStyle(18, Styles.semiBold, Styles.customBlackFont),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // _buildTestModeCard(),
            // const SizedBox(height: 16),
            _buildBackgroundLocationCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildTestModeCard() {
    return SizedBox(
      width: double.infinity,
      child: Card(
        elevation: 4,
        shadowColor: Constants.BLACK_COLOR,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        color: Colors.white,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Test Mode',
                    style: Styles()
                        .textStyle(18, Styles.semiBold, Styles.customBlackFont),
                  ),
                  Text(
                    'Toggle to enable test mode',
                    style: Styles()
                        .textStyle(14, Styles.normal, Styles.customBlackFont),
                  )
                ],
              ),
              const Spacer(),
              Switch(
                  value: AppConfig.isTestMode,
                  onChanged: (value) {
                    setState(() => AppConfig.isTestMode = value);
                  },
                  activeThumbColor: Constants.GRADIENT_COLOR_1),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackgroundLocationCard() {
    return SizedBox(
      width: double.infinity,
      child: Card(
        elevation: 4,
        shadowColor: Constants.BLACK_COLOR,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        color: Colors.white,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Background Location',
                    style: Styles()
                        .textStyle(18, Styles.semiBold, Styles.customBlackFont),
                  ),
                  Text(
                    'Track location when app is closed',
                    style: Styles()
                        .textStyle(14, Styles.normal, Styles.customBlackFont),
                  )
                ],
              ),
              const Spacer(),
              Switch(
                  value: _backgroundLocationEnabled,
                  onChanged: _toggleBackgroundLocation,
                  activeThumbColor: Constants.GRADIENT_COLOR_1),
            ],
          ),
        ),
      ),
    );
  }
}
