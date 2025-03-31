import 'package:flutter/material.dart';

class ConnectionStatusBar extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const ConnectionStatusBar({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.orange,
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}