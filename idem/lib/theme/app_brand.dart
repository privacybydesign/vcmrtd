import 'package:flutter/material.dart';
import 'package:idem/theme/brands/cm_theme.dart';
import 'package:idem/theme/brands/idem_theme.dart';

/// The brand a build is dressed in, chosen at compile time:
///
///     flutter run --dart-define=BRAND=cm
///
/// Without the define the app is the stock Idem build.
enum AppBrand {
  idem,
  cm;

  static AppBrand get current => fromName(const String.fromEnvironment('BRAND', defaultValue: 'idem'));

  /// Throws on an unknown name, so a typo in the build command fails loudly
  /// instead of silently shipping the default brand.
  static AppBrand fromName(String name) {
    final normalized = name.trim().toLowerCase();
    for (final brand in values) {
      if (brand.name == normalized) return brand;
    }
    throw ArgumentError.value(name, 'BRAND', 'Unknown brand; expected one of ${values.map((b) => b.name).join(', ')}');
  }

  ThemeData get theme => switch (this) {
    AppBrand.idem => idemTheme(),
    AppBrand.cm => cmTheme(),
  };
}
