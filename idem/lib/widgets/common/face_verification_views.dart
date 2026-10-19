import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:mrz_capture/mrz_capture.dart';
import 'package:idem/l10n/l10n.dart';
import 'package:idem/theme/brand_theme.dart';
import 'package:idem/widgets/common/brand_mark.dart';
import 'package:idem/widgets/common/button_styles.dart';
import 'package:idem/widgets/guided/guided_widgets.dart';

/// The layouts every face-verification engine's screen shares (Regula,
/// Iris): the intro before the scan starts, a busy state while it runs, and
/// the result.

/// The frame around a running scan or its result: the guided top and step
/// bars, or the classic step badge.
class FaceStepScaffold extends StatelessWidget {
  final int stepNumber;
  final int totalSteps;
  final VoidCallback onBack;
  final Widget child;

  const FaceStepScaffold({
    super.key,
    required this.stepNumber,
    required this.totalSteps,
    required this.onBack,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (context.guided == null) {
      return Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              StepBadgeTopBar(
                icon: Icons.arrow_back,
                tooltip: l10n.faceBack,
                onBack: onBack,
                current: stepNumber,
                total: totalSteps,
                label: l10n.faceStepLabel,
              ),
              Expanded(child: child),
            ],
          ),
        ),
      );
    }
    return GuidedStatusBar(
      backdrop: Backdrop.light,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GuidedTopBar(
                leading: GuidedRoundButton(icon: Icons.chevron_left, tooltip: l10n.faceBack, onPressed: onBack),
                center: const BrandMark(size: 32, excludeFromSemantics: true),
              ),
              GuidedStepBar(step: stepNumber, total: totalSteps),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

/// What the scan is about to do, as numbered [steps], and a start button.
class FaceIntroView extends StatelessWidget {
  final String title;
  final String body;
  final List<String> steps;
  final VoidCallback onStart;

  const FaceIntroView({super.key, required this.title, required this.body, required this.steps, required this.onStart});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.verified_user, size: 64, color: context.brand.accent ?? Colors.green),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.faceIrisWhatToExpect, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                for (var i = 0; i < steps.length; i++) ...[
                  SizedBox(height: i == 0 ? 10 : 6),
                  _IntroStepRow(number: '${i + 1}', text: steps[i]),
                ],
              ],
            ),
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: onStart,
            style: context.brand.primaryButtonStyle ?? actionButtonStyle,
            icon: const Icon(Icons.face),
            label: Text(l10n.faceStartVerification),
          ),
        ],
      ),
    );
  }
}

/// The guided layout's intro: a selfie illustration, what the check does,
/// [tips] for a good result, and a full-width start button ([onStart] null
/// while it can't start yet).
class GuidedFaceIntroView extends StatelessWidget {
  final GuidedStyle style;
  final String title;
  final String body;
  final List<(IconData, String)> tips;
  final String startLabel;
  final VoidCallback? onStart;
  final VoidCallback onBack;
  final String backTooltip;
  final int stepNumber;
  final int totalSteps;

  const GuidedFaceIntroView({
    super.key,
    required this.style,
    required this.title,
    required this.body,
    required this.tips,
    required this.startLabel,
    required this.onStart,
    required this.onBack,
    required this.backTooltip,
    required this.stepNumber,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    final g = style;
    return GuidedStatusBar(
      backdrop: Backdrop.light,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GuidedTopBar(
                leading: GuidedRoundButton(icon: Icons.chevron_left, tooltip: backTooltip, onPressed: onBack),
                center: const BrandMark(size: 32, excludeFromSemantics: true),
              ),
              GuidedStepBar(step: stepNumber, total: totalSteps),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 36, 24, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 160,
                          height: 160,
                          decoration: BoxDecoration(color: g.actionTint, shape: BoxShape.circle),
                          child: Center(
                            child: SizedBox.fromSize(
                              size: _SelfieIllustrationPainter.size,
                              child: CustomPaint(painter: _SelfieIllustrationPainter(color: g.action)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      GuidedStepLabel(step: stepNumber, total: totalSteps),
                      const SizedBox(height: 12),
                      GuidedHeading(title, style: g.heading(26)),
                      const SizedBox(height: 12),
                      Text(body, style: TextStyle(fontSize: 16, height: 1.5, color: g.bodyText)),
                      for (final (i, (icon, text)) in tips.indexed) ...[
                        SizedBox(height: i == 0 ? 22 : 14),
                        _GuidedTipRow(style: g, icon: icon, text: text),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: guidedBottomButtonPadding,
                child: GuidedButton(label: startLabel, onPressed: onStart),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuidedTipRow extends StatelessWidget {
  final GuidedStyle style;
  final IconData icon;
  final String text;
  const _GuidedTipRow({required this.style, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: style.buttonGrey, borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, size: 18, color: style.slate),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: TextStyle(fontSize: 15, color: style.ink)),
        ),
      ],
    );
  }
}

/// A face in an oval: drawn in a [size] box.
class _SelfieIllustrationPainter extends CustomPainter {
  const _SelfieIllustrationPainter({required this.color});

  static const size = Size(96, 120);

  final Color color;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    canvas.scale(canvasSize.width / size.width, canvasSize.height / size.height);
    canvas.drawOval(
      const Rect.fromLTWH(4, 4, 88, 112),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    final fill = Paint()..color = color.withValues(alpha: 0.25);
    canvas.drawCircle(const Offset(48, 50), 17, fill);
    canvas.drawPath(
      Path()
        ..moveTo(20, 104)
        ..cubicTo(26, 89, 36, 82, 48, 82)
        ..cubicTo(60, 82, 70, 89, 76, 104)
        ..close(),
      fill,
    );
  }

  @override
  bool shouldRepaint(_SelfieIllustrationPainter old) => old.color != color;
}

class _IntroStepRow extends StatelessWidget {
  final String number;
  final String text;
  const _IntroStepRow({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 18,
          height: 18,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: Colors.black12, shape: BoxShape.circle),
          child: Text(number, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
      ],
    );
  }
}

/// A spinner with what is happening meanwhile.
class FaceBusyView extends StatelessWidget {
  final String label;
  const FaceBusyView({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final g = context.guided;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: g?.action),
            const SizedBox(height: 16),
            Text(
              label,
              textAlign: TextAlign.center,
              style: g == null ? null : TextStyle(fontSize: 16, color: g.bodyText),
            ),
          ],
        ),
      ),
    );
  }
}

/// Whether a result is a failure or only a note (cancelled).
enum FaceResultTone { failure, notice }

/// A scan that didn't pass, with the compared photos when there are any.
class FaceResultView extends StatelessWidget {
  final IconData icon;
  final FaceResultTone tone;
  final String title;
  final String subtitle;
  final Uint8List? documentPhoto;
  final Uint8List? liveFace;
  final VoidCallback onRetry;
  final String? retryLabel;

  const FaceResultView({
    super.key,
    required this.icon,
    required this.tone,
    required this.title,
    required this.subtitle,
    this.documentPhoto,
    this.liveFace,
    required this.onRetry,
    this.retryLabel,
  });

  @override
  Widget build(BuildContext context) {
    final documentPhoto = this.documentPhoto;
    final liveFace = this.liveFace;
    final g = context.guided;
    if (g != null) return _buildGuided(context, g);
    final color = tone == FaceResultTone.failure ? Colors.red : Colors.orange;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(icon, size: 80, color: color),
          const SizedBox(height: 24),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
          if (documentPhoto != null || liveFace != null) ...[
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (documentPhoto != null) _Thumbnail(label: context.l10n.faceDocumentPhoto, bytes: documentPhoto),
                if (documentPhoto != null && liveFace != null) const SizedBox(width: 16),
                if (liveFace != null) _Thumbnail(label: context.l10n.faceLiveCapture, bytes: liveFace),
              ],
            ),
          ],
          const SizedBox(height: 32),
          OutlinedButton(onPressed: onRetry, child: Text(retryLabel ?? context.l10n.faceTryAgain)),
        ],
      ),
    );
  }

  Widget _buildGuided(BuildContext context, GuidedStyle g) {
    final documentPhoto = this.documentPhoto;
    final liveFace = this.liveFace;
    final color = tone == FaceResultTone.failure ? g.error : g.slate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
                    child: Icon(icon, size: 48, color: color),
                  ),
                ),
                const SizedBox(height: 24),
                GuidedHeading(title, textAlign: TextAlign.center, style: g.heading(24, height: 1.25)),
                const SizedBox(height: 12),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, height: 1.5, color: g.bodyText),
                ),
                if (documentPhoto != null || liveFace != null) ...[
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (documentPhoto != null)
                        _Thumbnail(label: context.l10n.faceDocumentPhoto, bytes: documentPhoto),
                      if (documentPhoto != null && liveFace != null) const SizedBox(width: 16),
                      if (liveFace != null) _Thumbnail(label: context.l10n.faceLiveCapture, bytes: liveFace),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: guidedBottomButtonPadding,
          child: GuidedButton(label: retryLabel ?? context.l10n.faceTryAgain, icon: Icons.refresh, onPressed: onRetry),
        ),
      ],
    );
  }
}

class _Thumbnail extends StatelessWidget {
  final String label;
  final Uint8List bytes;
  const _Thumbnail({required this.label, required this.bytes});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(bytes, width: 100, height: 100, fit: BoxFit.cover),
        ),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(fontSize: 12, color: context.guided?.muted ?? Colors.grey)),
      ],
    );
  }
}
