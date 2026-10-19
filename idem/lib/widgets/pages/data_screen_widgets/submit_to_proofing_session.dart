import 'package:flutter/material.dart';
import 'package:idem/l10n/l10n.dart';
import 'package:idem/widgets/common/button_styles.dart';
import 'package:idem/theme/brand_theme.dart';

/// What the session still waits for once this app sent every step it
/// performs.
enum PendingStep {
  /// Nothing: every step is in.
  none,

  /// The face step, which the browser runs.
  browserFace,

  /// The user's go-ahead: every step is in, the session is submitted when
  /// they tap Share.
  share,
}

/// Shown on the document data screen when every step was already sent to
/// the session as it completed, so there's nothing left to submit - just a
/// confirmation.
class SubmittedToProofingSessionSection extends StatefulWidget {
  final String relyingParty;
  final PendingStep pendingStep;
  final VoidCallback onDone;

  /// Submits the session; set for [PendingStep.share].
  final Future<bool> Function()? onShare;

  const SubmittedToProofingSessionSection({
    super.key,
    required this.relyingParty,
    required this.pendingStep,
    required this.onDone,
    this.onShare,
  });

  @override
  State<SubmittedToProofingSessionSection> createState() => _SubmittedToProofingSessionSectionState();
}

class _SubmittedToProofingSessionSectionState extends State<SubmittedToProofingSessionSection> {
  bool _sharing = false;

  Future<void> _share() async {
    setState(() => _sharing = true);
    await widget.onShare!();
    if (mounted) setState(() => _sharing = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final relyingParty = widget.relyingParty;
    final style = context.brand.primaryButtonStyle ?? actionButtonStyle;
    final share = widget.pendingStep == PendingStep.share && widget.onShare != null;
    return _ProofingCard(
      icon: Icons.check_circle,
      title: share ? l10n.proofingVerifiedTitle : l10n.proofingSentTo(relyingParty),
      body: switch (widget.pendingStep) {
        PendingStep.browserFace => l10n.proofingSentBrowserFace(relyingParty),
        PendingStep.share => l10n.proofingShareBody(relyingParty),
        PendingStep.none => l10n.proofingSentEverything(relyingParty),
      },
      action: share
          ? ElevatedButton(
              onPressed: _sharing ? null : _share,
              style: style,
              child: Text(_sharing ? l10n.proofingSharing : l10n.proofingShareWith(relyingParty)),
            )
          : ElevatedButton(onPressed: widget.onDone, style: style, child: Text(l10n.proofingDone)),
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
                Icon(icon, color: context.brand.success ?? Colors.green, size: 28),
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
