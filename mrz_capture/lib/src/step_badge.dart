import 'package:flutter/material.dart';

/// A pill showing progress through the multi-step capture flow, e.g. "1 of 4 · Scan".
class StepBadge extends StatelessWidget {
  const StepBadge({required this.current, required this.total, required this.label, super.key});

  final int current;
  final int total;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: Colors.indigo, borderRadius: BorderRadius.circular(20)),
      child: Text(
        '$current of $total · $label',
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
      ),
    );
  }
}
