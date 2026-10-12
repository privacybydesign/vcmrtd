import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:idem/l10n/l10n.dart';
import 'package:idem/widgets/common/button_styles.dart';

/// The layouts every face-verification engine's screen shares (Regula,
/// Iris): the intro before the scan starts, a busy state while it runs, and
/// the result.

/// What the scan is about to do, as numbered [steps], and a start button.
class FaceIntroView extends StatelessWidget {
  final String title;
  final String body;
  final List<String> steps;
  final VoidCallback onStart;

  const FaceIntroView({super.key, required this.title, required this.body, required this.steps, required this.onStart});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.verified_user, size: 64, color: Colors.green),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.faceIrisWhatToExpect, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                for (var i = 0; i < steps.length; i++) ...[
                  SizedBox(height: i == 0 ? 10 : 6),
                  _IntroStepRow(number: '${i + 1}', text: steps[i]),
                ],
              ],
            ),
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: onStart,
            style: actionButtonStyle,
            icon: const Icon(Icons.face),
            label: Text(l10n.faceStartVerification),
          ),
        ],
      ),
    );
  }
}

class _IntroStepRow extends StatelessWidget {
  final String number;
  final String text;
  const _IntroStepRow({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 18,
          height: 18,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: Colors.black12, shape: BoxShape.circle),
          child: Text(number, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
      ],
    );
  }
}

/// A spinner with what is happening meanwhile.
class FaceBusyView extends StatelessWidget {
  final String label;
  const FaceBusyView({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [const CircularProgressIndicator(), const SizedBox(height: 16), Text(label)],
      ),
    );
  }
}

/// A scan's outcome, with the compared photos when there are any. With
/// [onRetry] the user can scan again; without it the screen is about to
/// continue on its own.
class FaceResultView extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final Uint8List? documentPhoto;
  final Uint8List? liveFace;
  final VoidCallback? onRetry;
  final String? retryLabel;

  const FaceResultView({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.documentPhoto,
    this.liveFace,
    this.onRetry,
    this.retryLabel,
  });

  @override
  Widget build(BuildContext context) {
    final documentPhoto = this.documentPhoto;
    final liveFace = this.liveFace;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(icon, size: 80, color: color),
          const SizedBox(height: 24),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
          if (documentPhoto != null || liveFace != null) ...[
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (documentPhoto != null) _Thumbnail(label: context.l10n.faceDocumentPhoto, bytes: documentPhoto),
                if (documentPhoto != null && liveFace != null) const SizedBox(width: 16),
                if (liveFace != null) _Thumbnail(label: context.l10n.faceLiveCapture, bytes: liveFace),
              ],
            ),
          ],
          const SizedBox(height: 32),
          if (onRetry != null)
            OutlinedButton(onPressed: onRetry, child: Text(retryLabel ?? context.l10n.faceTryAgain))
          else
            Center(
              child: Text(context.l10n.faceContinuing, style: const TextStyle(color: Colors.grey)),
            ),
        ],
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  final String label;
  final Uint8List bytes;
  const _Thumbnail({required this.label, required this.bytes});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(bytes, width: 100, height: 100, fit: BoxFit.cover),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}
