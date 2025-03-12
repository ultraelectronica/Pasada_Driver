//this class is used for driver status changes, specifically when a button is pressed. it doesn't work on the same class but i might implement this in the database class. for now. this is what im gonna use.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pasada_driver_side/driver_provider.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fluttertoast/fluttertoast.dart';

class GlobalVar {
  static final GlobalVar _instance = GlobalVar._internal();
  bool isOnline = false;
  List<String> driverStatus = ['Online', 'Driving', 'Idling', 'Offline'];
  final SupabaseClient supabase = Supabase.instance.client;
  final ValueNotifier<String> currentStatusNotifier;

  factory GlobalVar() {
    return _instance;
  }

  GlobalVar._internal() : currentStatusNotifier = ValueNotifier('Online');

  Future<void> setDriverStatus(BuildContext context) async {
    final String? driverID = context.read<DriverProvider>().driverID;

    if (driverID == null) {
      if (kDebugMode) print("DriverID is null; cannot read status.");
      return;
    }

    final response = await supabase
        .from('driverTable')
        .select('drivingStatus')
        .eq('driverID', driverID)
        .single();

    if (kDebugMode) {
      print('reading driver status from DB: ${response['drivingStatus']}');
      Fluttertoast.showToast(
          msg: 'status updated to ${response['drivingStatus']}');
    }

    currentStatusNotifier.value = response['drivingStatus'];

    if (kDebugMode) {
      print(
          'setted driver status in GlobalVar: ${currentStatusNotifier.value}');
    }
  }

  //method to update the status
  void updateStatus(int index, BuildContext context) {
    if (index >= 0 && index < driverStatus.length) {
      if (kDebugMode) {
        print("current stastus:${currentStatusNotifier.value}");
      }

      //updates the global variable
      currentStatusNotifier.value = driverStatus[index];

      //updates the driver status in the provider
      context
          .read<DriverProvider>()
          .setDriverStatus(currentStatusNotifier.value);

      //updates the database
      updateStatusToDB(currentStatusNotifier.value, context);

      if (kDebugMode) {
        print("updated stastus:${currentStatusNotifier.value}");
      }

      setDriverStatus(context);
    } else {
      throw RangeError("Invalid index for driverStatus.");
    }
  }

  Future<void> updateStatusToDB(String newStatus, BuildContext context) async {
    final String? driverID = context.read<DriverProvider>().driverID;
    if (kDebugMode) {
      print('Driver ID in GlobarVar: $driverID');
      print('Driver new driving status in method: $newStatus');
    }

    if (driverID == null) {
      if (kDebugMode) print("DriverID is null; cannot update status.");
      return;
    }

    final response = await supabase
        .from('driverTable')
        .update({'drivingStatus': newStatus})
        .eq('driverID', driverID)
        .select()
        .single();

    if (kDebugMode) {
      print('new data: ${response['drivingStatus']}');
    }
  }
}
