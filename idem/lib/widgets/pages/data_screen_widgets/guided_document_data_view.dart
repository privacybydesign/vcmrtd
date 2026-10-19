import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vcmrtd/vcmrtd.dart';
import 'package:idem/l10n/l10n.dart';
import 'package:idem/providers/wallet_provider.dart';
import 'package:idem/widgets/guided/guided_widgets.dart';

import 'profile_picture.dart';
import 'submit_to_proofing_session.dart';
import 'web_banner.dart';

/// One labelled value in the guided details card.
class GuidedDetail {
  final String label;
  final String? value;
  final bool mono;

  const GuidedDetail(this.label, this.value, {this.mono = false});
}

/// Guided layout of the document data screen: a success header, the key
/// details in one card, and either "add to wallet" or, when every step was
/// already sent to a session, "save for next time" with a confirmation or,
/// still to be shared, "Share with ...".
/// Says the chip was read rather than that it's genuine: authenticity is
/// checked by the backend, not on the phone.
class GuidedDocumentDataView extends ConsumerStatefulWidget {
  final DocumentData document;
  final RawDocumentData rawDocument;
  final DocumentType documentType;
  final String? submittedTo;
  final PendingStep pendingStep;
  final VoidCallback onBackPressed;

  /// Submits the session; set for [PendingStep.share].
  final Future<bool> Function()? onShare;

  /// The header when nothing was sent to a session, e.g. "Document read".
  final String readTitle;
  final Uint8List photoImageData;
  final ImageType photoImageType;
  final String holderName;
  final String subtitle;
  final List<GuidedDetail> details;

  /// Anything shown below the details card, such as licence categories.
  final List<Widget> extra;

  const GuidedDocumentDataView({
    super.key,
    required this.document,
    required this.rawDocument,
    required this.documentType,
    required this.submittedTo,
    required this.pendingStep,
    required this.onBackPressed,
    this.onShare,
    required this.readTitle,
    required this.photoImageData,
    required this.photoImageType,
    required this.holderName,
    required this.subtitle,
    required this.details,
    this.extra = const [],
  });

  @override
  ConsumerState<GuidedDocumentDataView> createState() => _GuidedDocumentDataViewState();
}

class _GuidedDocumentDataViewState extends ConsumerState<GuidedDocumentDataView> {
  bool _saveForNextTime = false;
  bool _sharing = false;

  void _addToWallet() => _addTo(ref.read(walletProvider.notifier));

  void _addTo(WalletNotifier wallet) =>
      wallet.add(WalletCard.fromDocument(widget.document, widget.documentType, rawData: widget.rawDocument));

  /// Saves the document only once the share went through; the notifier is
  /// read up front, as completing the session navigates away from here.
  Future<void> _share() async {
    final wallet = ref.read(walletProvider.notifier);
    final save = _saveForNextTime;
    setState(() => _sharing = true);
    final shared = await widget.onShare!();
    if (shared && save) _addTo(wallet);
    if (mounted) setState(() => _sharing = false);
  }

  @override
  Widget build(BuildContext context) {
    final g = context.guided!;
    final submittedTo = widget.submittedTo;
    final share = widget.pendingStep == PendingStep.share && widget.onShare != null;
    final sessionId = widget.rawDocument.sessionId;

    Widget detail(GuidedDetail d, {bool last = false}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: g.subtleBorder)),
      ),
      child: Row(
        children: [
          Text(d.label, style: TextStyle(fontSize: 15, color: g.bodyText)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              d.value ?? '—',
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: d.mono ? 14 : 15,
                fontWeight: FontWeight.w700,
                color: g.ink,
                fontFamily: d.mono ? 'monospace' : null,
              ),
            ),
          ),
        ],
      ),
    );

    return GuidedStatusBar(
      onDark: false,
      child: Scaffold(
        backgroundColor: g.surface,
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 40, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (sessionId != null) ...[WebBanner(sessionId: sessionId), const SizedBox(height: 16)],
                      Center(
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: g.success,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: g.successBright.withValues(alpha: 0.2), spreadRadius: 10)],
                          ),
                          child: const Icon(Icons.check, size: 36, color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        share
                            ? context.l10n.proofingVerifiedTitle
                            : submittedTo != null
                            ? context.l10n.proofingSentTo(submittedTo)
                            : widget.readTitle,
                        textAlign: TextAlign.center,
                        style: g.heading(26),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        switch ((submittedTo, widget.pendingStep)) {
                          (null, _) => context.l10n.dataViewChipRead(widget.documentType.name),
                          (final rp?, PendingStep.browserFace) => context.l10n.proofingSentBrowserFace(rp),
                          (final rp?, PendingStep.share) => context.l10n.proofingShareBody(rp),
                          (final rp?, PendingStep.none) => context.l10n.proofingSentEverything(rp),
                        },
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 15, height: 1.5, color: g.bodyText),
                      ),
                      const SizedBox(height: 28),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: g.subtleBorder),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              color: g.header,
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: SizedBox(
                                      width: 56,
                                      height: 70,
                                      child: FittedBox(
                                        fit: BoxFit.cover,
                                        clipBehavior: Clip.hardEdge,
                                        child: ProfilePictureWidget(
                                          imageData: widget.photoImageData,
                                          imageType: widget.photoImageType,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(widget.holderName, style: g.heading(17, color: Colors.white)),
                                        const SizedBox(height: 2),
                                        Text(widget.subtitle, style: TextStyle(fontSize: 13, color: g.placeholder)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            for (final (i, d) in widget.details.indexed)
                              detail(d, last: i == widget.details.length - 1),
                          ],
                        ),
                      ),
                      ...widget.extra,
                      const Spacer(),
                      const SizedBox(height: 24),
                      if (share) ...[
                        GuidedSaveForNextTime(
                          value: _saveForNextTime,
                          onChanged: (value) => setState(() => _saveForNextTime = value),
                        ),
                        const SizedBox(height: 16),
                        GuidedButton(
                          label: _sharing
                              ? context.l10n.proofingSharing
                              : context.l10n.proofingShareWith(submittedTo ?? ''),
                          onPressed: _sharing ? null : _share,
                        ),
                      ] else if (submittedTo != null) ...[
                        GuidedSaveForNextTime(
                          value: _saveForNextTime,
                          onChanged: (value) => setState(() => _saveForNextTime = value),
                        ),
                        const SizedBox(height: 16),
                        GuidedButton(
                          label: context.l10n.proofingDone,
                          onPressed: () {
                            if (_saveForNextTime) _addToWallet();
                            widget.onBackPressed();
                          },
                        ),
                      ] else ...[
                        GuidedButton(
                          label: context.l10n.dataViewAddToWallet,
                          onPressed: () {
                            _addToWallet();
                            widget.onBackPressed();
                          },
                        ),
                        const SizedBox(height: 12),
                        GuidedButton(
                          label: context.l10n.proofingDone,
                          secondary: true,
                          onPressed: widget.onBackPressed,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
