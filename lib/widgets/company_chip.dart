import 'package:flutter/material.dart';

class CompanyChip extends StatelessWidget {
  final String companyName;
  final Color? color;

  const CompanyChip({
    super.key, 
    required this.companyName,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chipColor = color ?? theme.colorScheme.primary;
    
    return Chip(
      label: Text(
        companyName,
        style: TextStyle(
          fontSize: 12,
          color: chipColor,
        ),
      ),
      backgroundColor: chipColor.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
    );
  }
}