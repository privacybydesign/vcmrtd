// Created by Crt Vavros, copyright © 2022 ZeroPass. All rights reserved.
// NFC status display widget

import 'package:flutter/material.dart';

/// Widget to display NFC availability status
class NfcStatusWidget extends StatelessWidget {
  final bool isNfcAvailable;

  const NfcStatusWidget({Key? key, required this.isNfcAvailable}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const Text('NFC available:', style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold)),
        const SizedBox(width: 4),
        Text(isNfcAvailable ? "Yes" : "No", style: const TextStyle(fontSize: 18.0)),
      ],
    );
  }
}
