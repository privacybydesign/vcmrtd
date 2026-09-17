import 'package:flutter/material.dart';
import 'package:idem/services/proofing_session_client.dart';

/// Shown right after the app fetches a scanned/deep-linked proofing session,
/// before anything else happens: who's asking, what they want, and an
/// explicit accept/decline. Connecting to a relying party (routing.dart's
/// _handleScannedQr) no longer pins the session by itself — only [onConsent]
/// does that; declining leaves nothing pinned and nothing is ever sent.
class ProofingSessionConsentScreen extends StatelessWidget {
  final ProofingSessionInfo info;
  final VoidCallback onConsent;
  final VoidCallback onDecline;

  const ProofingSessionConsentScreen({super.key, required this.info, required this.onConsent, required this.onDecline});

  @override
  Widget build(BuildContext context) {
    final expiresIn = info.expiresAt.difference(DateTime.now());
    final expired = expiresIn.isNegative;

    return Scaffold(
      appBar: AppBar(title: const Text('Identity proofing request')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.verified_user, color: Colors.green, size: 28),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              info.relyingParty,
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'is requesting to verify your identity from a document. Scanning your document and '
                        'completing face verification will send the result below back to them.',
                        style: TextStyle(fontSize: 15, color: Colors.grey[700], height: 1.4),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('They are requesting:', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final label in _requestedAttributeLabels(info.requestedAttributes))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline, size: 20, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(child: Text(label)),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              Text(
                expired ? 'This request has expired.' : 'This request expires in ${_formatDuration(expiresIn)}.',
                style: TextStyle(fontSize: 13, color: expired ? Colors.red[700] : Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: expired ? null : onConsent,
                icon: const Icon(Icons.check),
                label: const Text('Continue'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: onDecline,
                icon: const Icon(Icons.close),
                label: const Text('Decline'),
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
      ),
    );
  }
}

const _attributeLabels = {
  'dg1': 'Document identity (name, date of birth, document number, expiry)',
  'dg11': 'Additional personal details (personal number, place of birth)',
  'dg2': 'Your face photo from the document chip',
  'face_image': 'Your face photo from the document chip',
  'chip_checks': 'Document authenticity checks',
  'biometrics': 'Face verification result',
};

/// Deduplicates aliases (dg2/face_image mean the same thing server-side) and
/// falls back to the raw key for anything not in [_attributeLabels], so an
/// unrecognised future attribute is still shown rather than silently
/// dropped. An empty list means the relying party didn't restrict anything —
/// see identity-proofing-service's attrRequested.
List<String> _requestedAttributeLabels(List<String> requested) {
  if (requested.isEmpty) return const ['Everything the app reads from your document'];
  final labels = <String>{};
  for (final key in requested) {
    labels.add(_attributeLabels[key] ?? key);
  }
  return labels.toList();
}

String _formatDuration(Duration d) {
  if (d.inMinutes < 1) return 'less than a minute';
  if (d.inMinutes < 60) return '${d.inMinutes} minute${d.inMinutes == 1 ? '' : 's'}';
  return '${d.inHours} hour${d.inHours == 1 ? '' : 's'}';
}
