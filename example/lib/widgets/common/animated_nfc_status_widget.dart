// Created by Hive Mind Collective Intelligence, copyright © 2025. All rights reserved.
// Animated NFC status display widget with beautiful state-based animations

import 'package:flutter/material.dart';

/// Enumeration of NFC reading states for animation control
enum NFCReadingState {
  waiting,
  connecting,
  reading,
  authenticating,
  success,
  error,
  idle,
  cancelling
}

/// Animated widget to display NFC reading status with beautiful animations
class AnimatedNFCStatusWidget extends StatefulWidget {
  final NFCReadingState state;
  final String message;
  final VoidCallback? onRetry;
  final VoidCallback? onCancel;
  final double progress; // 0.0 to 1.0 for progress indicators

  const AnimatedNFCStatusWidget({
    Key? key,
    required this.state,
    required this.message,
    this.onRetry,
    this.onCancel,
    this.progress = 0.0,
  }) : super(key: key);

  @override
  State<AnimatedNFCStatusWidget> createState() => _AnimatedNFCStatusWidgetState();
}

class _AnimatedNFCStatusWidgetState extends State<AnimatedNFCStatusWidget>
    with TickerProviderStateMixin {
  late AnimationController _primaryController;
  late AnimationController _secondaryController;
  late AnimationController _shakeController;
  
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _shakeAnimation;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    
    // Primary controller for state transitions and scale effects
    _primaryController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    // Secondary controller for continuous animations (pulse, rotation)
    _secondaryController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    // Shake controller for error states
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _initializeAnimations();
    _updateAnimationState();
  }

  void _initializeAnimations() {
    // Scale animation for state transitions
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _primaryController,
      curve: Curves.elasticOut,
    ));
    
    // Rotation animation for loading states
    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _secondaryController,
      curve: Curves.linear,
    ));
    
    // Pulse animation for waiting states
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _secondaryController,
      curve: Curves.easeInOut,
    ));
    
    // Shake animation for error states
    _shakeAnimation = Tween<double>(
      begin: -10.0,
      end: 10.0,
    ).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.bounceOut,
    ));
    
    // Color animation for state changes
    _colorAnimation = ColorTween(
      begin: Colors.grey,
      end: _getStateColor(),
    ).animate(CurvedAnimation(
      parent: _primaryController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void didUpdateWidget(AnimatedNFCStatusWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _updateAnimationState();
    }
  }

  void _updateAnimationState() {
    // Update color animation target
    _colorAnimation = ColorTween(
      begin: _colorAnimation.value ?? Colors.grey,
      end: _getStateColor(),
    ).animate(CurvedAnimation(
      parent: _primaryController,
      curve: Curves.easeInOut,
    ));
    
    // Reset and start primary animation for state change
    _primaryController.reset();
    _primaryController.forward();
    
    // Handle continuous animations based on state
    switch (widget.state) {
      case NFCReadingState.waiting:
        _secondaryController.repeat(reverse: true);
        break;
      case NFCReadingState.connecting:
      case NFCReadingState.reading:
      case NFCReadingState.authenticating:
        _secondaryController.repeat();
        break;
      case NFCReadingState.success:
        _secondaryController.stop();
        break;
      case NFCReadingState.error:
        _secondaryController.stop();
        _shakeController.forward().then((_) => _shakeController.reverse());
        break;
      case NFCReadingState.cancelling:
        _secondaryController.stop();
        break;
      case NFCReadingState.idle:
        _secondaryController.stop();
        break;
    }
  }

  Color _getStateColor() {
    switch (widget.state) {
      case NFCReadingState.waiting:
        return const Color(0xFF2196F3); // Blue
      case NFCReadingState.connecting:
      case NFCReadingState.reading:
      case NFCReadingState.authenticating:
        return const Color(0xFFFF9800); // Orange
      case NFCReadingState.success:
        return const Color(0xFF4CAF50); // Green
      case NFCReadingState.error:
        return const Color(0xFFF44336); // Red
      case NFCReadingState.cancelling:
        return const Color(0xFFFF9800); // Orange (transitional state)
      case NFCReadingState.idle:
        return const Color(0xFF757575); // Gray
    }
  }

  IconData _getStateIcon() {
    switch (widget.state) {
      case NFCReadingState.waiting:
        return Icons.nfc;
      case NFCReadingState.connecting:
        return Icons.wifi_find;
      case NFCReadingState.reading:
        return Icons.sync;
      case NFCReadingState.authenticating:
        return Icons.security;
      case NFCReadingState.success:
        return Icons.check_circle;
      case NFCReadingState.error:
        return Icons.error;
      case NFCReadingState.cancelling:
        return Icons.cancel;
      case NFCReadingState.idle:
        return Icons.nfc;
    }
  }

  Widget _buildAnimatedIcon() {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _scaleAnimation,
        _rotationAnimation,
        _pulseAnimation,
        _shakeAnimation,
        _colorAnimation,
      ]),
      builder: (context, child) {
        Widget iconWidget = Icon(
          _getStateIcon(),
          size: 64,
          color: _colorAnimation.value ?? _getStateColor(),
        );

        // Apply state-specific animations
        switch (widget.state) {
          case NFCReadingState.waiting:
            iconWidget = Transform.scale(
              scale: _pulseAnimation.value,
              child: iconWidget,
            );
            break;
          case NFCReadingState.connecting:
          case NFCReadingState.reading:
          case NFCReadingState.authenticating:
            iconWidget = Transform.rotate(
              angle: _rotationAnimation.value * 2 * 3.14159,
              child: iconWidget,
            );
            break;
          case NFCReadingState.success:
            iconWidget = Transform.scale(
              scale: _scaleAnimation.value,
              child: iconWidget,
            );
            break;
          case NFCReadingState.error:
            iconWidget = Transform.translate(
              offset: Offset(_shakeAnimation.value, 0),
              child: iconWidget,
            );
            break;
          default:
            break;
        }

        return Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: (_colorAnimation.value ?? _getStateColor()).withOpacity(0.1),
            border: Border.all(
              color: _colorAnimation.value ?? _getStateColor(),
              width: 2,
            ),
          ),
          child: Center(
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: iconWidget,
            ),
          ),
        );
      },
    );
  }

  Widget _buildProgressIndicator() {
    if (widget.state == NFCReadingState.reading ||
        widget.state == NFCReadingState.authenticating) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Column(
          children: [
            LinearProgressIndicator(
              value: widget.progress > 0 ? widget.progress : null,
              backgroundColor: _getStateColor().withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(_getStateColor()),
            ),
            if (widget.progress > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  '${(widget.progress * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 12,
                    color: _getStateColor(),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildRetryButton() {
    if (widget.state == NFCReadingState.error && widget.onRetry != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 16.0),
        child: ElevatedButton.icon(
          onPressed: widget.onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Try Again'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _getStateColor(),
            foregroundColor: Colors.white,
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildCancelButton() {
    if ((widget.state == NFCReadingState.waiting ||
         widget.state == NFCReadingState.connecting ||
         widget.state == NFCReadingState.reading) && 
        widget.onCancel != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 16.0),
        child: OutlinedButton.icon(
          onPressed: widget.onCancel,
          icon: const Icon(Icons.close),
          label: const Text('Cancel'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFF44336), // Material red
            side: const BorderSide(color: Color(0xFFF44336)),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _colorAnimation,
      builder: (context, child) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildAnimatedIcon(),
            const SizedBox(height: 24),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 300),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: _colorAnimation.value ?? _getStateColor(),
              ),
              child: Text(
                widget.message,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _buildProgressIndicator(),
            _buildRetryButton(),
            _buildCancelButton(),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _primaryController.dispose();
    _secondaryController.dispose();
    _shakeController.dispose();
    super.dispose();
  }
}