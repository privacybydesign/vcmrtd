// Created for UX improvement - NFC positioning guidance screen
// Implementation based on hive design specifications

import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';

/// NFC guidance screen - helps users position phone correctly for NFC reading
class NfcGuidanceScreen extends StatefulWidget {
  final VoidCallback onStartReading;
  final VoidCallback onBack;
  final VoidCallback? onTroubleshooting;

  const NfcGuidanceScreen({
    Key? key,
    required this.onStartReading,
    required this.onBack,
    this.onTroubleshooting,
  }) : super(key: key);

  @override
  State<NfcGuidanceScreen> createState() => _NfcGuidanceScreenState();
}

class _NfcGuidanceScreenState extends State<NfcGuidanceScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _positionAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    
    // Setup positioning animation
    _animationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    
    _positionAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _glowAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    // Start animation loop
    _animationController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: const Text('Position Your Phone'),
        leading: PlatformIconButton(
          icon: Icon(PlatformIcons(context).back),
          onPressed: widget.onBack,
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Progress indicator
              const LinearProgressIndicator(
                value: 0.75, // Step 3 of 4
                backgroundColor: Color(0xFFE0E0E0),
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2196F3)),
              ),
              const SizedBox(height: 8),
              const Text(
                'Step 3 of 4',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF666666),
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 32),
              
              // Animation area - 60% of available space
              Expanded(
                flex: 6,
                child: AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return _buildPositioningDiagram();
                  },
                ),
              ),
              
              // Instruction area - 30% of available space
              Expanded(
                flex: 3,
                child: _buildInstructions(),
              ),
              
              // Button area - 10% of available space
              _buildButtons(),
            ],
          ),
        ),
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
          // Dotted alignment guides
          Positioned.fill(
            child: CustomPaint(
              painter: AlignmentGuidesPainter(),
            ),
          ),
          
          // Phone illustration (moves up and down)
          Positioned(
            top: 60 + (_positionAnimation.value * 20),
            child: _buildPhoneIllustration(),
          ),
          
          // Passport illustration with glowing NFC indicator
          Positioned(
            bottom: 60,
            child: _buildPassportIllustration(),
          ),
          
          // Distance indicator
          Positioned(
            right: 20,
            top: 100,
            child: _buildDistanceIndicator(),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneIllustration() {
    return Container(
      width: 120,
      height: 60,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF2196F3), width: 3),
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
      ),
      child: const Center(
        child: Icon(
          Icons.smartphone,
          color: Color(0xFF2196F3),
          size: 30,
        ),
      ),
    );
  }

  Widget _buildPassportIllustration() {
    return Container(
      width: 160,
      height: 100,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF424242), width: 2),
        borderRadius: BorderRadius.circular(8),
        color: const Color(0xFFBDBDBD),
      ),
      child: Stack(
        children: [
          const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'PASSPORT',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF424242),
                  ),
                ),
                Text(
                  'Back Cover',
                  style: TextStyle(
                    fontSize: 10,
                    color: Color(0xFF666666),
                  ),
                ),
              ],
            ),
          ),
          
          // Glowing NFC chip indicator
          Positioned(
            top: 20,
            right: 20,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.orange,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withOpacity(_glowAnimation.value),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDistanceIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF2196F3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        '2-3cm',
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildInstructions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Place your phone on the back cover of your passport',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF212121),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Keep the phone flat and centered over the passport',
          style: TextStyle(
            fontSize: 16,
            color: Color(0xFF666666),
          ),
        ),
        const SizedBox(height: 16),
        
        // Tips
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tips for better results:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF374151),
                ),
              ),
              SizedBox(height: 8),
              Text(
                '• Remove any phone case if reading fails\n'
                '• Keep both devices still during reading\n'
                '• The process takes 10-30 seconds',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280),
                  height: 1.4,
                ),
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
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'I\'m Ready',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        
        const SizedBox(height: 8),
        
        if (widget.onTroubleshooting != null)
          PlatformTextButton(
            onPressed: widget.onTroubleshooting,
            child: const Text(
              'Having trouble?',
              style: TextStyle(
                color: Color(0xFF2196F3),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }
}

/// Custom painter for alignment guides (dotted lines)
class AlignmentGuidesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey[400]!
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Vertical center line (dotted)
    _drawDottedLine(
      canvas,
      paint,
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
    );
    
    // Horizontal center line (dotted)
    _drawDottedLine(
      canvas,
      paint,
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
    );
  }

  void _drawDottedLine(Canvas canvas, Paint paint, Offset start, Offset end) {
    const double dashLength = 8;
    const double gapLength = 4;
    
    final double totalLength = (end - start).distance;
    final int segments = (totalLength / (dashLength + gapLength)).floor();
    
    final Offset direction = (end - start) / totalLength;
    
    for (int i = 0; i < segments; i++) {
      final double startDistance = i * (dashLength + gapLength);
      final double endDistance = startDistance + dashLength;
      
      final Offset segmentStart = start + direction * startDistance;
      final Offset segmentEnd = start + direction * endDistance;
      
      canvas.drawLine(segmentStart, segmentEnd, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}