import 'package:flutter/material.dart';
import 'package:idem/theme/brand_theme.dart';

/// CM.com palette, taken from the cm.com stylesheets.
abstract final class CmColors {
  static const ink = Color(0xFF101E1E);
  static const slate = Color(0xFF212E39);
  static const bodyText = Color(0xFF344055);
  static const muted = Color(0xFF6F7786);
  static const placeholder = Color(0xFFAEB3BB);
  static const buttonGrey = Color(0xFFF5F5F6);
  static const neutralTile = Color(0xFFEAEBEE);
  static const cardBorder = Color(0xFFD6D9DD);
  static const border = Color(0xFFEAEBEE);
  static const surface = Color(0xFFFBFBFC);

  /// CM's brand blue. Too light for white text (under 4.5:1), so filled
  /// buttons use [action] instead.
  static const brandBlue = Color(0xFF007FFF);
  static const action = Color(0xFF036BD2);
  static const blueTint = Color(0xFFE5F2FF);
  static const blueTintStrong = Color(0xFFCCE5FF);
  static const heroBlue = Color(0xFF33A0FF);
  static const heroEyebrow = Color(0xFF99CCFF);
  static const heroMuted = Color(0xFFD6D9DD);

  static const purple = Color(0xFF5412C7);
  static const purpleTint = Color(0xFFF0E8FE);
  static const purpleOnDark = Color(0xFFC29FFA);
  static const navy = Color(0xFF13156A);

  static const success = Color(0xFF2A9066);
  static const successBright = Color(0xFF3DDC97);
  static const successTint = Color(0xFFE9F9F1);
  static const successText = Color(0xFF1F6B4C);
}

abstract final class CmFonts {
  static const heading = 'Montserrat';
  static const body = 'Nunito';
}

const _buttonText = TextStyle(fontFamily: CmFonts.body, fontWeight: FontWeight.w700, fontSize: 16);

final _primaryButtonStyle = ElevatedButton.styleFrom(
  backgroundColor: CmColors.action,
  foregroundColor: Colors.white,
  disabledBackgroundColor: CmColors.border,
  disabledForegroundColor: CmColors.muted,
  elevation: 0,
  minimumSize: const Size(64, 52),
  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
  shape: const StadiumBorder(),
  textStyle: _buttonText,
);

final _secondaryButtonStyle = ElevatedButton.styleFrom(
  backgroundColor: Colors.white,
  foregroundColor: CmColors.slate,
  elevation: 0,
  minimumSize: const Size(64, 52),
  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
  shape: const StadiumBorder(),
  side: const BorderSide(color: CmColors.slate, width: 2),
  textStyle: _buttonText,
);

final cmBrandTheme = BrandTheme(
  appBarTitle: 'CM.com',
  appBarLogoAsset: 'assets/brands/cm/logo_horizontal_white.png',
  markAsset: 'assets/brands/cm/mark.png',
  showPoweredByIdem: true,
  accent: CmColors.action,
  success: CmColors.success,
  ink: CmColors.ink,
  mutedText: CmColors.bodyText,
  headingFontFamily: CmFonts.heading,
  homeBackgroundGradient: const [CmColors.ink, CmColors.surface],
  documentOptionAccent: CmColors.action,
  badgeBackground: CmColors.purpleTint,
  badgeForeground: CmColors.purple,
  proofingBannerColor: CmColors.purple,
  primaryButtonStyle: _primaryButtonStyle,
  secondaryButtonStyle: _secondaryButtonStyle,
  guided: GuidedStyle(
    logoOnDarkAsset: 'assets/brands/cm/logo_horizontal_white.png',
    markAsset: 'assets/brands/cm/mark.png',
    headingFontFamily: CmFonts.heading,
    ink: CmColors.ink,
    slate: CmColors.slate,
    bodyText: CmColors.bodyText,
    muted: CmColors.muted,
    placeholder: CmColors.placeholder,
    border: CmColors.cardBorder,
    subtleBorder: CmColors.border,
    surface: CmColors.surface,
    neutralTile: CmColors.neutralTile,
    buttonGrey: CmColors.buttonGrey,
    heroMuted: CmColors.heroMuted,
    heroEyebrow: CmColors.heroEyebrow,
    heroAccent: CmColors.heroBlue,
    action: CmColors.action,
    actionTint: CmColors.blueTint,
    actionTintStrong: CmColors.blueTintStrong,
    stepLabel: CmColors.purple,
    stepLabelOnDark: CmColors.purpleOnDark,
    badgeBackground: CmColors.purpleTint,
    illustrationDocument: CmColors.navy,
    success: CmColors.success,
    successBright: CmColors.successBright,
    successTint: CmColors.successTint,
    successText: CmColors.successText,
    primaryButtonStyle: _primaryButtonStyle,
    secondaryButtonStyle: _secondaryButtonStyle,
  ),
);

ThemeData cmTheme() {
  final colorScheme = ColorScheme.fromSeed(seedColor: CmColors.action).copyWith(
    primary: CmColors.action,
    onPrimary: Colors.white,
    secondary: CmColors.purple,
    onSecondary: Colors.white,
    surface: Colors.white,
    onSurface: CmColors.ink,
  );
  final base = ThemeData(colorScheme: colorScheme, fontFamily: CmFonts.body);
  final bodyText = base.textTheme.apply(bodyColor: CmColors.ink, displayColor: CmColors.ink);
  TextStyle? heading(TextStyle? style, FontWeight weight) =>
      style?.copyWith(fontFamily: CmFonts.heading, fontWeight: weight);

  return base.copyWith(
    scaffoldBackgroundColor: CmColors.surface,
    textTheme: bodyText.copyWith(
      displayLarge: heading(bodyText.displayLarge, FontWeight.w700),
      displayMedium: heading(bodyText.displayMedium, FontWeight.w700),
      displaySmall: heading(bodyText.displaySmall, FontWeight.w700),
      headlineLarge: heading(bodyText.headlineLarge, FontWeight.w700),
      headlineMedium: heading(bodyText.headlineMedium, FontWeight.w700),
      headlineSmall: heading(bodyText.headlineSmall, FontWeight.w700),
      titleLarge: heading(bodyText.titleLarge, FontWeight.w600),
      titleMedium: heading(bodyText.titleMedium, FontWeight.w600),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: CmColors.ink,
      foregroundColor: Colors.white,
      elevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: CmFonts.heading,
        fontWeight: FontWeight.w600,
        fontSize: 18,
        color: Colors.white,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(style: _primaryButtonStyle),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: CmColors.slate,
        minimumSize: const Size(64, 52),
        shape: const StadiumBorder(),
        side: const BorderSide(color: CmColors.slate, width: 2),
        textStyle: _buttonText,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: CmColors.action, textStyle: _buttonText),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: CmColors.border),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: CmColors.action),
    extensions: [cmBrandTheme],
  );
}
