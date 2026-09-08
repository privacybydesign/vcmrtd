// Created for UX improvement - NFC positioning guidance screen
// Implementation based on hive design specifications

import 'dart:async';

import 'package:vcmrtd/vcmrtd.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:mrz_capture/mrz_capture.dart';
import 'package:vcmrtdapp/widgets/common/document_illustrations.dart';

/// NFC guidance screen - helps users position phone correctly for NFC reading
class NfcGuidanceScreen extends StatefulWidget {
  final VoidCallback onStartReading;
  final VoidCallback onBack;
  final VoidCallback? onTroubleshooting;
  final DocumentType documentType;

  const NfcGuidanceScreen({
    super.key,
    required this.onStartReading,
    required this.onBack,
    this.onTroubleshooting,
    required this.documentType,
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
                      'Read the chip',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF212121)),
                    ),
                    const SizedBox(height: 4.0),
                    Text(
                      'Place your phone on the ${widget.documentType.displayName}',
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

  Widget _buildTopBar(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(icon: Icon(PlatformIcons(context).back), onPressed: widget.onBack),
          ),
          StepBadge(current: 2, total: 4, label: 'Read ${widget.documentType.displayName}'),
        ],
      ),
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
              const Text(
                'Tips for better results:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
              ),
              const SizedBox(height: 8),
              Text(
                '• Place the ${widget.documentType.displayName} behind your phone like in the example\n'
                '• Remove phone case if reading fails\n'
                '• The process may take 10–30 seconds',
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
                'Scan ${widget.documentType.displayName}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
          )
        else
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'NFC is not available',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
        const SizedBox(height: 8),
        if (widget.onTroubleshooting != null)
          PlatformTextButton(
            onPressed: widget.onTroubleshooting,
            child: const Text(
              'Having trouble?',
              style: TextStyle(color: Color(0xFF2196F3), fontWeight: FontWeight.w500),
            ),
          ),
      ],
    );
  }
}
