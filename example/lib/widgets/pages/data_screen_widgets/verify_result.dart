import 'package:flutter/material.dart';
import 'package:vcmrtdapp/widgets/pages/data_screen_widgets/read_only_textbox.dart';

class VerifyResultSection extends StatelessWidget {
  final bool isExpired;
  final bool authenticChip;
  final bool authenticContent;

  const VerifyResultSection({
    super.key,
    required this.isExpired,
    required this.authenticChip,
    required this.authenticContent,
  });

  @override
  Widget build(BuildContext context) {
    String yn(bool? v) => v == null ? '-' : (v ? 'Yes' : 'No');

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.assignment_turned_in,
                    color: Colors.teal[700], size: 28),
                const SizedBox(width: 8),
                Text(
                  'Verification Result',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.teal[700],
                      ),
                ),
              ],
            ),
            const Divider(height: 30),
            ReadOnlyTextBox(
              label: 'Expired Document',
              value: yn(isExpired),
              isError: false,
            ),
            const SizedBox(height: 12),
            ReadOnlyTextBox(
              label: 'Authentic Chip',
              value: yn(authenticChip),
              isError: false,
            ),
            const SizedBox(height: 12),
            ReadOnlyTextBox(
              label: 'Authentic Content',
              value: yn(authenticContent),
              isError: false,
            ),
          ],
        ),
      ),
    );
  }
}
