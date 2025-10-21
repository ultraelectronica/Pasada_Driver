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
    return SafeArea(
      child: Stack(
        children: [
          // Background image
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/png/pasada_welcome_page_bg.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Gradient overlay
          // Container(
          //   decoration: BoxDecoration(
          //     gradient: LinearGradient(
          //       begin:
          //           Alignment.topLeft * 2, // Extends beyond the top left corner
          //       end: Alignment.bottomRight,
          //       colors: const [
          //         Color(0xFF00CC58), // Custom green color
          //         Color(0xFF88CB0C), // Custom yellow-green color
          //       ],
          //     ),
          //   ),
          // ),
          // Content
          SizedBox(
            width: double.infinity,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top spacer to push content down
                const Spacer(flex: 2),

                // Welcome message
                const WelcomeMessage(),

                const Spacer(flex: 1),

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
            ),
          ),
        ],
      ),
    );
  }
}

class WelcomeMessage extends StatelessWidget {
  const WelcomeMessage({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Hello Manong!',
          style: Styles().textStyle(40.0, Styles.bold, Styles.customWhiteFont),
        ),
        const SizedBox(height: 5),
        Text(
          'Welcome to Pasada Driver',
          style:
              Styles().textStyle(18, Styles.semiBold, Styles.customWhiteFont),
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
        backgroundColor: Colors.white,
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
      child: Icon(
        Icons.chevron_right,
        color: Constants.GREEN_COLOR,
        size: 40.0,
      ),
    );
  }
}
