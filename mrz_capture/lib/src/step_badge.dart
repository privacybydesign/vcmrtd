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

/// The back button + [StepBadge] combination shown at the top of every
/// screen in the multi-step capture flow: a fixed-height row with the back
/// button pinned to the left and the badge centered over it.
class StepBadgeTopBar extends StatelessWidget {
  const StepBadgeTopBar({
    required this.icon,
    required this.onBack,
    required this.current,
    required this.total,
    required this.label,
    this.tooltip,
    super.key,
  });

  final IconData icon;
  final VoidCallback onBack;
  final int current;
  final int total;
  final String label;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(tooltip: tooltip, icon: Icon(icon), onPressed: onBack),
          ),
          StepBadge(current: current, total: total, label: label),
        ],
      ),
    );
  }
}
