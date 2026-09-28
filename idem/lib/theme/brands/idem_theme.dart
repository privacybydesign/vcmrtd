import 'package:flutter/material.dart';
import 'package:idem/theme/brand_theme.dart';

/// The stock Idem look. [BrandTheme.idem] overrides nothing, so widgets keep
/// their built-in colours.
ThemeData idemTheme() {
  return ThemeData(
    primarySwatch: Colors.indigo,
    brightness: Brightness.light,
    textTheme: TextTheme(bodyLarge: TextStyle(fontSize: 16.0, color: Colors.black87)),
    appBarTheme: AppBarTheme(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
    extensions: const [BrandTheme.idem],
  );
}
