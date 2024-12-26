import 'package:flutter/material.dart';

class ActivityPage extends StatefulWidget {
  const ActivityPage({super.key});

  @override
  ActivityPageState createState() => ActivityPageState();
}

class ActivityPageState extends State<ActivityPage>{
  
  @override
  Widget build(BuildContext context) {
    return Container(
      child: const Center(
        child: Text(
          'Activity page'
        ),
      ),
    );
  }
}