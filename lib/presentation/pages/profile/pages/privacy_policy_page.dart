import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:pasada_driver_side/common/constants/constants.dart';
import 'package:pasada_driver_side/common/constants/text_styles.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Constants.WHITE_COLOR,
      appBar: AppBar(
        title: Text(
          'Privacy Policy',
          style: Styles().textStyle(20, Styles.semiBold, Constants.WHITE_COLOR),
        ),
        backgroundColor: Constants.GREEN_COLOR,
        iconTheme: IconThemeData(color: Constants.WHITE_COLOR),
        elevation: 0,
      ),
      body: FutureBuilder<String>(
        future: rootBundle.loadString('assets/docs/privacy_policy.md'),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return Markdown(
              data: snapshot.data!,
              styleSheet: MarkdownStyleSheet(
                h1: Styles().textStyle(24, Styles.bold, Constants.GREEN_COLOR),
                h2: Styles().textStyle(18, Styles.bold, Constants.GREEN_COLOR),
                h3: Styles()
                    .textStyle(16, Styles.semiBold, Styles.customBlackFont),
                p: Styles()
                    .textStyle(14, Styles.normal, Styles.customBlackFont),
                listBullet: Styles()
                    .textStyle(14, Styles.normal, Styles.customBlackFont),
                strong:
                    Styles().textStyle(14, Styles.bold, Styles.customBlackFont),
              ),
              padding: const EdgeInsets.all(20.0),
            );
          } else if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  'Error loading privacy policy: ${snapshot.error}',
                  style: Styles().textStyle(14, Styles.normal, Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}
