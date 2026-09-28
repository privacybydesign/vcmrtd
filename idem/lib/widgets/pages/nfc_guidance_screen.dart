// Created for UX improvement - NFC positioning guidance screen
// Implementation based on hive design specifications

import 'dart:async';

import 'package:vcmrtd/vcmrtd.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:mrz_capture/mrz_capture.dart';
import 'package:idem/l10n/l10n.dart';
import 'package:idem/widgets/common/document_illustrations.dart';
import 'package:idem/theme/brand_theme.dart';
import 'package:idem/widgets/guided/guided_widgets.dart';

/// NFC guidance screen - helps users position phone correctly for NFC reading
class NfcGuidanceScreen extends StatefulWidget {
  final VoidCallback onStartReading;
  final VoidCallback onBack;
  final VoidCallback? onTroubleshooting;
  final DocumentType documentType;

  /// Step badge numbers — default to vcmrtd's fixed 4-step sequence (this
  /// screen is always step 2 there); see NfcReadingScreen's matching fields.
  final int stepNumber;
  final int totalSteps;

  const NfcGuidanceScreen({
    super.key,
    required this.onStartReading,
    required this.onBack,
    this.onTroubleshooting,
    required this.documentType,
    this.stepNumber = 2,
    this.totalSteps = 4,
  });

  @override
  State<NfcGuidanceScreen> createState() => _NfcGuidanceScreenState();
}

class _NfcGuidanceScreenState extends State<NfcGuidanceScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _positionAnimation;
  var _isNfcAvailable = false;
  late Timer _timerStateUpdater;

  @override
  void initState() {
    super.initState();

    // Setup positioning animation
    _animationController = AnimationController(duration: const Duration(seconds: 1), vsync: this);

    _positionAnimation = Tween<double>(
      begin: 0.0,
      end: 2.0,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));
    // Start animation loop
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

    if (!mounted) return;

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
    final guided = context.guided;
    if (guided != null) return _buildGuided(guided);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      context.l10n.docNfcGuidanceTitle,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF212121)),
                    ),
                    const SizedBox(height: 4.0),
                    Text(
                      context.l10n.docNfcGuidancePlacePhone(widget.documentType.name),
                      style: const TextStyle(fontSize: 15, color: Color(0xFF6B7280)),
                    ),
                    const SizedBox(height: 24.0),
                    // Animation area
                    SizedBox(
                      height: 240,
                      child: AnimatedBuilder(
                        animation: _animationController,
                        builder: (context, child) {
                          return _buildPositioningDiagram();
                        },
                      ),
                    ),
                    const SizedBox(height: 24.0),

                    // Instruction area
                    _buildInstructions(),
                    const SizedBox(height: 24.0),

                    // Button area
                    _buildButtons(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuided(GuidedStyle g) {
    final (name, isBooklet) = switch (widget.documentType) {
      DocumentType.passport => ('passport', true),
      DocumentType.identityCard => ('ID card', false),
      DocumentType.drivingLicence => ('driving licence', false),
    };
    final steps = [
      isBooklet
          ? 'Close the passport and lay it on a flat, non-metal surface.'
          : 'Lay the $name on a flat, non-metal surface.',
      'Place the top half of your phone flat on the ${isBooklet ? 'cover' : 'card'}.',
      'Keep still until the check turns green. Remove a thick phone case if reading fails.',
    ];

    return GuidedStatusBar(
      onDark: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GuidedTopBar(
                leading: GuidedRoundButton(icon: Icons.chevron_left, tooltip: 'Back', onPressed: widget.onBack),
                center: Image.asset(g.markAsset, width: 32, height: 32, semanticLabel: context.brand.appBarTitle),
              ),
              const GuidedStepBar(step: 2),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 32, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AspectRatio(
                        aspectRatio: 350 / 260,
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
                            const GuidedStepLabel(step: 2),
                            const SizedBox(height: 12),
                            Text('Hold your phone on the $name', style: g.heading(26)),
                            const SizedBox(height: 12),
                            Text(
                              'Your $name has a chip that proves it is genuine. We read it with NFC.',
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
                                    decoration: BoxDecoration(color: g.ink, shape: BoxShape.circle),
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
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!_isNfcAvailable) ...[
                      Text(
                        "NFC is turned off. Turn it on in your phone's settings to continue.",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: g.bodyText),
                      ),
                      const SizedBox(height: 12),
                    ],
                    GuidedButton(label: 'Start reading', onPressed: _isNfcAvailable ? widget.onStartReading : null),
                    if (widget.onTroubleshooting != null) ...[
                      const SizedBox(height: 4),
                      TextButton(onPressed: widget.onTroubleshooting, child: const Text('Having trouble?')),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return StepBadgeTopBar(
      icon: PlatformIcons(context).back,
      onBack: widget.onBack,
      current: widget.stepNumber,
      total: widget.totalSteps,
      label: context.l10n.docReadDocument(widget.documentType.name),
    );
  }

  Widget _buildPositioningDiagram() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(bottom: 60, child: buildDocumentIllustration(widget.documentType)),
          Positioned(top: 40 + (_positionAnimation.value * 20), child: buildPhoneIllustration()),
        ],
      ),
    );
  }

  Widget _buildInstructions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tips
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(8)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.docNfcGuidanceTipsTitle,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.docNfcGuidanceTips(widget.documentType.name),
                style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280), height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_isNfcAvailable)
          ElevatedButton(
            onPressed: widget.onStartReading,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                context.l10n.docScanDocument(widget.documentType.name),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              context.l10n.docNfcNotAvailable,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
        const SizedBox(height: 8),
        if (widget.onTroubleshooting != null)
          PlatformTextButton(
            onPressed: widget.onTroubleshooting,
            child: Text(
              context.l10n.docHavingTrouble,
              style: TextStyle(color: context.brand.accent ?? const Color(0xFF2196F3), fontWeight: FontWeight.w500),
            ),
          ),
      ],
    );
  }
}

/// A phone lying on a document with NFC waves, drawn in a 350×260 box and
/// scaled to fit. [pulse] (0–1) breathes the waves.
class _GuidedNfcIllustration extends StatelessWidget {
  const _GuidedNfcIllustration({required this.style, required this.pulse});

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
          child: SizedBox(
            width: 350,
            height: 260,
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
