import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:idem/services/proofing_session_client.dart';
import 'package:idem/theme/brand_theme.dart';

/// Whose app this looks like: a name, a logo and a theme. Idem's own until a
/// session brings the branding of the org (or the org's customer) that asked
/// for it ([AppBranding.fromSession]), so the app looks like theirs. Every
/// colour or font left null keeps the design's own.
@immutable
class AppBranding {
  const AppBranding({
    required this.name,
    required this.primary,
    required this.secondary,
    this.text,
    this.surface,
    this.border,
    this.link,
    this.success,
    this.error,
    this.header,
    this.font = AppFont.design,
    this.logo,
  });

  /// Idem's own look, used until a session supplies another one.
  static const idem = AppBranding(name: 'Idem', primary: Color(0xFF3949AB), secondary: Color(0xFF546E7A));

  /// [branding] as the app shows it, with [logo] its logo's bytes.
  factory AppBranding.fromSession(ProofingBranding branding, {Uint8List? logo}) {
    final header = parseHexColor(branding.headerColor);
    return AppBranding(
      name: branding.name,
      primary: parseHexColor(branding.primaryColor) ?? idem.primary,
      secondary: parseHexColor(branding.secondaryColor) ?? idem.secondary,
      text: parseHexColor(branding.textColor),
      surface: parseHexColor(branding.surfaceColor),
      border: parseHexColor(branding.borderColor),
      link: parseHexColor(branding.linkColor),
      success: parseHexColor(branding.successColor),
      error: parseHexColor(branding.errorColor),
      // The header carries white text: one too light for it keeps the design's.
      header: header != null && contrastRatio(header, Colors.white) >= _minHeaderContrast ? header : null,
      font: AppFont.fromCss(branding.fontFamily),
      logo: logo == null ? null : MemoryImage(logo),
    );
  }

  /// Shown as a wordmark when there is no [logo].
  final String name;

  /// Buttons, links and progress.
  final Color primary;

  /// Step labels, badges and illustrations.
  final Color secondary;

  final Color? text;

  /// Screen background.
  final Color? surface;
  final Color? border;
  final Color? link;
  final Color? success;
  final Color? error;

  /// The dark top of the screens (home hero, card headers, camera screens).
  final Color? header;
  final AppFont font;

  /// Square mark, drawn on light and dark backgrounds alike.
  final ImageProvider? logo;
}

/// Large text on the header needs 3:1 (WCAG AA for large text).
const _minHeaderContrast = 3.0;

/// The fonts the app draws with: the design's own pair, one the app bundles,
/// or the platform's own when a theme names only system fonts.
@immutable
class AppFont {
  const AppFont._(this.heading, this.body);

  static const design = AppFont._(AppFonts.heading, AppFonts.body);

  /// The platform's default font for everything.
  static const platform = AppFont._(null, null);

  /// The families the app bundles that a theme may name.
  static const _bundled = {'alexandria': 'Alexandria', 'montserrat': 'Montserrat', 'nunito': 'Nunito'};

  /// A theme's CSS font-family list as the app can draw it: the first family
  /// it bundles, else the platform's font; an empty list keeps the design's.
  factory AppFont.fromCss(String? css) {
    if (css == null || css.trim().isEmpty) return design;
    for (final family in css.split(',')) {
      final bundled = _bundled[family.trim().replaceAll(RegExp('["\']'), '').toLowerCase()];
      if (bundled != null) return AppFont._(bundled, bundled);
    }
    return platform;
  }

  /// Null means the platform's default.
  final String? heading;
  final String? body;
}

/// `#rrggbb` as a colour; null for null or anything else.
Color? parseHexColor(String? hex) {
  if (hex == null || !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(hex)) return null;
  return Color(0xFF000000 | int.parse(hex.substring(1), radix: 16));
}

/// WCAG contrast ratio between [a] and [b], from 1 to 21.
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (la > lb ? la + 0.05 : lb + 0.05) / (la > lb ? lb + 0.05 : la + 0.05);
}

/// The design's own neutrals; a theme replaces each it sets.
abstract final class AppColors {
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
  static const heroMuted = Color(0xFFD6D9DD);

  static const success = Color(0xFF2A9066);
  static const successBright = Color(0xFF3DDC97);
  static const successTint = Color(0xFFE9F9F1);
  static const successText = Color(0xFF1F6B4C);
  static const error = Color(0xFFD1293D);
}

abstract final class AppFonts {
  static const heading = 'Montserrat';
  static const body = 'Nunito';
}

/// [color] mixed towards white by [amount] (0 = unchanged, 1 = white).
Color _lighten(Color color, double amount) => Color.lerp(color, Colors.white, amount)!;

/// [color] mixed towards black by [amount].
Color _darken(Color color, double amount) => Color.lerp(color, Colors.black, amount)!;

/// White or ink, whichever reads better on [background].
Color _readableOn(Color background) =>
    contrastRatio(background, Colors.white) >= contrastRatio(background, AppColors.ink) ? Colors.white : AppColors.ink;

TextStyle _buttonText(AppFont font) => TextStyle(fontFamily: font.body, fontWeight: FontWeight.w700, fontSize: 16);

BrandTheme brandThemeFor(AppBranding branding) {
  final primary = branding.primary;
  final secondary = branding.secondary;
  final ink = branding.text ?? AppColors.ink;
  final header = branding.header ?? AppColors.ink;
  final surface = branding.surface ?? AppColors.surface;
  final border = branding.border ?? AppColors.border;
  final success = branding.success ?? AppColors.success;
  final buttonText = _buttonText(branding.font);
  // Secondary text and greys follow the text colour, so a themed one still matches.
  final bodyText = branding.text == null ? AppColors.bodyText : Color.lerp(ink, Colors.white, 0.15)!;
  final muted = branding.text == null ? AppColors.muted : Color.lerp(ink, Colors.white, 0.4)!;

  final primaryButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: primary,
    foregroundColor: _readableOn(primary),
    disabledBackgroundColor: border,
    disabledForegroundColor: muted,
    elevation: 0,
    minimumSize: const Size(64, 52),
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
    shape: const StadiumBorder(),
    textStyle: buttonText,
  );

  final secondaryButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: Colors.white,
    foregroundColor: ink,
    elevation: 0,
    minimumSize: const Size(64, 52),
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
    shape: const StadiumBorder(),
    side: BorderSide(color: ink, width: 2),
    textStyle: buttonText,
  );

  final badgeBackground = _lighten(secondary, 0.9);

  return BrandTheme(
    name: branding.name,
    logo: branding.logo,
    accent: branding.link ?? primary,
    success: success,
    ink: ink,
    mutedText: bodyText,
    headingFontFamily: branding.font.heading,
    homeBackgroundGradient: [header, surface],
    documentOptionAccent: primary,
    badgeBackground: badgeBackground,
    badgeForeground: secondary,
    proofingBannerColor: secondary,
    primaryButtonStyle: primaryButtonStyle,
    secondaryButtonStyle: secondaryButtonStyle,
    guided: GuidedStyle(
      headingFontFamily: branding.font.heading,
      ink: ink,
      header: header,
      slate: branding.text == null ? AppColors.slate : ink,
      bodyText: bodyText,
      muted: muted,
      placeholder: branding.text == null ? AppColors.placeholder : Color.lerp(ink, Colors.white, 0.65)!,
      border: branding.border == null ? AppColors.cardBorder : _darken(border, 0.08),
      subtleBorder: border,
      surface: surface,
      neutralTile: AppColors.neutralTile,
      buttonGrey: AppColors.buttonGrey,
      heroMuted: AppColors.heroMuted,
      heroEyebrow: _lighten(primary, 0.6),
      heroAccent: _lighten(primary, 0.3),
      action: primary,
      actionTint: _lighten(primary, 0.9),
      actionTintStrong: _lighten(primary, 0.8),
      stepLabel: secondary,
      stepLabelOnDark: _lighten(secondary, 0.6),
      badgeBackground: badgeBackground,
      illustrationDocument: _darken(secondary, 0.4),
      success: success,
      successBright: branding.success == null ? AppColors.successBright : _lighten(success, 0.3),
      successTint: branding.success == null ? AppColors.successTint : _lighten(success, 0.9),
      successText: branding.success == null ? AppColors.successText : _darken(success, 0.25),
      error: branding.error ?? AppColors.error,
      primaryButtonStyle: primaryButtonStyle,
      secondaryButtonStyle: secondaryButtonStyle,
    ),
  );
}

ThemeData appTheme([AppBranding branding = AppBranding.idem]) {
  final brand = brandThemeFor(branding);
  final guided = brand.guided!;
  final font = branding.font;
  final buttonText = _buttonText(font);
  final colorScheme = ColorScheme.fromSeed(seedColor: branding.primary).copyWith(
    primary: branding.primary,
    onPrimary: _readableOn(branding.primary),
    secondary: branding.secondary,
    onSecondary: _readableOn(branding.secondary),
    surface: Colors.white,
    onSurface: guided.ink,
    error: guided.error,
  );
  final base = ThemeData(colorScheme: colorScheme, fontFamily: font.body);
  final bodyText = base.textTheme.apply(bodyColor: guided.ink, displayColor: guided.ink);
  TextStyle? heading(TextStyle? style, FontWeight weight) =>
      style?.copyWith(fontFamily: font.heading, fontWeight: weight);

  return base.copyWith(
    scaffoldBackgroundColor: guided.surface,
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
    appBarTheme: AppBarTheme(
      backgroundColor: guided.header,
      foregroundColor: Colors.white,
      elevation: 0,
      titleTextStyle: TextStyle(fontFamily: font.heading, fontWeight: FontWeight.w600, fontSize: 18, color: Colors.white),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(style: brand.primaryButtonStyle),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: guided.ink,
        minimumSize: const Size(64, 52),
        shape: const StadiumBorder(),
        side: BorderSide(color: guided.ink, width: 2),
        textStyle: buttonText,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: branding.link ?? branding.primary, textStyle: buttonText),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: guided.subtleBorder),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: branding.primary),
    extensions: [brand],
  );
}
