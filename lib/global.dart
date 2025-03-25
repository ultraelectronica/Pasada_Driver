import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pasada_driver_side/driver_provider.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fluttertoast/fluttertoast.dart';

class GlobalVar {
  static final GlobalVar _instance = GlobalVar._internal();
  bool isDriving = false;
  List<String> driverStatus = ['Online', 'Driving', 'Idling', 'Offline'];
  final SupabaseClient supabase = Supabase.instance.client;
  final ValueNotifier<String> currentStatusNotifier;

  factory GlobalVar() {
    return _instance;
  }

  GlobalVar._internal() : currentStatusNotifier = ValueNotifier('Online');

  // Future<void> setDriverStatus(BuildContext context) async {
  //   final String? driverID = context.read<DriverProvider>().driverID;

  //   if (driverID == null) {
  //     if (kDebugMode) print("DriverID is null; cannot read status.");
  //     return;
  //   }

  //   final response = await supabase
  //       .from('driverTable')
  //       .select('driving_status')
  //       .eq('driver_id', driverID)
  //       .single();

  //   if (kDebugMode) {
  //     print('reading driver status from DB: ${response['driving_status']}');
  //     Fluttertoast.showToast(
  //         msg: 'status updated to ${response['driving_status']}');
  //   }

  //   currentStatusNotifier.value = response['driving_status'];

  //   if (kDebugMode) {
  //     print(
  //         'setted driver status in GlobalVar: ${currentStatusNotifier.value}');
  //   }
  // }

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

      // setDriverStatus(context);
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
        .update({'driving_status': newStatus})
        .eq('driver_id', driverID)
        .select()
        .single();

    if (kDebugMode) {
      print('new data: ${response['driving_status']}');
      Fluttertoast.showToast(
          msg: 'status updated to ${response['driving_status']}');
    }
  }
}
