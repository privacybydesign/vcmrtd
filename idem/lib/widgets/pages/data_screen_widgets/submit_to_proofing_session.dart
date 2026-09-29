import 'package:flutter/material.dart';
import 'package:idem/l10n/l10n.dart';
import 'package:idem/widgets/common/button_styles.dart';

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
    return _ProofingCard(
      icon: Icons.verified_user,
      title: context.l10n.proofingSessionSectionTitle,
      body: context.l10n.proofingSubmitSectionBody(relyingParty),
      action: ElevatedButton.icon(
        onPressed: isSubmitting ? null : onSubmit,
        icon: isSubmitting
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.send),
        label: Text(isSubmitting ? context.l10n.proofingSubmitting : context.l10n.proofingSubmitTo(relyingParty)),
        style: actionButtonStyle,
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
  final VoidCallback onDone;

  const SubmittedToProofingSessionSection({
    super.key,
    required this.relyingParty,
    required this.browserFaceStep,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return _ProofingCard(
      icon: Icons.check_circle,
      title: context.l10n.proofingSentTo(relyingParty),
      body: browserFaceStep
          ? context.l10n.proofingSentBrowserFace(relyingParty)
          : context.l10n.proofingSentEverything(relyingParty),
      action: ElevatedButton(onPressed: onDone, style: actionButtonStyle, child: Text(context.l10n.proofingDone)),
    );
  }
}

/// A proofing-session card: a green-iconed title, an explanation and one
/// action.
class _ProofingCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Widget action;

  const _ProofingCard({required this.icon, required this.title, required this.body, required this.action});

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
                Icon(icon, color: Colors.green, size: 28),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(
                      context,
                    ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                ),
              ],
            ),
            const Divider(height: 30),
            Text(body, style: TextStyle(fontSize: 15, color: Colors.grey[700], height: 1.4)),
            const SizedBox(height: 16),
            action,
          ],
        ),
      ),
    );
  }
}
