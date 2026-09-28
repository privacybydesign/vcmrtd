import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:idem/theme/brand_theme.dart';

/// Building blocks shared by the guided layout's screens (see [GuidedStyle]).

extension GuidedContext on BuildContext {
  /// The active brand's guided style, or null for the classic layout.
  GuidedStyle? get guided => brand.guided;
}

/// 44×44 round icon button used in the guided top bars.
class GuidedRoundButton extends StatelessWidget {
  const GuidedRoundButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.onDark = false,
    this.outlined = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool onDark;

  /// A thin ring instead of a filled background (the home hero's settings button).
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final g = context.guided!;
    final foreground = onDark ? Colors.white : g.ink;
    final background = outlined
        ? Colors.transparent
        : onDark
        ? Colors.white.withValues(alpha: 0.16)
        : g.buttonGrey;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: background,
        shape: CircleBorder(side: outlined ? BorderSide(color: Colors.white.withValues(alpha: 0.24)) : BorderSide.none),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(width: 44, height: 44, child: Icon(icon, size: 20, color: foreground)),
        ),
      ),
    );
  }
}

/// Top bar of a guided flow screen: a button on the left, a title or mark in
/// the middle, and an optional button on the right (kept balanced with a spacer).
class GuidedTopBar extends StatelessWidget {
  const GuidedTopBar({super.key, required this.leading, this.center, this.trailing});

  final Widget leading;
  final Widget? center;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          leading,
          Expanded(child: Center(child: center)),
          trailing ?? const SizedBox(width: 44, height: 44),
        ],
      ),
    );
  }
}

/// Title in a guided top bar.
class GuidedTopBarTitle extends StatelessWidget {
  const GuidedTopBarTitle(this.text, {super.key, this.onDark = false});

  final String text;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final g = context.guided!;
    return Text(
      text,
      style: g.heading(16, weight: FontWeight.w600, color: onDark ? Colors.white : g.ink),
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// Three-segment progress bar: scan document, read chip, selfie check.
class GuidedStepBar extends StatelessWidget {
  const GuidedStepBar({super.key, required this.step, this.onDark = false});

  /// 1-based step that's current; that many segments are filled.
  final int step;
  final bool onDark;

  static const stepCount = 3;

  @override
  Widget build(BuildContext context) {
    final g = context.guided!;
    final filled = onDark ? g.heroAccent : g.action;
    final empty = onDark ? Colors.white.withValues(alpha: 0.2) : g.border;
    return Semantics(
      label: 'Step $step of $stepCount',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Row(
          children: [
            for (var i = 1; i <= stepCount; i++) ...[
              if (i > 1) const SizedBox(width: 6),
              Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(color: i <= step ? filled : empty, borderRadius: BorderRadius.circular(2)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// "Step N of 3" over a guided heading.
class GuidedStepLabel extends StatelessWidget {
  const GuidedStepLabel({super.key, required this.step, this.onDark = false});

  final int step;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final g = context.guided!;
    return Text(
      'Step $step of ${GuidedStepBar.stepCount}',
      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: onDark ? g.stepLabelOnDark : g.stepLabel),
    );
  }
}

/// Full-width pill button in the guided primary (filled) or secondary (outlined) style.
class GuidedButton extends StatelessWidget {
  const GuidedButton({super.key, required this.label, required this.onPressed, this.icon, this.secondary = false});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool secondary;

  @override
  Widget build(BuildContext context) {
    final g = context.guided!;
    final style = (secondary ? g.secondaryButtonStyle : g.primaryButtonStyle).copyWith(
      minimumSize: const WidgetStatePropertyAll(Size.fromHeight(52)),
    );
    final child = Text(label);
    return icon == null
        ? ElevatedButton(onPressed: onPressed, style: style, child: child)
        : ElevatedButton.icon(onPressed: onPressed, style: style, icon: Icon(icon, size: 20), label: child);
  }
}

/// System bar styling for a guided screen. Guided brands run edge-to-edge
/// (see [enableGuidedEdgeToEdge]), so both bars are transparent and the
/// screen draws behind them; this only picks light or dark icons to suit
/// what is underneath: [onDark] for the status bar at the top, [bottomOnDark]
/// (defaults to [onDark]) for the navigation bar at the bottom.
class GuidedStatusBar extends StatelessWidget {
  const GuidedStatusBar({super.key, required this.onDark, this.bottomOnDark, required this.child});

  final bool onDark;
  final bool? bottomOnDark;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bottomDark = bottomOnDark ?? onDark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: onDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: onDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
        systemNavigationBarIconBrightness: bottomDark ? Brightness.light : Brightness.dark,
      ),
      child: child,
    );
  }
}

/// Lets guided screens draw behind the status and navigation bars, so dark
/// scrims and backgrounds reach the edges of the screen. Call once at start-up
/// for brands with a [GuidedStyle].
Future<void> enableGuidedEdgeToEdge() => SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

/// An outline QR glyph (three finder squares and a corner), drawn on a 24-unit grid.
class GuidedQrGlyphPainter extends CustomPainter {
  const GuidedQrGlyphPainter({this.color = Colors.white, this.strokeWidth = 1.6});

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final origin in const [Offset(3, 3), Offset(14, 3), Offset(3, 14)]) {
      canvas.drawRRect(RRect.fromRectAndRadius(origin & const Size(7, 7), const Radius.circular(1)), paint);
    }
    canvas.drawRect(const Rect.fromLTWH(14, 14, 3, 3), paint);
    canvas.drawPath(
      Path()
        ..moveTo(21, 14)
        ..lineTo(21, 21)
        ..lineTo(14, 21),
      paint,
    );
  }

  @override
  bool shouldRepaint(GuidedQrGlyphPainter old) => old.color != color || old.strokeWidth != strokeWidth;
}

/// "Save for next time" switch on the guided result screens: keeps the
/// document on this phone after sharing, so a later request can reuse it.
class GuidedSaveForNextTime extends StatelessWidget {
  const GuidedSaveForNextTime({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final g = context.guided!;
    return MergeSemantics(
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: g.subtleBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onChanged(!value),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Save for next time',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: g.ink),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Keep this document on this phone so you don’t have to scan it again.',
                        style: TextStyle(fontSize: 13, height: 1.4, color: g.bodyText),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Switch(value: value, activeTrackColor: g.action, onChanged: onChanged),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pads [child] up from the bottom edge by the navigation bar's height, so a
/// band behind it (a scrim, a sheet) reaches the very bottom of the screen
/// while its content stays clear of the bar. Uses the view padding, which
/// still reports the navigation bar where [SafeArea]'s padding may already
/// have been consumed higher up.
class GuidedBottomInset extends StatelessWidget {
  const GuidedBottomInset({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bottom = math.max(MediaQuery.viewPaddingOf(context).bottom, MediaQuery.paddingOf(context).bottom);
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: child,
    );
  }
}
