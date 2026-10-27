import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:idem/l10n/l10n.dart';
import 'package:idem/theme/brand_theme.dart';

/// Building blocks shared by the guided layout's screens (see [GuidedStyle]).

/// Around the button(s) at the bottom of a guided screen.
const guidedBottomButtonPadding = EdgeInsets.fromLTRB(20, 0, 20, 28);

extension GuidedContext on BuildContext {
  GuidedStyle get guided => brand.guided;
}

const _roundButtonSize = 44.0;

/// 44×44 round icon button used in the guided top bars.
class GuidedRoundButton extends StatelessWidget {
  const GuidedRoundButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.backdrop = Backdrop.light,
    this.fill = GuidedRoundButtonFill.filled,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Backdrop backdrop;
  final GuidedRoundButtonFill fill;

  @override
  Widget build(BuildContext context) {
    final g = context.guided;
    final onDark = backdrop == Backdrop.dark;
    final outlined = fill == GuidedRoundButtonFill.outlined;
    final foreground = onDark ? Colors.white : g.ink;
    final background = outlined
        ? Colors.transparent
        : onDark
        ? Colors.white.withValues(alpha: 0.16)
        : g.buttonGrey;
    return Semantics(
      button: true,
      enabled: onPressed != null,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: background,
          shape: CircleBorder(
            side: outlined ? BorderSide(color: Colors.white.withValues(alpha: 0.24)) : BorderSide.none,
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: SizedBox.square(
              dimension: _roundButtonSize,
              child: Icon(icon, size: 20, color: foreground),
            ),
          ),
        ),
      ),
    );
  }
}

enum GuidedRoundButtonFill {
  filled,

  /// A thin ring instead of a filled background (the home hero's settings button).
  outlined,
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
          trailing ?? const SizedBox.square(dimension: _roundButtonSize),
        ],
      ),
    );
  }
}

/// Title in a guided top bar.
class GuidedTopBarTitle extends StatelessWidget {
  const GuidedTopBarTitle(this.text, {super.key, this.backdrop = Backdrop.light});

  final String text;
  final Backdrop backdrop;

  @override
  Widget build(BuildContext context) {
    final g = context.guided;
    return GuidedHeading(
      text,
      style: g.heading(16, weight: FontWeight.w600, color: backdrop == Backdrop.dark ? Colors.white : g.ink),
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// A title screen readers can jump to as a heading.
class GuidedHeading extends StatelessWidget {
  const GuidedHeading(this.text, {super.key, required this.style, this.textAlign, this.overflow});

  final String text;
  final TextStyle style;
  final TextAlign? textAlign;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(text, style: style, textAlign: textAlign, overflow: overflow),
    );
  }
}

/// Progress bar with a segment per step of the flow ([FlowStepPlan]).
class GuidedStepBar extends StatelessWidget {
  const GuidedStepBar({super.key, required this.step, required this.total, this.backdrop = Backdrop.light});

  /// 1-based step that's current; that many segments are filled.
  final int step;
  final int total;
  final Backdrop backdrop;

  @override
  Widget build(BuildContext context) {
    final g = context.guided;
    final onDark = backdrop == Backdrop.dark;
    final filled = onDark ? g.heroAccent : g.action;
    final empty = onDark ? Colors.white.withValues(alpha: 0.2) : g.border;
    return Semantics(
      label: context.l10n.guidedStepOf(step, total),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Row(
          children: [
            for (var i = 1; i <= total; i++) ...[
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

/// "Step N of M" over a guided heading.
class GuidedStepLabel extends StatelessWidget {
  const GuidedStepLabel({super.key, required this.step, required this.total, this.backdrop = Backdrop.light});

  final int step;
  final int total;
  final Backdrop backdrop;

  @override
  Widget build(BuildContext context) {
    final g = context.guided;
    return Text(
      context.l10n.guidedStepOf(step, total),
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: backdrop == Backdrop.dark ? g.stepLabelOnDark : g.stepLabel,
      ),
    );
  }
}

/// Full-width pill button in the guided primary (filled) or secondary (outlined) style.
class GuidedButton extends StatelessWidget {
  const GuidedButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.kind = GuidedButtonKind.primary,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final GuidedButtonKind kind;

  @override
  Widget build(BuildContext context) {
    final g = context.guided;
    final style = switch (kind) {
      GuidedButtonKind.primary => g.primaryButtonStyle,
      GuidedButtonKind.secondary => g.secondaryButtonStyle,
    }.copyWith(minimumSize: const WidgetStatePropertyAll(Size.fromHeight(52)));
    final child = Text(label);
    return icon == null
        ? ElevatedButton(onPressed: onPressed, style: style, child: child)
        : ElevatedButton.icon(onPressed: onPressed, style: style, icon: Icon(icon, size: 20), label: child);
  }
}

enum GuidedButtonKind { primary, secondary }

/// System bar styling for a guided screen. Guided brands run edge-to-edge
/// (see [enableGuidedEdgeToEdge]), so both bars are transparent and the
/// screen draws behind them; this only picks light or dark icons to suit
/// what is underneath: [backdrop] for the status bar at the top,
/// [bottomBackdrop] (defaults to [backdrop]) for the navigation bar at the
/// bottom.
class GuidedStatusBar extends StatelessWidget {
  const GuidedStatusBar({super.key, required this.backdrop, this.bottomBackdrop, required this.child});

  final Backdrop backdrop;
  final Backdrop? bottomBackdrop;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final onDark = backdrop == Backdrop.dark;
    final bottomDark = (bottomBackdrop ?? backdrop) == Backdrop.dark;
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
    final g = context.guided;
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
                        context.l10n.guidedSaveForNextTime,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: g.ink),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.l10n.guidedSaveForNextTimeSubtitle,
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

/// A camera screen's scrim with a cut-out for the document at [frame], white
/// corners around it, and with [mrzLines] the zone they're read from.
class GuidedScanFramePainter extends CustomPainter {
  GuidedScanFramePainter({required this.frame, this.mrzLines = 0, required this.scrim, required this.highlight});

  final Rect frame;
  final int mrzLines;
  final Color scrim;
  final Color highlight;

  static const _radius = 16.0;
  static const _cornerLength = 28.0;

  @override
  void paint(Canvas canvas, Size size) {
    final cutout = RRect.fromRectAndRadius(frame, const Radius.circular(_radius));
    canvas.drawPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(Offset.zero & size)
        ..addRRect(cutout),
      Paint()..color = scrim,
    );

    final corner = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    const r = Radius.circular(_radius);
    final l = frame.left, t = frame.top, rt = frame.right, b = frame.bottom;
    canvas.drawPath(
      Path()
        ..moveTo(l, t + _cornerLength)
        ..lineTo(l, t + _radius)
        ..arcToPoint(Offset(l + _radius, t), radius: r)
        ..lineTo(l + _cornerLength, t)
        ..moveTo(rt - _cornerLength, t)
        ..lineTo(rt - _radius, t)
        ..arcToPoint(Offset(rt, t + _radius), radius: r)
        ..lineTo(rt, t + _cornerLength)
        ..moveTo(rt, b - _cornerLength)
        ..lineTo(rt, b - _radius)
        ..arcToPoint(Offset(rt - _radius, b), radius: r)
        ..lineTo(rt - _cornerLength, b)
        ..moveTo(l + _cornerLength, b)
        ..lineTo(l + _radius, b)
        ..arcToPoint(Offset(l, b - _radius), radius: r)
        ..lineTo(l, b - _cornerLength),
      corner,
    );
    if (mrzLines == 0) return;

    // The machine-readable lines sit along the bottom of every supported document.
    final inset = frame.width * 0.044;
    final zoneHeight = frame.height * (0.08 + 0.08 * mrzLines);
    final zone = RRect.fromRectAndRadius(
      Rect.fromLTRB(
        frame.left + inset,
        frame.bottom - frame.height * 0.08 - zoneHeight,
        frame.right - inset,
        frame.bottom - frame.height * 0.08,
      ),
      const Radius.circular(10),
    );
    canvas.drawRRect(zone, Paint()..color = highlight.withValues(alpha: 0.12));
    canvas.drawRRect(
      zone,
      Paint()
        ..color = highlight
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(GuidedScanFramePainter old) =>
      old.frame != frame || old.mrzLines != mrzLines || old.scrim != scrim || old.highlight != highlight;
}

/// The white sheet under a camera screen's frame: [label] and [title], and
/// [footer] when given, with [tip] behind a tap (or swipe up) so the sheet
/// stays clear of the frame on smaller phones.
class GuidedSheet extends StatefulWidget {
  const GuidedSheet({
    super.key,
    required this.label,
    required this.title,
    required this.tip,
    required this.showTip,
    required this.hideTip,
    this.notice,
    this.footer,
  });

  final Widget label;
  final String title;
  final Widget tip;

  /// Shown under the title, open or closed.
  final Widget? notice;

  /// What tapping the closed or the open sheet does, for screen readers.
  final String showTip;
  final String hideTip;

  final Widget? footer;

  @override
  State<GuidedSheet> createState() => _GuidedSheetState();
}

class _GuidedSheetState extends State<GuidedSheet> {
  static const _duration = Duration(milliseconds: 280);

  bool _expanded = false;

  /// Stays true while the tip collapses, so it shrinks with its content.
  bool _tipMounted = false;

  void _expand() {
    if (_expanded) return;

    setState(() {
      _expanded = true;
      _tipMounted = true;
    });
  }

  void _collapse() {
    if (_expanded) setState(() => _expanded = false);
  }

  @override
  Widget build(BuildContext context) {
    final g = context.guided;
    final notice = widget.notice;
    final footer = widget.footer;
    return GestureDetector(
      onVerticalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity < -100) _expand();
        if (velocity > 100) _collapse();
      },
      child: Material(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                button: true,
                expanded: _expanded,
                hint: _expanded ? widget.hideTip : widget.showTip,
                child: InkWell(
                  onTap: _expanded ? _collapse : _expand,
                  // The arrow turning is the feedback; a highlight greys half the card.
                  splashFactory: NoSplash.splashFactory,
                  highlightColor: Colors.transparent,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(color: g.border, borderRadius: BorderRadius.circular(2)),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  widget.label,
                                  const SizedBox(height: 4),
                                  GuidedHeading(widget.title, style: g.heading(18, height: 1.3)),
                                  if (notice != null) ...[const SizedBox(height: 4), notice],
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            AnimatedRotation(
                              turns: _expanded ? 0.5 : 0,
                              duration: _duration,
                              curve: Curves.easeOutCubic,
                              child: Icon(Icons.keyboard_arrow_up, color: g.muted),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              ClipRect(
                child: AnimatedAlign(
                  duration: _duration,
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  heightFactor: _expanded ? 1 : 0,
                  onEnd: () {
                    if (!_expanded && _tipMounted) setState(() => _tipMounted = false);
                  },
                  child: AnimatedOpacity(
                    opacity: _expanded ? 1 : 0,
                    duration: _duration,
                    child: _tipMounted
                        ? Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 20), child: widget.tip)
                        : const SizedBox(width: double.infinity),
                  ),
                ),
              ),
              if (footer != null) Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 16), child: footer),
            ],
          ),
        ),
      ),
    );
  }
}
