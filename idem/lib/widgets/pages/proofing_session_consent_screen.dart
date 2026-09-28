import 'package:flutter/material.dart';
import 'package:idem/l10n/l10n.dart';
import 'package:idem/services/proofing_session_client.dart';
import 'package:idem/theme/brand_theme.dart';
import 'package:idem/widgets/guided/guided_widgets.dart';

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
    final guided = context.guided;
    if (guided != null) return _buildGuided(context, guided, expiresIn: expiresIn, expired: expired);
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
                          Icon(Icons.verified_user, color: context.brand.success ?? Colors.green, size: 28),
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
                      Icon(Icons.check_circle_outline, size: 20, color: context.brand.success ?? Colors.green),
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
                onPressed: expired ? null : onConsent,
                icon: const Icon(Icons.check),
                label: Text(l10n.proofingContinue),
                style:
                    context.brand.primaryButtonStyle ??
                    ElevatedButton.styleFrom(
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
                label: Text(l10n.proofingDecline),
                style:
                    context.brand.secondaryButtonStyle ??
                    ElevatedButton.styleFrom(
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

extension on ProofingSessionConsentScreen {
  /// Guided layout: who is asking, a list of what they'll receive, and the
  /// two choices. Shows the brand mark only when the brand itself is asking.
  Widget _buildGuided(BuildContext context, GuidedStyle g, {required Duration expiresIn, required bool expired}) {
    final brand = context.brand;
    final l10n = context.l10n;
    final party = info.relyingParty;
    final isBrand = party.toLowerCase().contains(brand.appBarTitle.toLowerCase());
    return GuidedStatusBar(
      onDark: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GuidedTopBar(
                leading: GuidedRoundButton(icon: Icons.close, tooltip: l10n.proofingDecline, onPressed: onDecline),
                center: const GuidedTopBarTitle('Request'),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 32, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 88,
                          height: 88,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: g.actionTint.withValues(alpha: 0.5),
                            border: Border.all(color: g.actionTintStrong),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: isBrand
                              ? Image.asset(g.markAsset, width: 56, height: 56, excludeFromSemantics: true)
                              : Text(
                                  party.isEmpty ? '?' : party[0].toUpperCase(),
                                  style: g.heading(36, color: g.action),
                                ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        '$party wants to verify your identity',
                        textAlign: TextAlign.center,
                        style: g.heading(24, height: 1.25),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        expired
                            ? l10n.proofingConsentExpired
                            : l10n.proofingConsentExpiresIn(_formatDuration(l10n, expiresIn)),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: expired ? const Color(0xFFD1293D) : g.bodyText,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        'They will receive',
                        style: g.heading(16, weight: FontWeight.w600, color: g.slate),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: g.subtleBorder),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            for (final (i, (icon, label)) in _requestedAttributes(
                              l10n,
                              info.requestedAttributes,
                            ).indexed)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                decoration: BoxDecoration(
                                  border: i == 0 ? null : Border(top: BorderSide(color: g.subtleBorder)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(icon, size: 20, color: g.action),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        label,
                                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: g.ink),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GuidedButton(label: l10n.proofingContinue, onPressed: expired ? null : onConsent),
                    const SizedBox(height: 12),
                    GuidedButton(label: l10n.proofingDecline, secondary: true, onPressed: onDecline),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const _attributeIcons = {
  'dg1': Icons.badge_outlined,
  'dg11': Icons.person_outline,
  'dg2': Icons.portrait_outlined,
  'face_image': Icons.portrait_outlined,
  'chip_checks': Icons.verified_user_outlined,
  'biometrics': Icons.face,
};

/// [_requestedAttributeLabels] with an icon per entry, for the guided list.
List<(IconData, String)> _requestedAttributes(AppLocalizations l10n, List<String> requested) {
  if (requested.isEmpty) return [(Icons.list_alt, _requestedAttributeLabels(l10n, requested).single)];
  final attributeLabels = _attributeLabels(l10n);
  final seen = <String>{};
  return [
    for (final key in requested)
      if (seen.add(attributeLabels[key] ?? key))
        (_attributeIcons[key] ?? Icons.check_circle_outline, attributeLabels[key] ?? key),
  ];
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
