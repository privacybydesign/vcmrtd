import 'package:flutter/material.dart';

class WebBanner extends StatelessWidget {
  final sessionId;

  const WebBanner({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[50]!, Colors.blue[100]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.web, color: Colors.blue[700], size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Web Authentication Session',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[800], fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  'Session IID: $sessionId',
                  style: TextStyle(color: Colors.blue[600], fontSize: 12, fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
          Icon(Icons.check_circle, color: Colors.green[600], size: 20),
        ],
      ),
    );
  }
}
