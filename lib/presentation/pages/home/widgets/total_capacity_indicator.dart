import 'package:flutter/material.dart';
import 'package:pasada_driver_side/presentation/pages/home/widgets/floating_capacity.dart';
import 'package:provider/provider.dart';
import 'package:pasada_driver_side/presentation/providers/driver/driver_provider.dart';
import 'package:pasada_driver_side/domain/services/passenger_capacity.dart';
import 'package:pasada_driver_side/common/constants/text_styles.dart';
import 'package:pasada_driver_side/common/constants/constants.dart';

class TotalCapacityIndicator extends StatelessWidget {
  const TotalCapacityIndicator({
    super.key,
    required this.screenHeight,
    required this.screenWidth,
    required this.bottomFraction,
    required this.rightFraction,
  });

  final double screenHeight;
  final double screenWidth;
  final double bottomFraction;
  final double rightFraction;

  @override
  Widget build(BuildContext context) {
    final driverProvider = Provider.of<DriverProvider>(context, listen: false);
    final total =
        context.select<DriverProvider, int>((p) => p.passengerCapacity);

    return FloatingCapacity(
      driverProvider: driverProvider,
      passengerCapacity: PassengerCapacity(),
      screenHeight: screenHeight,
      screenWidth: screenWidth,
      bottomPosition: screenHeight * bottomFraction,
      rightPosition: screenWidth * rightFraction,
      icon: 'assets/svg/people.svg',
      text: total.toString(),
      canIncrement: false,
      onTap: () {
        _showManualAddPassengerBottomSheet(context);
      },
    );
  }

  // Method to show the bottom sheet
  void _showManualAddPassengerBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return const ManualAddPassengerSheet();
      },
    );
  }
}

// Separate StatefulWidget for the bottom sheet content
class ManualAddPassengerSheet extends StatefulWidget {
  const ManualAddPassengerSheet({super.key});

  @override
  State<ManualAddPassengerSheet> createState() =>
      _ManualAddPassengerSheetState();
}

class _ManualAddPassengerSheetState extends State<ManualAddPassengerSheet> {
  // State variables
  int regularCount = 1;
  int studentCount = 1;
  int seniorCount = 0;
  int pwdCount = 1;
  String? selectedPickup;
  String? selectedDestination;

  // Example data - replace with your actual data
  final List<String> pickupLocations = [
    'Location A',
    'Location B',
    'Location C'
  ];
  final List<String> destinations = [
    'Destination 1',
    'Destination 2',
    'Destination 3'
  ];

  double get totalFare {
    // Calculate based on your fare logic
    return (regularCount * 15.0) +
        (studentCount * 12.0) +
        (seniorCount * 12.0) +
        (pwdCount * 12.0);
  }

  @override
  Widget build(BuildContext context) {
    final double height = MediaQuery.of(context).size.height * 0.048;

    return Container(
      constraints: BoxConstraints(
        maxHeight:
            MediaQuery.of(context).size.height * 0.85, // Max 85% of screen
      ),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 60,
                height: 7,
                decoration: BoxDecoration(
                  color: Colors.grey[500],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),

              // Title
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Manually Add Passenger',
                  style: Styles().textStyle(18, FontWeight.bold, Colors.black),
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Discount Type Section
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        'Select Discount Type:',
                        style: Styles()
                            .textStyle(16, FontWeight.w500, Colors.black),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Regular
                    _buildDiscountTypeRow('Regular', regularCount, false, () {
                      setState(() => regularCount++);
                    }, () {
                      if (regularCount > 0) setState(() => regularCount--);
                    }),

                    const SizedBox(height: 12),

                    // Student
                    _buildDiscountTypeRow('Student', studentCount, true, () {
                      setState(() => studentCount++);
                    }, () {
                      if (studentCount > 0) setState(() => studentCount--);
                    }),

                    const SizedBox(height: 12),

                    // Senior
                    _buildDiscountTypeRow('Senior', seniorCount, true, () {
                      setState(() => seniorCount++);
                    }, () {
                      if (seniorCount > 0) setState(() => seniorCount--);
                    }),

                    const SizedBox(height: 12),

                    // PWD
                    _buildDiscountTypeRow('PWD', pwdCount, true, () {
                      setState(() => pwdCount++);
                    }, () {
                      if (pwdCount > 0) setState(() => pwdCount--);
                    }),

                    const SizedBox(height: 24),

                    // Pickup Selection
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        'Select Pickup:',
                        style: Styles()
                            .textStyle(16, FontWeight.w500, Colors.black),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildDropdown(
                      value: selectedPickup,
                      items: pickupLocations,
                      onChanged: (value) =>
                          setState(() => selectedPickup = value),
                    ),

                    const SizedBox(height: 16),

                    // Destination Selection
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        'Select Destination:',
                        style: Styles()
                            .textStyle(16, FontWeight.w500, Colors.black),
                      ),
                    ),

                    const SizedBox(height: 8),

                    _buildDropdown(
                      value: selectedDestination,
                      items: destinations,
                      onChanged: (value) =>
                          setState(() => selectedDestination = value),
                    ),

                    const SizedBox(height: 24),

                    // Total Fare
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            'Total Fare:',
                            style: Styles()
                                .textStyle(16, FontWeight.w500, Colors.black),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            '₱${totalFare.toStringAsFixed(2)}',
                            style: Styles()
                                .textStyle(18, FontWeight.bold, Colors.green),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Add Passenger Button
                    SizedBox(
                      width: double.infinity,
                      height: height,
                      child: ElevatedButton(
                        onPressed: _handleAddPassenger,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Constants.GRADIENT_COLOR_2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Add Passenger',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDiscountTypeRow(
    String label,
    int count,
    bool isHighlighted,
    VoidCallback onIncrement,
    VoidCallback onDecrement,
  ) {
    final double height = MediaQuery.of(context).size.height * 0.048;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Main container with label and count
        Expanded(
          child: SizedBox(
            height: height,
            child: Material(
              color: isHighlighted ? Constants.GRADIENT_COLOR_2 : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: isHighlighted
                    ? BorderSide.none
                    : BorderSide(color: Constants.GREY_COLOR, width: 2),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onIncrement,
                splashColor: Constants.GREEN_COLOR.withAlpha(77),
                highlightColor: Constants.GREEN_COLOR.withAlpha(26),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        label,
                        style: Styles().textStyle(
                            18,
                            Styles.semiBold,
                            isHighlighted
                                ? Styles.customWhiteFont
                                : Styles.customBlackFont),
                      ),
                      Text(
                        count.toString(),
                        style: Styles().textStyle(
                            18,
                            Styles.bold,
                            isHighlighted
                                ? Styles.customWhiteFont
                                : Styles.customBlackFont),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // remove passenger button
        SizedBox(
          width: height,
          height: height,
          child: Material(
            color: isHighlighted ? Constants.GRADIENT_COLOR_2 : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: isHighlighted
                  ? BorderSide.none
                  : BorderSide(color: Constants.GREY_COLOR, width: 2),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onDecrement,
              splashColor: Colors.red.withAlpha(77),
              highlightColor: Colors.red.withAlpha(26),
              child: Center(
                child: Icon(
                  Icons.person_remove,
                  color: isHighlighted ? Colors.white : Colors.grey[600],
                  size: 24,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String? value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    final double height = MediaQuery.of(context).size.height * 0.048;

    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Constants.GRADIENT_COLOR_2,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        underline: const SizedBox(),
        dropdownColor: Constants.GRADIENT_COLOR_2,
        style: Styles().textStyle(16, FontWeight.w500, Styles.customWhiteFont),
        icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
        hint: Text(
          'Select...',
          style:
              Styles().textStyle(16, FontWeight.w500, Styles.customWhiteFont),
        ),
        items: items.map((String item) {
          return DropdownMenuItem<String>(
            value: item,
            child: Text(item),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }

  void _handleAddPassenger() {
    // Validate selections
    if (selectedPickup == null || selectedDestination == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select pickup and destination'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Add your logic to add the passenger here
    // For example, call your PassengerCapacity service

    Navigator.pop(context); // Close the bottom sheet

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Passenger added successfully'),
        backgroundColor: Colors.green,
      ),
    );
  }
}
