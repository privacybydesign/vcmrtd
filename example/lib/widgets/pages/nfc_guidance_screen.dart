// Created for UX improvement - NFC positioning guidance screen
// Implementation based on hive design specifications

import 'dart:async';

import 'package:vcmrtd/vcmrtd.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';

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
      appBar: AppBar(
        title: Text('Read ${widget.documentType.displayName} via NFC'),
        leading: IconButton(icon: Icon(PlatformIcons(context).back), onPressed: widget.onBack),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    _isNfcAvailable ? 'NFC is available' : 'NFC is not available',
                    style: const TextStyle(fontSize: 18, color: Color(0xFF212121)),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _isNfcAvailable ? Icons.check_circle : Icons.cancel,
                    color: _isNfcAvailable ? Colors.green : Colors.red,
                    size: 24,
                  ),
                ],
              ),
              const SizedBox(height: 24.0),
              // Animation area
              SizedBox(
                height: 300, // or use MediaQuery if dynamic height needed
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
    );
  }

  Widget _buildPositioningDiagram() {
    final isPassport = widget.documentType == DocumentType.passport;

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(bottom: 60, child: isPassport ? _buildPassportIllustration() : _buildDrivingLicenceIllustration()),
          Positioned(top: 60 + (_positionAnimation.value * 20), child: _buildPhoneIllustration()),
        ],
      ),
    );
  }

  Widget _buildPhoneIllustration() {
    return Container(
      width: 80, // Portrait shape (narrower than height)
      height: 160,
      decoration: BoxDecoration(
        border: Border.all(color: const Color.fromARGB(255, 0, 0, 0), width: 3),
        borderRadius: BorderRadius.circular(20),
        color: Colors.white,
      ),
      child: Column(
        children: [
          // Notch (optional, to suggest speaker/camera area)
          Container(
            width: 40,
            height: 6,
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 0, 0, 0),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const Spacer(),
          // You can add a blank screen or content here if desired
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildPassportIllustration() {
    return RotatedBox(
      quarterTurns: 3,
      child: Container(
        width: 160,
        height: 200, // increased height to accommodate opened cover
        child: Column(
          children: [
            // Top half – passport cover flipped open
            Container(
              height: 90,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF424242),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                border: Border.all(color: const Color(0xFF424242), width: 2),
              ),
              child: const Center(
                child: RotatedBox(
                  quarterTurns: 2, // upside down to simulate flipping
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'PASSPORT',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      Text('Kingdom of Example', style: TextStyle(fontSize: 10, color: Colors.white70)),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom half – inner page with photo + info
            Container(
              height: 100,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFBDBDBD),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                border: Border.all(color: const Color(0xFF424242), width: 2),
              ),
              child: Row(
                children: [
                  // Photo placeholder
                  Container(
                    width: 70,
                    alignment: Alignment.center,
                    child: CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.grey.shade300,
                      child: Icon(Icons.person, size: 28, color: Colors.grey.shade700),
                    ),
                  ),
                  // Info text
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Name: John Doe', style: TextStyle(fontSize: 10, color: Color(0xFF333333))),
                        Text('Nationality: NL', style: TextStyle(fontSize: 10, color: Color(0xFF333333))),
                        Text('DOB: 01-01-1990', style: TextStyle(fontSize: 10, color: Color(0xFF333333))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrivingLicenceIllustration() {
    return Container(
      width: 155,
      height: 90,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFE0E6), Color(0xFFFFC1CC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Color(0xFFB48DA3), width: 1.2),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.15), blurRadius: 3, offset: const Offset(2, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SizedBox(width: 5),
                const Text(
                  'DRIVING LICENCE',
                  style: TextStyle(
                    color: Color(0xFF0046AD),
                    fontWeight: FontWeight.bold,
                    fontSize: 9,
                    letterSpacing: 0.4,
                  ),
                ),
                const Spacer(),
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: Colors.grey[400]!),
                  ),
                  child: Icon(Icons.person, size: 10, color: Colors.grey[600]),
                ),
              ],
            ),

            const SizedBox(height: 4),

            // Middle section – main photo placeholder
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: 38,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: Colors.grey[400]!),
                  ),
                  child: Icon(Icons.person, size: 20, color: Colors.grey[600]),
                ),
              ),
            ),

            // MRZ line at the bottom (only text, no bar)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'D1NLD2X150949621115MZ26KC47X2W',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    fontSize: 6,
                    color: Colors.black,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Place your phone on the ${widget.documentType.displayName} and press the 'Scan' button",
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF212121)),
        ),

        const SizedBox(height: 8),

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
                '• Place your phone on the section of the ${widget.documentType.displayName} with your photo\n'
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
        PlatformElevatedButton(
          onPressed: widget.onStartReading,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Scan ${widget.documentType.displayName}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
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
