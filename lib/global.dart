//this class is used for data changes when a button is pressed. it doesn't work on the same class but i might implement this in the database class. for now. this is what im gonna use.

import 'package:flutter/material.dart';

class GlobalVar {
  static final GlobalVar _instance = GlobalVar._internal();
  bool isOnline = false;
  List<String> driverStatus = ['Online', 'Driving', 'Idling', 'Offline'];
  final ValueNotifier<String> currentStatusNotifier;

  factory GlobalVar() {
    return _instance;
  }

  GlobalVar._internal() : currentStatusNotifier = ValueNotifier('Online');

  void updateStatus(int index) {
    if (index >= 0 && index < driverStatus.length) {
      print("current stastus:" + currentStatusNotifier.toString());
      currentStatusNotifier.value = driverStatus[index];
      print("updated stastus:" + currentStatusNotifier.toString());
    } else {
      throw RangeError("Invalid index for driverStatus.");
    }
  }
}
