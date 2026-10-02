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
                    SizedBox(height: 240, child: _buildPositioningDiagram()),
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
          // Only the phone moves; the rest isn't rebuilt every frame.
          AnimatedBuilder(
            animation: _positionAnimation,
            child: buildPhoneIllustration(),
            builder: (context, phone) => Positioned(top: 40 + (_positionAnimation.value * 20), child: phone!),
          ),
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
      ],
    );
  }
}
