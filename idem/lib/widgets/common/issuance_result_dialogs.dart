import 'package:flutter/material.dart';
import 'package:idem/l10n/l10n.dart';

class DialogHelpers {
  static void showInfoDialog({required BuildContext context, required String title, required String message}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.info_outline, color: Colors.blue[600], size: 48),
        title: Text(title),
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.l10n.proofingDialogOk))],
      ),
    );
  }

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
        actions: [TextButton(onPressed: onContinue, child: Text(context.l10n.proofingContinue))],
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
              Text(context.l10n.proofingDialogRetryHint, style: const TextStyle(fontSize: 14)),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.l10n.proofingDialogOk)),
          if (onRetry != null)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onRetry();
              },
              child: Text(context.l10n.proofingRetry),
            ),
        ],
      ),
    );
  }
}
