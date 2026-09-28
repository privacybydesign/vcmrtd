import 'package:flutter/material.dart';

/// Per-brand look for a white-label build, carried on [ThemeData.extensions].
///
/// Every colour and style here is an override: null means "keep the widget's
/// own default", so the stock Idem build ([BrandTheme.idem], all nulls) looks
/// exactly as it did before white-labelling existed. Widgets read it through
/// [BrandContext.brand], which falls back to [BrandTheme.idem] when no theme
/// carries one (e.g. a bare MaterialApp in a widget test).
@immutable
class BrandTheme extends ThemeExtension<BrandTheme> {
  const BrandTheme({
    required this.appBarTitle,
    this.appBarLogoAsset,
    this.markAsset,
    this.showPoweredByIdem = false,
    this.accent,
    this.success,
    this.ink,
    this.mutedText,
    this.headingFontFamily,
    this.homeBackgroundGradient,
    this.documentOptionAccent,
    this.badgeBackground,
    this.badgeForeground,
    this.proofingBannerColor,
    this.primaryButtonStyle,
    this.secondaryButtonStyle,
    this.guided,
  });

  static const idem = BrandTheme(appBarTitle: 'VCMRTD');

  /// Home app bar title; also the logo's semantic label when [appBarLogoAsset] is set.
  final String appBarTitle;

  /// Logo shown instead of [appBarTitle] on the (dark) home app bar.
  final String? appBarLogoAsset;

  /// Square brand mark, shown in the home header instead of the generic scanner icon.
  final String? markAsset;

  /// Adds a "Powered by Idem" line to the home screen.
  final bool showPoweredByIdem;

  /// Highlight colour for interactive and in-progress states (NFC waiting, links).
  final Color? accent;

  /// Colour for completed and verified states.
  final Color? success;

  /// Primary text colour.
  final Color? ink;

  /// Secondary text colour.
  final Color? mutedText;

  /// Font family for headings; body text takes the theme's default family.
  final String? headingFontFamily;

  /// Top-to-bottom gradient behind the home screen.
  final List<Color>? homeBackgroundGradient;

  /// Icon colour for every option card on the home screen.
  final Color? documentOptionAccent;

  final Color? badgeBackground;
  final Color? badgeForeground;

  /// Strip under the home app bar while a proofing session is connected.
  final Color? proofingBannerColor;

  /// Style for the main call-to-action buttons (continue, submit, start).
  final ButtonStyle? primaryButtonStyle;

  /// Style for the alternative action next to a primary one (decline).
  final ButtonStyle? secondaryButtonStyle;

  /// When set, screens use the guided layout (dark hero, step progress, flat
  /// bordered cards) instead of the classic Idem layout.
  final GuidedStyle? guided;

  @override
  BrandTheme copyWith() => this;

  @override
  BrandTheme lerp(covariant BrandTheme? other, double t) => t < 0.5 || other == null ? this : other;
}

extension BrandContext on BuildContext {
  BrandTheme get brand => Theme.of(this).extension<BrandTheme>() ?? BrandTheme.idem;
}

/// Palette and assets for the guided layout. Only brands that opt into that
/// layout provide one, so it has no defaults.
@immutable
class GuidedStyle {
  const GuidedStyle({
    required this.logoOnDarkAsset,
    required this.markAsset,
    required this.headingFontFamily,
    required this.ink,
    required this.slate,
    required this.bodyText,
    required this.muted,
    required this.placeholder,
    required this.border,
    required this.subtleBorder,
    required this.surface,
    required this.neutralTile,
    required this.buttonGrey,
    required this.heroMuted,
    required this.heroEyebrow,
    required this.heroAccent,
    required this.action,
    required this.actionTint,
    required this.actionTintStrong,
    required this.stepLabel,
    required this.stepLabelOnDark,
    required this.badgeBackground,
    required this.illustrationDocument,
    required this.success,
    required this.successBright,
    required this.successTint,
    required this.successText,
    required this.primaryButtonStyle,
    required this.secondaryButtonStyle,
  });

  final String logoOnDarkAsset;
  final String markAsset;
  final String headingFontFamily;

  /// Primary text, and the background of dark (hero and camera) areas.
  final Color ink;
  final Color slate;
  final Color bodyText;
  final Color muted;
  final Color placeholder;
  final Color border;
  final Color subtleBorder;
  final Color surface;
  final Color neutralTile;
  final Color buttonGrey;

  /// Secondary text on dark areas.
  final Color heroMuted;
  final Color heroEyebrow;

  /// Highlight on dark areas (step numbers, progress).
  final Color heroAccent;

  final Color action;
  final Color actionTint;
  final Color actionTintStrong;
  final Color stepLabel;
  final Color stepLabelOnDark;
  final Color badgeBackground;

  /// Document colour in the guided illustrations.
  final Color illustrationDocument;
  final Color success;

  /// Success on dark areas.
  final Color successBright;
  final Color successTint;
  final Color successText;

  final ButtonStyle primaryButtonStyle;
  final ButtonStyle secondaryButtonStyle;

  TextStyle heading(double size, {FontWeight weight = FontWeight.w700, Color? color, double height = 1.2}) =>
      TextStyle(fontFamily: headingFontFamily, fontSize: size, fontWeight: weight, color: color ?? ink, height: height);
}
