// Animated illustration of a phone resting on the document with pulsing
// signal rings, shown above the circular progress ring while actively
// reading over NFC.

import 'package:flutter/material.dart';
import 'package:vcmrtd/vcmrtd.dart';
import 'package:vcmrtdapp/widgets/common/document_illustrations.dart';

class NfcReadingAnimation extends StatefulWidget {
  const NfcReadingAnimation({super.key, required this.documentType});

  final DocumentType documentType;

  @override
  State<NfcReadingAnimation> createState() => _NfcReadingAnimationState();
}

class _NfcReadingAnimationState extends State<NfcReadingAnimation> with SingleTickerProviderStateMixin {
  static const _pulseDelays = [0.0, 0.33, 0.66];

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 1800), vsync: this)..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 170,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(bottom: 10, child: buildDocumentIllustration(widget.documentType)),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: [for (final delay in _pulseDelays) _buildPulseRing(delay)],
              );
            },
          ),
          Positioned(
            top: 0,
            child: Stack(
              alignment: Alignment.center,
              children: [buildPhoneIllustration(), const Icon(Icons.wifi, color: Color(0xFF2196F3), size: 28)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPulseRing(double delay) {
    final t = (_controller.value + delay) % 1.0;
    final scale = 0.5 + t;
    final opacity = (1.0 - t) * 0.5;

    return Positioned(
      top: 30,
      child: Opacity(
        opacity: opacity,
        child: Transform.scale(
          scale: scale,
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF2196F3), width: 2),
            ),
          ),
        ),
      ),
    );
  }
}
