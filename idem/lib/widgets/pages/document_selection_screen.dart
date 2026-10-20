import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:idem/l10n/l10n.dart';
import 'package:idem/providers/proofing_session_provider.dart';
import 'package:idem/widgets/common/brand_mark.dart';
import 'package:idem/theme/brand_theme.dart';
import 'package:idem/widgets/guided/guided_widgets.dart';

/// Home screen (see [_GuidedHome]).
class DocumentTypeSelectionScreen extends ConsumerWidget {
  final VoidCallback onSettingsPressed;
  final VoidCallback onScanQrPressed;

  /// Resumes a proofing session that was accepted but not finished, in place
  /// of scanning a new QR code.
  final VoidCallback? onContinueProofingSession;

  const DocumentTypeSelectionScreen({
    super.key,
    required this.onSettingsPressed,
    required this.onScanQrPressed,
    this.onContinueProofingSession,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _GuidedHome(
      onSettingsPressed: onSettingsPressed,
      onScanQrPressed: onScanQrPressed,
      onContinueProofingSession: onContinueProofingSession,
      connectedRelyingParty: ref.watch(activeProofingSessionProvider)?.info.relyingParty,
    );
  }
}

/// Home in the guided layout, where every verification starts from a QR
/// code: the hero leads with "Scan QR code", followed by how it works. Saved
/// documents live under settings, not here.
class _GuidedHome extends StatelessWidget {
  const _GuidedHome({
    required this.onSettingsPressed,
    required this.onScanQrPressed,
    required this.onContinueProofingSession,
    required this.connectedRelyingParty,
  });

  final VoidCallback onSettingsPressed;
  final VoidCallback onScanQrPressed;
  final VoidCallback? onContinueProofingSession;

  /// Set while an accepted proofing session is still open.
  final String? connectedRelyingParty;

  @override
  Widget build(BuildContext context) {
    final g = context.guided;
    final l10n = context.l10n;
    final connected = connectedRelyingParty != null && onContinueProofingSession != null;
    return GuidedStatusBar(
      backdrop: Backdrop.dark,
      bottomBackdrop: Backdrop.light,
      child: Scaffold(
        backgroundColor: g.surface,
        body: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                decoration: BoxDecoration(
                  color: g.header,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
                ),
                padding: EdgeInsets.fromLTRB(20, MediaQuery.paddingOf(context).top + 20, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const BrandMark(size: 40, backdrop: Backdrop.dark),
                        const Spacer(),
                        GuidedRoundButton(
                          icon: Icons.settings_outlined,
                          tooltip: l10n.docSettingsTitle,
                          backdrop: Backdrop.dark,
                          fill: GuidedRoundButtonFill.outlined,
                          onPressed: onSettingsPressed,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      l10n.homeEyebrow,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.04,
                        color: g.heroEyebrow,
                      ),
                    ),
                    const SizedBox(height: 10),
                    GuidedHeading(l10n.homeTitle, style: g.heading(30, color: Colors.white)),
                    const SizedBox(height: 10),
                    Text(
                      connected ? l10n.homeConnectedBody(connectedRelyingParty!) : l10n.homeBody,
                      style: TextStyle(fontSize: 16, height: 1.5, color: g.heroMuted),
                    ),
                    const SizedBox(height: 24),
                    const Center(child: _GuidedQrBadge()),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: connected ? onContinueProofingSession : onScanQrPressed,
                      style: g.heroButtonStyle.copyWith(
                        minimumSize: const WidgetStatePropertyAll(Size.fromHeight(56)),
                        textStyle: WidgetStatePropertyAll(
                          g.heroButtonStyle.textStyle?.resolve({})?.copyWith(fontSize: 17),
                        ),
                      ),
                      icon: Icon(connected ? Icons.arrow_forward : Icons.qr_code_scanner, size: 22),
                      label: Text(connected ? l10n.homeContinueWith(connectedRelyingParty!) : l10n.docScanQrTitle),
                    ),
                  ],
                ),
              ),
            ),
            SliverFillRemaining(
              hasScrollBody: false,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      GuidedHeading(
                        l10n.homeHowItWorks,
                        style: g.heading(16, weight: FontWeight.w600, color: g.slate),
                      ),
                      const SizedBox(height: 14),
                      for (final (i, step) in [
                        l10n.homeStepScan,
                        l10n.homeStepDocument,
                        l10n.homeStepSelfie,
                      ].indexed) ...[
                        if (i > 0) const SizedBox(height: 14),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 26,
                              height: 26,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(color: g.actionTint, shape: BoxShape.circle),
                              child: Text('${i + 1}', style: g.heading(13, color: g.action)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(step, style: TextStyle(fontSize: 15, height: 1.45, color: g.ink)),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const Spacer(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The QR illustration in the home hero: a QR glyph with scan-frame corners.
class _GuidedQrBadge extends StatelessWidget {
  const _GuidedQrBadge();

  @override
  Widget build(BuildContext context) {
    final g = context.guided;
    return SizedBox(
      width: 140,
      height: 140,
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Center(
                  child: SizedBox(width: 76, height: 76, child: CustomPaint(painter: GuidedQrGlyphPainter())),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: CustomPaint(painter: _ScanCornersPainter(color: g.heroAccent)),
          ),
        ],
      ),
    );
  }
}

class _ScanCornersPainter extends CustomPainter {
  const _ScanCornersPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const len = 24.0, r = 14.0;
    final w = size.width, h = size.height;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    const radius = Radius.circular(r);
    canvas.drawPath(
      Path()
        ..moveTo(0, len)
        ..lineTo(0, r)
        ..arcToPoint(const Offset(r, 0), radius: radius)
        ..lineTo(len, 0)
        ..moveTo(w - len, 0)
        ..lineTo(w - r, 0)
        ..arcToPoint(Offset(w, r), radius: radius)
        ..lineTo(w, len)
        ..moveTo(w, h - len)
        ..lineTo(w, h - r)
        ..arcToPoint(Offset(w - r, h), radius: radius)
        ..lineTo(w - len, h)
        ..moveTo(len, h)
        ..lineTo(r, h)
        ..arcToPoint(Offset(0, h - r), radius: radius)
        ..lineTo(0, h - len),
      paint,
    );
  }

  @override
  bool shouldRepaint(_ScanCornersPainter old) => old.color != color;
}
