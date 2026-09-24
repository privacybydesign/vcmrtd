import 'package:flutter/material.dart';

/// Shown on the document data screen when the current scan was handed off
/// from a relying party's browser session (see routing.dart's QR handling
/// and providers/proofing_session_provider.dart). Reaching this screen at
/// all already means NFC reading and the mandatory on-device face
/// verification step both succeeded, so there's nothing left to decide here
/// — just a single action to report that back.
class SubmitToProofingSessionSection extends StatelessWidget {
  final String relyingParty;
  final bool isSubmitting;
  final VoidCallback onSubmit;

  const SubmitToProofingSessionSection({
    super.key,
    required this.relyingParty,
    required this.isSubmitting,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.verified_user, color: Colors.green, size: 28),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Identity proofing session',
                    style: Theme.of(
                      context,
                    ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                ),
              ],
            ),
            const Divider(height: 30),
            Text(
              'This scan is for a session opened by $relyingParty. Send the document identity and '
              'face verification result back to them.',
              style: TextStyle(fontSize: 15, color: Colors.grey[700], height: 1.4),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: isSubmitting ? null : onSubmit,
              icon: isSubmitting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send),
              label: Text(isSubmitting ? 'Submitting...' : 'Submit to $relyingParty'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown on the document data screen instead of [SubmitToProofingSessionSection]
/// when every step was already sent to the session as it completed, so
/// there's nothing left to submit - just a confirmation.
class SubmittedToProofingSessionSection extends StatelessWidget {
  final String relyingParty;
  final bool browserFaceStep;
  final VoidCallback? onDone;

  const SubmittedToProofingSessionSection({
    super.key,
    required this.relyingParty,
    this.browserFaceStep = false,
    this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 28),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Sent to $relyingParty',
                    style: Theme.of(
                      context,
                    ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                ),
              ],
            ),
            const Divider(height: 30),
            Text(
              browserFaceStep
                  ? 'Your document identity was sent to $relyingParty. Finish face verification in the browser '
                        'tab where you started this session.'
                  : 'Everything this verification needed from this device was sent to $relyingParty.',
              style: TextStyle(fontSize: 15, color: Colors.grey[700], height: 1.4),
            ),
            if (onDone != null) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onDone,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Done'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
