import 'package:flutter/material.dart';
import 'package:pasada_driver_side/Settings/preference_page.dart';
import 'package:pasada_driver_side/Settings/support_page.dart';
import 'package:pasada_driver_side/Settings/notification_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).size.height * 0.15,
          left: MediaQuery.of(context).size.width * 0.05,
          right: MediaQuery.of(context).size.width * 0.05,
        ),
        child: Column(children: [
          //NOTIFICATION BUTTON
          SettingsButtons(
            'Notification',
            onPressed: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const NotificationPage()));
            },
          ),
          const SizedBox(height: 20),

          //ALTERNATIVE ROUTE SUGGESTION BUTTON
          // const RouteSuggestionToggleButton('Alternative Route Suggestion'),
          // const SizedBox(height: 20),

          //PREFERENCE BUTTON
          SettingsButtons(
            'Preference',
            onPressed: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const PreferencePage()));
            },
          ),
          const SizedBox(height: 20),

          //SUPPORT BUTTON
          SettingsButtons(
            'Support',
            onPressed: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => const SupportPage()));
            },
          ),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }
}

// CLASS TO BUILD THE BUTTON
class SettingsButtons extends StatelessWidget {
  final String buttonName;
  final VoidCallback onPressed;
  const SettingsButtons(this.buttonName, {super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          border: Border.all(
            color: const Color(0xFF5F3FC4),
            width: 2.0,
          ),
          borderRadius: BorderRadius.circular(30.0),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: Text(
          buttonName,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// CLASS FOR TOGGLE BUTTON
class RouteSuggestionToggleButton extends StatefulWidget {
  const RouteSuggestionToggleButton(this.buttonName, {super.key});
  final String buttonName;

  @override
  State<RouteSuggestionToggleButton> createState() =>
      _RouteSuggestionToggleButtonState();
}

class _RouteSuggestionToggleButtonState
    extends State<RouteSuggestionToggleButton> {
  bool active = true;

  @override
  Widget build(BuildContext context) {
    return Container(
        height: 50,
        decoration: BoxDecoration(
          border: Border.all(
            color: const Color(0xFF5F3FC4),
            width: 2.0,
          ),
          borderRadius: BorderRadius.circular(30.0),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20, right: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.buttonName,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            Switch(
                value: active,
                activeColor: const Color(0xFF5F3FC4),
                onChanged: (bool value) {
                  setState(() {
                    active = value;
                  });
                }),
          ],
        ));
  }
}
