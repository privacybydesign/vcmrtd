import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vcmrtdapp/providers/facetec_verification_provider.dart';

/// Screen for capturing face with FaceTec 3D liveness check
class FaceTecCaptureScreen extends ConsumerStatefulWidget {
  final Uint8List? documentImage;
  final VoidCallback onBack;
  final Function(double matchScore)? onVerificationSuccess;
  final VoidCallback? onSkip;

  const FaceTecCaptureScreen({
    super.key,
    this.documentImage,
    required this.onBack,
    this.onVerificationSuccess,
    this.onSkip,
  });

  @override
  ConsumerState<FaceTecCaptureScreen> createState() =>
      _FaceTecCaptureScreenState();
}

class _FaceTecCaptureScreenState extends ConsumerState<FaceTecCaptureScreen> {
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    // Initialize FaceTec SDK after build phase
    Future.microtask(() => _initializeFaceTecSDK());
  }

  Future<void> _initializeFaceTecSDK() async {
    final notifier = ref.read(faceTecVerificationProvider.notifier);
    await notifier.initialize();
  }

  Future<void> _startLiveness() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    final notifier = ref.read(faceTecVerificationProvider.notifier);

    try {
      // Set document image if provided
      if (widget.documentImage != null) {
        notifier.setDocumentImage(widget.documentImage!);
      }

      // Start the liveness check
      final success = await notifier.startLiveness();

      if (!success) {
        if (mounted) {
          _showError("Failed to start liveness check. Please try again.");
        }
      } else {
        // NOTE: In a real implementation, the native code will call back
        // with the result after the FaceTec session completes.
        // For now, we'll simulate a successful match for demonstration.
        // You would need to implement the callback mechanism in native code
        // to get the actual liveness image and match score.

        // Simulate processing time
        await Future.delayed(const Duration(seconds: 2));

        if (mounted) {
          // For demonstration, show a simulated match result
          _showMatchResult(0.85); // Simulated 85% match
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
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'NOTE: This is a demonstration. FaceTec 3D liveness provides advanced anti-spoofing protection.',
                style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
              ),
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
    final state = ref.watch(faceTecVerificationProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('FaceTec Face Verification'),
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
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.face_retouching_natural,
                  size: 120,
                  color: Colors.deepPurple,
                ),
                const SizedBox(height: 32),
                const Text(
                  'FaceTec 3D Liveness Check',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  'We will verify that you are a real person using advanced 3D face scanning technology.',
                  style: TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'What to expect:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildFeatureItem(
                        '3D Face Scan',
                        'Advanced 3D scanning technology',
                      ),
                      _buildFeatureItem(
                        'Liveness Detection',
                        'Ensures you are physically present',
                      ),
                      _buildFeatureItem(
                        'Anti-Spoofing',
                        'Protection against photos and videos',
                      ),
                      _buildFeatureItem(
                        'Secure Matching',
                        'Compare against your document photo',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                if (state.isLoading)
                  const Center(
                    child: Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Initializing FaceTec SDK...'),
                      ],
                    ),
                  )
                else if (state.error != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error, color: Colors.red.shade700),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            state.error!,
                            style: TextStyle(color: Colors.red.shade900),
                          ),
                        ),
                      ],
                    ),
                  )
                else if (state.isProcessing || _isProcessing)
                  const Center(
                    child: Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Processing liveness check...'),
                      ],
                    ),
                  )
                else
                  ElevatedButton(
                    onPressed: state.isInitialized && !_isProcessing
                        ? _startLiveness
                        : null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(fontSize: 18),
                    ),
                    child: const Text('Start 3D Liveness Check'),
                  ),
                const SizedBox(height: 16),
                Text(
                  'Powered by FaceTec',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle,
            size: 16,
            color: Colors.green.shade700,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
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
