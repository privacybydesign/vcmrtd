import 'package:flutter/material.dart';

class DialogHelpers {
  static void showSuccessDialog({
    required BuildContext context,
    required String title,
    required String message,
    required VoidCallback onContinue,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.check_circle, color: Colors.green[600], size: 48),
        title: Text(title),
        content: Text(message),
        actions: [TextButton(onPressed: onContinue, child: const Text('Continue'))],
      ),
    );
  }

  static void showErrorDialog({
    required BuildContext context,
    required String title,
    required String message,
    required String error,
    VoidCallback? onRetry,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.error, color: Colors.red[600], size: 48),
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(4)),
              child: Text(error, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              const Text(
                'Please try again or make an issue in GitHub of this project.',
                style: TextStyle(fontSize: 14),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK')),
          if (onRetry != null)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onRetry();
              },
              child: const Text('Retry'),
            ),
        ],
      ),
    );
  }
}
