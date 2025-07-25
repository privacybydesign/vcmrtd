import 'dart:ui';

import 'package:flutter/material.dart';

@immutable
class MyTextStyles {
  final TextStyle primaryLarge;
  final TextStyle secondary;
  final TextStyle hint;
  final TextStyle error;

  const MyTextStyles({
    required this.primaryLarge,
    required this.secondary,
    required this.hint,
    required this.error,
  });
}

extension MyThemeTextStyles on ThemeData {
  MyTextStyles get defaultTextStyles => const MyTextStyles(
        primaryLarge: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Color(0xFF212121),
        ),
        secondary: TextStyle(
            fontSize: 16, fontWeight: FontWeight.w400, color: Colors.grey),
        hint: TextStyle(fontSize: 16, color: Color(0xFF666666)),
        error: TextStyle(
            fontSize: 14, color: Colors.redAccent, fontWeight: FontWeight.bold),
      );
}
