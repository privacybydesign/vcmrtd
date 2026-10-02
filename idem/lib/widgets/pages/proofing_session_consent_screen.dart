import 'dart:async';

import 'package:flutter/material.dart';
import 'package:idem/l10n/l10n.dart';
import 'package:idem/services/proofing_session_client.dart';
import 'package:idem/widgets/common/button_styles.dart';

/// Shown right after the app fetches a scanned/deep-linked proofing session,
/// before anything else happens: who's asking, what they want, and an
/// explicit accept/decline. Connecting to a relying party (routing.dart's
/// _handleScannedQr) no longer pins the session by itself — only [onConsent]
/// does that; declining leaves nothing pinned and nothing is ever sent.
class ProofingSessionConsentScreen extends StatefulWidget {
  final ProofingSessionInfo info;
  final VoidCallback onConsent;
  final VoidCallback onDecline;

  const ProofingSessionConsentScreen({super.key, required this.info, required this.onConsent, required this.onDecline});

  @override
  State<ProofingSessionConsentScreen> createState() => _ProofingSessionConsentScreenState();
}

class _ProofingSessionConsentScreenState extends State<ProofingSessionConsentScreen> {
  /// Keeps the countdown current, and disables Continue once it runs out.
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!widget.info.expiresAt.isAfter(DateTime.now())) timer.cancel();
      setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.info;
    final expiresIn = info.expiresAt.difference(DateTime.now());
    final expired = expiresIn.isNegative;
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.proofingConsentTitle)),
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
                        l10n.proofingConsentIntro,
                        style: TextStyle(fontSize: 15, color: Colors.grey[700], height: 1.4),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(l10n.proofingConsentRequesting, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final label in _requestedAttributeLabels(l10n, info.requestedAttributes))
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
                expired ? l10n.proofingConsentExpired : l10n.proofingConsentExpiresIn(_formatDuration(l10n, expiresIn)),
                style: TextStyle(fontSize: 13, color: expired ? Colors.red[700] : Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: expired ? null : widget.onConsent,
                icon: const Icon(Icons.check),
                label: Text(l10n.proofingContinue),
                style: actionButtonStyle,
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: widget.onDecline,
                icon: const Icon(Icons.close),
                label: Text(l10n.proofingDecline),
                style: actionButtonStyle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Map<String, String> _attributeLabels(AppLocalizations l10n) => {
  'dg1': l10n.proofingAttributeDocumentIdentity,
  'dg11': l10n.proofingAttributeAdditionalDetails,
  'dg2': l10n.proofingAttributeFacePhoto,
  'face_image': l10n.proofingAttributeFacePhoto,
  'chip_checks': l10n.proofingAttributeChipChecks,
  'biometrics': l10n.proofingAttributeBiometrics,
};

/// Deduplicates aliases (dg2/face_image mean the same thing server-side) and
/// falls back to the raw key for anything not in [_attributeLabels], so an
/// unrecognised future attribute is still shown rather than silently
/// dropped. An empty list means the relying party didn't restrict anything —
/// see identity-proofing-service's attrRequested.
List<String> _requestedAttributeLabels(AppLocalizations l10n, List<String> requested) {
  if (requested.isEmpty) return [l10n.proofingAttributeEverything];
  final attributeLabels = _attributeLabels(l10n);
  final labels = <String>{};
  for (final key in requested) {
    labels.add(attributeLabels[key] ?? key);
  }
  return labels.toList();
}

String _formatDuration(AppLocalizations l10n, Duration d) {
  if (d.inMinutes < 1) return l10n.proofingDurationLessThanMinute;
  if (d.inMinutes < 60) return l10n.proofingDurationMinutes(d.inMinutes);
  return l10n.proofingDurationHours(d.inHours);
}
