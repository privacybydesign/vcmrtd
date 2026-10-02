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
}
