// Created by Crt Vavros, copyright © 2022 ZeroPass. All rights reserved.
// Alert message display widget

import 'package:flutter/material.dart';

/// Widget to display alert messages
class AlertMessageWidget extends StatelessWidget {
  final String message;

  const AlertMessageWidget({Key? key, required this.message}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 15.0, fontWeight: FontWeight.bold),
    );
  }
}
