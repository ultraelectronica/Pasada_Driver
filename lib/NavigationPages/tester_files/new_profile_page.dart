// import 'dart:async';
// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_svg/flutter_svg.dart';
// import 'package:pasada_driver_side/driver_provider.dart';
// import 'package:provider/provider.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';

// class NewProfilePage extends StatefulWidget {
//   final String driverStatus;

//   const NewProfilePage({super.key, required this.driverStatus});

//   @override
//   State<NewProfilePage> createState() => _ProfilePageState();
// }

// class _ProfilePageState extends State<NewProfilePage> {
//   // String status = DriverProvider().driverStatus;
//   late String status;
//   final SupabaseClient supabase = Supabase.instance.client;

//   static const Map<String, Color> statusColors = {
//     "Online": Colors.green,
//     "Driving": Colors.red,
//     "Idling": Colors.orange,
//     "Offline": Colors.grey,
//   };

//   void iniState() {
//     super.initState();
//     status = widget.driverStatus;
//   }

//   Future<void> _getDriverStatus() async {
//     try {
//       final String? driverID = context.read<DriverProvider>().driverID;

//       if (driverID == null) {
//         print('Error: driverID is null');
//         return;
//       }

//       final response = await supabase
//           .from('driverTable')
//           .select('drivingStatus')
//           .eq('driverID', driverID)
//           .maybeSingle();

//       // Fix 1: Correct null check logic
//       if (response == null) {
//         if (kDebugMode) {
//           print('Error: No driver status found for driverID: $driverID');
//         }
//         return;
//       }

//       if (kDebugMode) {
//         print('Driving status in DB: ${response['drivingStatus']}');
//       }

//       context
//           .read<DriverProvider>()
//           .setDriverStatus(response['drivingStatus'].toString());

//       status = DriverProvider().driverStatus.toString();
//       if (kDebugMode) {
//         print('Driving status in Program: $status');
//       }
//     } catch (e) {
//       if (kDebugMode) {
//         print('Error fetching driver status: $e');
//       }
//     }
//   }

//   Future<void> _updateDriverStatusToDB() async {
//     final String? driverID = context.read<DriverProvider>().driverID;

//     // final response = await supabase.from('driverTable').update('drivingStatus').eq('driverID', driverID);
//   }

//   @override
//   Widget build(BuildContext context) {
//     final double paddingValue = MediaQuery.of(context).size.width * 0.05;
//     final double profilePictureSize = MediaQuery.of(context).size.width * 0.3;
//     _getDriverStatus();

//     return Scaffold(
//       body: Center(
//         child: Padding(
//           padding: EdgeInsets.symmetric(horizontal: paddingValue),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               //PROFILE PICTURE
//               _buildProfilePicture(profilePictureSize),
//               const SizedBox(height: 20),

//               //DRIVER STATUS
//               _buildDriverStatus(),
//               const SizedBox(height: 25),

//               // Driver Details
//               _buildDriverDetails(),
//               const SizedBox(height: 30),

//               // Buttons
//               ProfileButton('Update Information', onPressed: () {}),
//               const SizedBox(height: 20),
//               ProfileButton('Log Out', onPressed: () {}),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

// //PROFILE PICTURE
//   Widget _buildProfilePicture(double size) {
//     return SizedBox(
//       height: size,
//       width: size,
//       child: SvgPicture.asset(
//         'assets/svg/Ellipse.svg',
//         placeholderBuilder: (_) => const CircularProgressIndicator(),
//       ),
//     );
//   }

// //DRIVER STATUS
//   Widget _buildDriverStatus() {
//     return InkWell(
//       onTap: _showStatusOption,
//       borderRadius: BorderRadius.circular(12),
//       child: Container(
//         padding: const EdgeInsets.symmetric(horizontal: 8.0),
//         height: 30,
//         decoration: BoxDecoration(
//           border: Border.all(
//             color: Theme.of(context).primaryColor,
//             width: 2,
//           ),
//           borderRadius: BorderRadius.circular(12),
//         ),
//         child: Row(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             //STATUS COLOR INDICATOR
//             Container(
//               width: 10,
//               height: 10,
//               // ignore: prefer_const_constructors
//               decoration: BoxDecoration(
//                 color: statusColors[status] ?? Colors.black,
//                 shape: BoxShape.circle,
//               ),
//             ),
//             const SizedBox(width: 8),
//             Text(status),
//           ],
//         ),
//       ),
//     );
//   }

// //DRIVER DETAILS
//   Widget _buildDriverDetails() {
//     return const Column(
//       children: [
//         Text(
//           'Name',
//           style: TextStyle(
//             fontSize: 30,
//             fontFamily: 'Inter',
//             fontWeight: FontWeight.w700,
//           ),
//         ),
//         SizedBox(height: 10),
//         Text(
//           'pasadadriver@example.com',
//           style: TextStyle(
//             fontSize: 16,
//             fontFamily: 'Inter',
//             fontWeight: FontWeight.w400,
//           ),
//         ),
//         SizedBox(height: 10),
//         Text(
//           '09123456789',
//           style: TextStyle(
//             fontSize: 16,
//             fontFamily: 'Inter',
//             fontWeight: FontWeight.w400,
//           ),
//         ),
//       ],
//     );
//   }

//   void _showStatusOption() {
//     showModalBottomSheet(
//         context: context,
//         shape: const RoundedRectangleBorder(
//           borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
//         ),
//         builder: (BuildContext context) {
//           return SafeArea(
//               child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               //Line above the change status
//               Container(
//                 width: 40,
//                 height: 5,
//                 margin: const EdgeInsets.only(top: 16.0, bottom: 16.0),
//                 decoration: BoxDecoration(
//                   color: Colors.grey[600],
//                   borderRadius: BorderRadius.circular(10),
//                 ),
//               ),

//               //Bottom sheet title
//               const Padding(
//                 padding: EdgeInsets.only(bottom: 10.0),
//                 child: Text(
//                   'Change Status',
//                   style: TextStyle(
//                     fontSize: 18,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//               ),

//               //Show all status
//               ListView.separated(
//                 shrinkWrap: true,
//                 physics: const NeverScrollableScrollPhysics(),
//                 itemCount: statusColors.length,
//                 separatorBuilder: (context, index) => const Divider(
//                   thickness: 1,
//                   color: Colors.grey,
//                   height: 1,
//                   indent: 20,
//                   endIndent: 20,
//                 ),

//                 //shows all of the contents of the statusColor
//                 itemBuilder: (context, index) {
//                   final status = statusColors.keys.elementAt(index);
//                   return ListTile(
//                     leading: Icon(Icons.circle, color: statusColors[status]),
//                     title: Text(
//                       status,
//                       style: const TextStyle(fontSize: 16),
//                     ),
//                     onTap: () {
//                       // _updateDriverStatus();
//                       _getDriverStatus();
//                       Navigator.pop(context);
//                     },
//                   );
//                 },
//               )
//             ],
//           ));
//         });
//   }
// }

// //class that build all buttons
// class ProfileButton extends StatelessWidget {
//   final String buttonName;
//   final VoidCallback onPressed;

//   const ProfileButton(this.buttonName, {super.key, required this.onPressed});

//   @override
//   Widget build(BuildContext context) {
//     return InkWell(
//       borderRadius: BorderRadius.circular(30.0),
//       onTap: onPressed,
//       child: Container(
//         height: 50,
//         decoration: BoxDecoration(
//           border: Border.all(
//             color: const Color(0xFF5F3FC4),
//             width: 2.0,
//           ),
//           borderRadius: BorderRadius.circular(30.0),
//         ),
//         alignment: Alignment.center,
//         child: Text(
//           buttonName,
//           style: const TextStyle(
//             fontFamily: 'Inter',
//             fontSize: 15,
//             fontWeight: FontWeight.w500,
//           ),
//         ),
//       ),
//     );
//   }
// }
