import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vcmrtd/vcmrtd.dart';
import 'package:idem/l10n/l10n.dart';
import 'package:idem/providers/wallet_provider.dart';
import 'package:idem/widgets/guided/guided_widgets.dart';
import 'package:idem/widgets/pages/wallet_widgets.dart';

/// Guided layout, after accepting a proofing request: pick a document saved on
/// this phone (then only the selfie check is left), or add a new one.
class ChooseDocumentScreen extends StatefulWidget {
  const ChooseDocumentScreen({
    super.key,
    required this.relyingParty,
    required this.savedDocuments,
    required this.onUseSaved,
    required this.onAddNew,
    required this.onBack,
  });

  final String relyingParty;

  /// Saved documents that can be shared again ([WalletCard.canBeReused]).
  final List<WalletCard> savedDocuments;
  final ValueChanged<WalletCard> onUseSaved;
  final ValueChanged<DocumentType> onAddNew;
  final VoidCallback onBack;

  @override
  State<ChooseDocumentScreen> createState() => _ChooseDocumentScreenState();
}

class _ChooseDocumentScreenState extends State<ChooseDocumentScreen> {
  String? _pickedId;

  WalletCard? get _picked {
    for (final card in widget.savedDocuments) {
      if (card.id == _pickedId) return card;
    }
    return widget.savedDocuments.isEmpty ? null : widget.savedDocuments.first;
  }

  @override
  Widget build(BuildContext context) {
    final g = context.guided!;
    final l10n = context.l10n;
    final saved = widget.savedDocuments;
    final picked = _picked;
    Widget sectionTitle(String text) => Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1.04, color: g.muted),
      ),
    );

    return GuidedStatusBar(
      onDark: false,
      child: Scaffold(
        backgroundColor: g.surface,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GuidedTopBar(
                leading: GuidedRoundButton(icon: Icons.chevron_left, tooltip: l10n.docBack, onPressed: widget.onBack),
                center: GuidedTopBarTitle(l10n.chooseTitle),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.chooseHeading, style: g.heading(24, height: 1.25)),
                            const SizedBox(height: 10),
                            Text(
                              saved.isEmpty
                                  ? l10n.chooseIntroEmpty(widget.relyingParty)
                                  : l10n.chooseIntroSaved(widget.relyingParty),
                              style: TextStyle(fontSize: 15, height: 1.5, color: g.bodyText),
                            ),
                          ],
                        ),
                      ),
                      if (saved.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        sectionTitle(l10n.chooseSavedOnPhone),
                        for (final (i, card) in saved.indexed) ...[
                          if (i > 0) const SizedBox(height: 10),
                          _SavedDocumentOption(
                            card: card,
                            selected: card.id == picked?.id,
                            onTap: () => setState(() => _pickedId = card.id),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.person_outline, size: 16, color: g.action),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  l10n.chooseSelfieHint,
                                  style: TextStyle(fontSize: 13, height: 1.45, color: g.bodyText),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      sectionTitle(saved.isEmpty ? l10n.chooseAddDocument : l10n.chooseAddNewDocument),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: g.subtleBorder),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            for (final (i, (type, icon)) in const [
                              (DocumentType.passport, Icons.portrait_outlined),
                              (DocumentType.identityCard, Icons.badge_outlined),
                              (DocumentType.drivingLicence, Icons.directions_car_outlined),
                            ].indexed) ...[
                              if (i > 0) Divider(height: 1, color: g.subtleBorder),
                              InkWell(
                                onTap: () => widget.onAddNew(type),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                                  child: Row(
                                    children: [
                                      Icon(icon, size: 20, color: g.slate),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          type.localizedName(l10n),
                                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: g.ink),
                                        ),
                                      ),
                                      Icon(Icons.add, size: 20, color: g.muted),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (picked != null)
                Padding(
                  padding: guidedBottomButtonPadding,
                  child: GuidedButton(
                    label: l10n.chooseContinueWith(picked.documentType.name),
                    onPressed: () => widget.onUseSaved(picked),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SavedDocumentOption extends StatelessWidget {
  const _SavedDocumentOption({required this.card, required this.selected, required this.onTap});

  final WalletCard card;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final g = context.guided!;
    final l10n = context.l10n;
    final details = [
      ?card.documentNumber,
      if (card.validUntil != null)
        l10n.chooseValidUntil(DateFormat('d MMM y', l10n.localeName).format(card.validUntil!)),
    ].join(' · ');
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: selected ? BorderSide(color: g.action, width: 2) : BorderSide(color: g.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(selected ? 13 : 14),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 44,
                    height: 56,
                    child: FittedBox(
                      fit: BoxFit.cover,
                      clipBehavior: Clip.hardEdge,
                      child: WalletPhoto(imageData: card.photoImageData, imageType: card.photoImageType, size: 56),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.documentType.localizedName(l10n),
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: g.ink),
                      ),
                      if (details.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(details, style: TextStyle(fontSize: 14, color: g.bodyText)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: selected
                        ? Border.all(color: g.action, width: 7)
                        : Border.all(color: g.placeholder, width: 2),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
