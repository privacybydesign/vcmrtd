import 'package:flutter/material.dart';

import '../models/comparison_result.dart';

/// Widget to display face verification results.
class VerificationResultWidget extends StatelessWidget {
  /// The comparison result to display.
  final FaceComparisonResult result;

  /// Callback when user wants to retry verification.
  final VoidCallback? onRetry;

  /// Callback when user confirms/dismisses the result.
  final VoidCallback? onConfirm;

  /// Custom success message.
  final String? successMessage;

  /// Custom failure message.
  final String? failureMessage;

  const VerificationResultWidget({
    super.key,
    required this.result,
    this.onRetry,
    this.onConfirm,
    this.successMessage,
    this.failureMessage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSuccess = result.match && result.passedLivenessCheck;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildIcon(isSuccess),
          const SizedBox(height: 16),
          _buildTitle(context, isSuccess),
          const SizedBox(height: 8),
          _buildMessage(context, isSuccess),
          if (result.isSuccessful) ...[
            const SizedBox(height: 16),
            _buildSimilarityScore(context),
          ],
          if (!isSuccess) ...[
            const SizedBox(height: 12),
            _buildErrorDetails(context),
          ],
          const SizedBox(height: 24),
          _buildButtons(context, isSuccess),
        ],
      ),
    );
  }

  Widget _buildIcon(bool isSuccess) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSuccess ? Colors.green.shade50 : Colors.red.shade50,
      ),
      child: Icon(
        isSuccess ? Icons.check_circle : Icons.cancel,
        size: 48,
        color: isSuccess ? Colors.green : Colors.red,
      ),
    );
  }

  Widget _buildTitle(BuildContext context, bool isSuccess) {
    return Text(
      isSuccess ? 'Verification Successful' : 'Verification Failed',
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: isSuccess ? Colors.green.shade700 : Colors.red.shade700,
          ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildMessage(BuildContext context, bool isSuccess) {
    final message = isSuccess
        ? (successMessage ?? 'Your identity has been verified.')
        : (failureMessage ?? 'Unable to verify your identity.');

    return Text(
      message,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.grey.shade600,
          ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildSimilarityScore(BuildContext context) {
    final similarity = result.similarityPercentage;
    if (similarity == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.analytics_outlined,
            size: 20,
            color: Colors.grey.shade600,
          ),
          const SizedBox(width: 8),
          Text(
            'Similarity: ${similarity.toStringAsFixed(1)}%',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorDetails(BuildContext context) {
    final errors = <String>[];

    if (!result.statusImage1.isOverallOk) {
      errors.addAll(result.statusImage1.errorMessages);
    }
    if (!result.statusImage2.isOverallOk) {
      errors.addAll(result.statusImage2.errorMessages
          .map((e) => '$e (reference image)'));
    }
    if (!result.passedLivenessCheck) {
      errors.add('Liveness check failed');
    }

    if (errors.isEmpty && !result.match && result.isSuccessful) {
      errors.add('Faces do not match');
    }

    if (errors.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: Colors.orange.shade700),
              const SizedBox(width: 8),
              Text(
                'Details:',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ...errors.map((e) => Padding(
                padding: const EdgeInsets.only(left: 24, top: 2),
                child: Text(
                  '• $e',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.orange.shade700,
                      ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildButtons(BuildContext context, bool isSuccess) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (!isSuccess && onRetry != null) ...[
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
          ),
          const SizedBox(width: 12),
        ],
        if (onConfirm != null)
          ElevatedButton(
            onPressed: onConfirm,
            style: ElevatedButton.styleFrom(
              backgroundColor: isSuccess ? Colors.green : null,
              foregroundColor: isSuccess ? Colors.white : null,
            ),
            child: Text(isSuccess ? 'Continue' : 'Close'),
          ),
      ],
    );
  }
}

/// Widget for displaying liveness check status during verification.
class LivenessStatusWidget extends StatelessWidget {
  /// Whether liveness check is in progress.
  final bool isChecking;

  /// Whether liveness check passed.
  final bool? passed;

  const LivenessStatusWidget({
    super.key,
    this.isChecking = false,
    this.passed,
  });

  @override
  Widget build(BuildContext context) {
    Widget icon;
    String text;
    Color color;

    if (isChecking) {
      icon = const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
      text = 'Checking liveness...';
      color = Colors.blue;
    } else if (passed == true) {
      icon = const Icon(Icons.verified, size: 16, color: Colors.green);
      text = 'Liveness verified';
      color = Colors.green;
    } else if (passed == false) {
      icon = const Icon(Icons.warning, size: 16, color: Colors.orange);
      text = 'Liveness check failed';
      color = Colors.orange;
    } else {
      icon = const Icon(Icons.person_outline, size: 16, color: Colors.grey);
      text = 'Liveness pending';
      color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
