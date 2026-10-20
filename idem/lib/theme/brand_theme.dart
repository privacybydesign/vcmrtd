import 'package:flutter/material.dart';
import 'package:idem/theme/app_theme.dart';

/// Per-brand look, carried on [ThemeData.extensions] and built by
/// [brandThemeFor].
///
/// Widgets read it through [BrandContext.brand], which falls back to Idem's
/// own look when no theme carries one (e.g. a bare MaterialApp in a widget
/// test).
@immutable
class BrandTheme extends ThemeExtension<BrandTheme> {
  const BrandTheme({required this.name, this.logo, required this.guided});

  /// Idem's own look, for when no theme carries one.
  static final idem = brandThemeFor(AppBranding.idem);

  /// The brand's name: the home app bar title, the wordmark when there is no
  /// [logo], and the logo's semantic label when there is.
  final String name;

  /// Square brand mark; see [BrandMark].
  final ImageProvider? logo;

  /// The guided layout's palette (dark hero, step progress, flat bordered cards).
  final GuidedStyle guided;

  @override
  BrandTheme copyWith() => this;

  @override
  BrandTheme lerp(covariant BrandTheme? other, double t) => t < 0.5 || other == null ? this : other;
}

extension BrandContext on BuildContext {
  BrandTheme get brand => Theme.of(this).extension<BrandTheme>() ?? BrandTheme.idem;
}

/// Palette for the guided layout, derived from a brand's colours by
/// [brandThemeFor], so it has no defaults.
@immutable
class GuidedStyle {
  const GuidedStyle({
    required this.headingFontFamily,
    required this.ink,
    required this.header,
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
    required this.error,
    required this.primaryButtonStyle,
    required this.secondaryButtonStyle,
    required this.heroButtonStyle,
  });

  /// Null is the platform's default font.
  final String? headingFontFamily;

  /// Primary text.
  final Color ink;

  /// The background of dark areas: the home hero, card headers and camera
  /// screens. Always dark enough for white text.
  final Color header;
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

  /// Errors and failed states.
  final Color error;

  final ButtonStyle primaryButtonStyle;
  final ButtonStyle secondaryButtonStyle;

  /// The main action on the dark header (the home hero's Scan QR code):
  /// [primaryButtonStyle], unless the primary is too close to [header].
  final ButtonStyle heroButtonStyle;

  TextStyle heading(double size, {FontWeight weight = FontWeight.w700, Color? color, double height = 1.2}) =>
      TextStyle(fontFamily: headingFontFamily, fontSize: size, fontWeight: weight, color: color ?? ink, height: height);
}

/// What a widget is drawn on, so its text and icons read on it.
enum Backdrop { light, dark }
