import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mrz_capture/mrz_capture.dart';
import 'package:vcmrtd/vcmrtd.dart';
import 'package:idem/l10n/l10n.dart';
import 'package:idem/providers/wallet_provider.dart';
import 'package:idem/widgets/common/button_styles.dart';

import 'submit_to_proofing_session.dart';
import 'web_banner.dart';

/// The page every document data screen (passport, driving licence) shares:
/// the step badge, the document's own [children], and adding the chip read
/// to the wallet - or, when it was sent to a proofing session step by step,
/// confirming that.
class DocumentDataView extends ConsumerWidget {
  final String title;
  final DocumentData document;
  final RawDocumentData rawDocument;
  final DocumentType documentType;

  /// The relying party every step was already sent to as it completed (see
  /// routing.dart's _submitNfcStep), or null for a scan without a session.
  final String? submittedTo;

  /// Whether the browser still does the face step after that.
  final bool browserFaceStep;
  final VoidCallback onBackPressed;
  final int stepNumber;
  final int totalSteps;
  final List<Widget> children;

  const DocumentDataView({
    super.key,
    required this.title,
    required this.document,
    required this.rawDocument,
    required this.documentType,
    required this.submittedTo,
    required this.browserFaceStep,
    required this.onBackPressed,
    required this.stepNumber,
    required this.totalSteps,
    required this.children,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionId = rawDocument.sessionId;
    final submittedTo = this.submittedTo;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            StepBadgeTopBar(
              icon: Icons.arrow_back,
              onBack: onBackPressed,
              current: stepNumber,
              total: totalSteps,
              label: title,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (sessionId != null) WebBanner(sessionId: sessionId),
                    ...children,
                    Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: submittedTo != null
                          ? SubmittedToProofingSessionSection(
                              relyingParty: submittedTo,
                              browserFaceStep: browserFaceStep,
                              onDone: onBackPressed,
                            )
                          : ElevatedButton.icon(
                              onPressed: () {
                                ref.read(walletProvider.notifier).add(WalletCard.fromDocument(document, documentType));
                                onBackPressed();
                              },
                              style: actionButtonStyle,
                              icon: const Icon(Icons.account_balance_wallet),
                              label: Text(context.l10n.proofingAddToWallet),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
