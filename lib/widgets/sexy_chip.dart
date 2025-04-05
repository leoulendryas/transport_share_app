import 'package:flutter/material.dart';

class SexyChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const SexyChip({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      avatar: icon != null 
          ? Icon(icon, size: 16, color: color)
          : null,
      backgroundColor: color.withOpacity(0.1),
      labelStyle: TextStyle(
        color: color,
        fontWeight: FontWeight.bold,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: color.withOpacity(0.3)),
      ),
    );
  }
}
