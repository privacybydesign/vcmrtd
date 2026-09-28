import 'package:flutter/material.dart';
import 'package:idem/theme/brand_theme.dart';

@immutable
class MyTextStyles {
  final TextStyle primaryLarge;
  final TextStyle secondary;
  final TextStyle hint;
  final TextStyle error;

  const MyTextStyles({required this.primaryLarge, required this.secondary, required this.hint, required this.error});
}

extension MyThemeTextStyles on ThemeData {
  MyTextStyles get defaultTextStyles {
    final brand = extension<BrandTheme>() ?? BrandTheme.idem;
    return MyTextStyles(
      primaryLarge: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: brand.ink ?? const Color(0xFF212121),
        fontFamily: brand.headingFontFamily,
      ),
      secondary: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: brand.mutedText ?? Colors.grey),
      hint: TextStyle(fontSize: 16, color: brand.mutedText ?? const Color(0xFF666666)),
      error: const TextStyle(fontSize: 14, color: Colors.redAccent, fontWeight: FontWeight.bold),
    );
  }
}
