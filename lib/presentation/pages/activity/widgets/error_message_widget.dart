import 'package:flutter/material.dart';

class ErrorMessageWidget extends StatelessWidget {
  final String message;
  final VoidCallback onClose;

  const ErrorMessageWidget(
      {super.key, required this.message, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            color: Colors.red,
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}
