import 'package:flutter/material.dart';

class CompanyChip extends StatelessWidget {
  final String companyName;
  final Color? color;
  final bool dense; // New optional parameter

  const CompanyChip({
    super.key, 
    required this.companyName,
    this.color,
    this.dense = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chipColor = color ?? theme.colorScheme.primary;
    
    return Chip(
      label: Text(
        companyName,
        style: TextStyle(
          fontSize: dense ? 12 : 14, // Adjust based on density
          fontWeight: dense ? FontWeight.normal : FontWeight.w500,
          color: chipColor,
        ),
      ),
      backgroundColor: chipColor.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: dense 
            ? BorderSide.none 
            : BorderSide(color: chipColor.withOpacity(0.3), width: 0.5),
      ),
      padding: dense 
          ? const EdgeInsets.symmetric(horizontal: 6, vertical: 0)
          : const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      visualDensity: dense 
          ? VisualDensity.compact 
          : VisualDensity.standard,
    );
  }
}