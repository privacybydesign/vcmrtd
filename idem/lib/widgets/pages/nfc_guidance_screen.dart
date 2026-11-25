// Created for UX improvement - NFC positioning guidance screen
// Implementation based on hive design specifications

import 'dart:async';

import 'package:vcmrtd/vcmrtd.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:idem/l10n/l10n.dart';
import 'package:idem/widgets/common/brand_mark.dart';
import 'package:idem/theme/brand_theme.dart';
import 'package:idem/widgets/guided/guided_widgets.dart';
import 'package:idem/services/flow_step_plan.dart';

/// NFC guidance screen - helps users position phone correctly for NFC reading
class NfcGuidanceScreen extends StatefulWidget {
  final VoidCallback onStartReading;
  final VoidCallback onBack;
  final DocumentType documentType;

  /// Step badge numbers — default to vcmrtd's fixed 4-step sequence (this
  /// screen is always step 2 there); see NfcReadingScreen's matching fields.
  final int stepNumber;
  final int totalSteps;

  const NfcGuidanceScreen({
    super.key,
    required this.onStartReading,
    required this.onBack,
    required this.documentType,
    this.stepNumber = FlowStepPlan.defaultNfcReadStep,
    this.totalSteps = FlowStepPlan.defaultTotalSteps,
  });

  @override
  State<NfcGuidanceScreen> createState() => _NfcGuidanceScreenState();
}

class _NfcGuidanceScreenState extends State<NfcGuidanceScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  var _isNfcAvailable = false;
  late Timer _timerStateUpdater;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(duration: const Duration(seconds: 1), vsync: this);
    _animationController.repeat(reverse: true);

    _initNFCState();

    // Update platform state every 3 sec
    _timerStateUpdater = Timer.periodic(const Duration(seconds: 3), (Timer t) {
      _initNFCState();
    });
  }

  Future<void> _initNFCState() async {
    bool isNfcAvailable;
    try {
      NfcStatus status = await NfcProvider.nfcStatus;
      isNfcAvailable = status == NfcStatus.enabled;
    } on PlatformException {
      isNfcAvailable = false;
    }

    if (!mounted || isNfcAvailable == _isNfcAvailable) return;

    setState(() {
      _isNfcAvailable = isNfcAvailable;
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _timerStateUpdater.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _buildGuided(context.guided);
  }

  Widget _buildGuided(GuidedStyle g) {
    final l10n = context.l10n;
    final type = widget.documentType.name;
    final steps = [l10n.nfcGuidanceStepLay(type), l10n.nfcGuidanceStepPlace(type), l10n.nfcGuidanceStepKeepStill];

    return GuidedStatusBar(
      backdrop: Backdrop.light,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GuidedTopBar(
                leading: GuidedRoundButton(icon: Icons.chevron_left, tooltip: l10n.docBack, onPressed: widget.onBack),
                center: const BrandMark(size: 32),
              ),
              GuidedStepBar(step: widget.stepNumber, total: widget.totalSteps),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 32, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AspectRatio(
                        aspectRatio: _GuidedNfcIllustration.size.aspectRatio,
                        child: AnimatedBuilder(
                          animation: _animationController,
                          builder: (context, _) => _GuidedNfcIllustration(style: g, pulse: _animationController.value),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GuidedStepLabel(step: widget.stepNumber, total: widget.totalSteps),
                            const SizedBox(height: 12),
                            GuidedHeading(l10n.nfcHoldPhoneOn(type), style: g.heading(26)),
                            const SizedBox(height: 12),
                            Text(
                              l10n.nfcGuidanceIntro(type),
                              style: TextStyle(fontSize: 16, height: 1.5, color: g.bodyText),
                            ),
                            const SizedBox(height: 20),
                            for (final (i, step) in steps.indexed) ...[
                              if (i > 0) const SizedBox(height: 14),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 28,
                                    height: 28,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(color: g.header, shape: BoxShape.circle),
                                    child: Text('${i + 1}', style: g.heading(13, color: Colors.white)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 3),
                                      child: Text(step, style: TextStyle(fontSize: 15, height: 1.45, color: g.ink)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: guidedBottomButtonPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!_isNfcAvailable) ...[
                      Text(
                        l10n.nfcTurnedOff,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: g.bodyText),
                      ),
                      const SizedBox(height: 12),
                    ],
                    GuidedButton(
                      label: l10n.docNfcStepStart,
                      onPressed: _isNfcAvailable ? widget.onStartReading : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A phone lying on a document with NFC waves, drawn in a [size] box and
/// scaled to fit. [pulse] (0–1) breathes the waves.
class _GuidedNfcIllustration extends StatelessWidget {
  const _GuidedNfcIllustration({required this.style, required this.pulse});

  static const size = Size(350, 260);

  final GuidedStyle style;
  final double pulse;

  @override
  Widget build(BuildContext context) {
    final g = style;
    Widget ring(double size, double width, double opacity) => Positioned(
      left: 184 - size / 2,
      top: 112 - size / 2,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: g.heroAccent.withValues(alpha: opacity),
            width: width,
          ),
        ),
      ),
    );
    final grow = 1 + 0.06 * pulse;
    return DecoratedBox(
      decoration: BoxDecoration(color: g.actionTint, borderRadius: BorderRadius.circular(24)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: FittedBox(
          child: SizedBox.fromSize(
            size: size,
            child: Stack(
              children: [
                Positioned(
                  left: 70,
                  top: 96,
                  child: Transform.rotate(
                    angle: -0.105,
                    child: Container(
                      width: 210,
                      height: 140,
                      decoration: BoxDecoration(color: g.illustrationDocument, borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                Positioned(
                  left: 132,
                  top: 24,
                  child: Container(
                    width: 104,
                    height: 188,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: g.ink, width: 4),
                      boxShadow: [
                        BoxShadow(color: g.ink.withValues(alpha: 0.18), blurRadius: 32, offset: const Offset(0, 16)),
                      ],
                    ),
                  ),
                ),
                ring(104 * grow, 2, 0.2 + 0.1 * pulse),
                ring(76 * grow, 2, 0.45),
                ring(48, 3, 0.9),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
