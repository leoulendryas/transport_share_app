// lib/widgets/participants_chip.dart
import 'package:flutter/material.dart';

class ParticipantsChip extends StatelessWidget {
  final int count;
  final VoidCallback onPressed;

  const ParticipantsChip({
    super.key,
    required this.count,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: CircleAvatar(
        child: Text(count.toString()),
      ),
      label: const Text('Participants'),
      onPressed: onPressed,
    );
  }
}