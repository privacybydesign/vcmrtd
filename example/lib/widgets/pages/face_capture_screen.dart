import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_face_api/flutter_face_api.dart';
import 'package:vcmrtdapp/providers/face_verification_provider.dart';

/// Screen for capturing face with liveness check
class FaceCaptureScreen extends ConsumerStatefulWidget {
  final Uint8List? documentImage;
  final VoidCallback onBack;
  final Function(double matchScore)? onVerificationSuccess;
  final VoidCallback? onSkip;

  const FaceCaptureScreen({
    super.key,
    this.documentImage,
    required this.onBack,
    this.onVerificationSuccess,
    this.onSkip,
  });

  @override
  ConsumerState<FaceCaptureScreen> createState() => _FaceCaptureScreenState();
}

class _FaceCaptureScreenState extends ConsumerState<FaceCaptureScreen> {
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initializeFaceSDK();
  }

  Future<void> _initializeFaceSDK() async {
    final notifier = ref.read(faceVerificationProvider.notifier);
    await notifier.initialize();
  }

  Future<void> _startLiveness() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    final notifier = ref.read(faceVerificationProvider.notifier);

    try {
      final result = await notifier.startLiveness();

      if (result != null && result.image != null) {
        // If we have a document image, perform face matching
        if (widget.documentImage != null) {
          notifier.setDocumentImage(widget.documentImage!);
          final matchScore = await notifier.matchFaces();

          if (matchScore != null) {
            if (mounted) {
              _showMatchResult(matchScore);
            }
          } else {
            if (mounted) {
              _showError("Failed to match faces. Please try again.");
            }
          }
        } else {
          // No document image to match against, just show success
          if (mounted) {
            _showSuccess();
          }
        }
      }
    } catch (e) {
      if (mounted) {
        _showError("Liveness check failed: $e");
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _showMatchResult(double matchScore) {
    // Typical threshold for face matching is around 0.75 (75%)
    const threshold = 0.75;
    final isMatch = matchScore >= threshold;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(isMatch ? 'Verification Successful' : 'Verification Failed'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isMatch
                  ? 'Face verification passed successfully!'
                  : 'Face verification failed. The face does not match the document photo.',
            ),
            const SizedBox(height: 12),
            Text(
              'Match Score: ${(matchScore * 100).toStringAsFixed(1)}%',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isMatch ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Threshold: ${(threshold * 100).toStringAsFixed(0)}%',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          if (!isMatch)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Try Again'),
            ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (isMatch && widget.onVerificationSuccess != null) {
                widget.onVerificationSuccess!(matchScore);
              } else if (isMatch) {
                widget.onBack();
              }
            },
            child: Text(isMatch ? 'Continue' : 'Cancel'),
          ),
        ],
      ),
    );
  }

  void _showSuccess() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Liveness Check Complete'),
        content: const Text('Liveness check passed successfully!'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              widget.onBack();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(faceVerificationProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Face Verification'),
        leading: IconButton(
          icon: Icon(PlatformIcons(context).back),
          onPressed: widget.onBack,
        ),
        actions: [
          if (widget.onSkip != null)
            TextButton(
              onPressed: widget.onSkip,
              child: const Text(
                'Skip',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.face_retouching_natural,
                size: 120,
                color: Colors.indigo,
              ),
              const SizedBox(height: 32),
              const Text(
                'Face Verification with Liveness Check',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'We need to verify that you are a real person and match the photo on your document.',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              _buildInstructionCard(
                icon: Icons.center_focus_strong,
                title: 'Position your face',
                description: 'Make sure your face is clearly visible and well-lit',
              ),
              const SizedBox(height: 12),
              _buildInstructionCard(
                icon: Icons.remove_red_eye,
                title: 'Follow instructions',
                description: 'You may be asked to turn your head during the check',
              ),
              const SizedBox(height: 12),
              _buildInstructionCard(
                icon: Icons.check_circle_outline,
                title: 'Stay still',
                description: 'Keep your device steady and look directly at the camera',
              ),
              const Spacer(),
              if (state.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            state.error!,
                            style: TextStyle(color: Colors.red.shade700),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (!state.isInitialized && state.isLoading)
                const Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text('Initializing Face SDK...'),
                    ],
                  ),
                )
              else
                ElevatedButton(
                  onPressed: _isProcessing || !state.isInitialized ? null : _startLiveness,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                  ),
                  child: _isProcessing
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Start Face Verification',
                          style: TextStyle(fontSize: 18),
                        ),
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInstructionCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.indigo.shade100),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.indigo, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
