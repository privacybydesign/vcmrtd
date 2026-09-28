// Created by Crt Vavros, copyright © 2022 ZeroPass. All rights reserved.
// NFC status display widget

import 'package:flutter/material.dart';
import 'package:idem/l10n/l10n.dart';

/// Widget to display NFC availability status
class NfcStatusWidget extends StatelessWidget {
  final bool isNfcAvailable;

  const NfcStatusWidget({super.key, required this.isNfcAvailable});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Text(context.l10n.nfcAvailableLabel, style: const TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold)),
        const SizedBox(width: 4),
        Text(isNfcAvailable ? context.l10n.commonYes : context.l10n.commonNo, style: const TextStyle(fontSize: 18.0)),
      ],
    );
  }
}
