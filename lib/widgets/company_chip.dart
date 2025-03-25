import 'package:flutter/material.dart';

class CompanyChip extends StatelessWidget {
  final String companyName;

  const CompanyChip({super.key, required this.companyName});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(companyName),
      backgroundColor: Colors.blue.withOpacity(0.2),
      labelStyle: const TextStyle(
        color: Colors.blue,
        fontSize: 12,
      ),
    );
  }
}