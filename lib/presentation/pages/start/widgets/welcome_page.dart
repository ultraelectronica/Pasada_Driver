import 'package:flutter/material.dart';
import 'package:pasada_driver_side/common/constants/constants.dart';
import 'package:pasada_driver_side/common/constants/text_styles.dart';
import 'package:pasada_driver_side/presentation/pages/start/utils/start_constants.dart';
import 'package:pasada_driver_side/presentation/routes/app_routes.dart';

class WelcomePage extends StatelessWidget {
  final VoidCallback onLoginPressed;

  const WelcomePage({
    super.key,
    required this.onLoginPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Logo
        Padding(
          padding: EdgeInsets.only(
              top: Constants(context).screenHeight *
                  StartConstants.welcomeLogoTopFraction),
          child: Center(
            child: SizedBox(
              width: Constants(context).screenWidth *
                  StartConstants.welcomeLogoSizeFraction,
              height: Constants(context).screenWidth *
                  StartConstants.welcomeLogoSizeFraction,
              child: Image.asset(
                'assets/png/PasadaLogo.png',
                color: Colors.grey.shade900,
              ),
            ),
          ),
        ),

        // Welcome message
        const WelcomeMessage(),

        // Next button
        Padding(
          padding: EdgeInsets.only(
            bottom: Constants(context).screenHeight *
                StartConstants.nextButtonVerticalPaddingFraction,
            top: Constants(context).screenHeight *
                StartConstants.nextButtonVerticalPaddingFraction,
          ),
          child: NextPageButton(onPressed: onLoginPressed),
        ),
      ],
    );
  }
}

class WelcomeMessage extends StatelessWidget {
  const WelcomeMessage({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Hello Manong!',
          style: Styles().textStyle(40.0, Styles.bold, Colors.black),
        ),
        Text(
          'Welcome to Pasada Driver',
          style: Styles().textStyle(18, Styles.normal, Styles.customBlackFont),
        ),
      ],
    );
  }
}

class NextPageButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const NextPageButton({super.key, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        // NotificationService.instance.showTestNotification(context);
        if (onPressed != null) {
          onPressed!();
        } else {
          Navigator.pushReplacementNamed(context, AppRoute.login.path);
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.black,
        minimumSize: Size(
            Constants(context).screenWidth * 0.1,
            Constants(context).screenHeight *
                StartConstants.pageIndicatorBottomFraction),
        shadowColor: Colors.black,
        elevation: 5.0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.0),
        ),
      ),
      child: const Icon(
        Icons.arrow_forward_ios_rounded,
        color: Colors.white,
        size: 20.0,
      ),
    );
  }
}
