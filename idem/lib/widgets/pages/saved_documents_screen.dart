import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:idem/l10n/l10n.dart';
import 'package:idem/providers/wallet_provider.dart';
import 'package:idem/widgets/guided/guided_widgets.dart';
import 'package:idem/widgets/pages/wallet_widgets.dart';

/// Guided layout, from settings: the documents kept on this phone, each of
/// which can be removed. They are offered again after scanning a QR code.
class SavedDocumentsScreen extends ConsumerWidget {
  const SavedDocumentsScreen({super.key, required this.onBack, required this.onScanQr});

  final VoidCallback onBack;
  final VoidCallback onScanQr;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.guided!;
    final l10n = context.l10n;
    final cards = ref.watch(walletProvider).reversed.toList();
    final date = DateFormat('d MMM y', l10n.localeName);
    final now = DateTime.now();
    String added(DateTime at) => at.year == now.year && at.month == now.month && at.day == now.day
        ? l10n.savedAddedToday
        : l10n.savedAddedOn(DateFormat('d MMM', l10n.localeName).format(at));

    return GuidedStatusBar(
      onDark: false,
      child: Scaffold(
        backgroundColor: g.surface,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GuidedTopBar(
                leading: GuidedRoundButton(icon: Icons.chevron_left, tooltip: l10n.docBack, onPressed: onBack),
                center: GuidedTopBarTitle(l10n.settingsSavedDocuments),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.savedCount(cards.length), style: g.heading(24, height: 1.25)),
                          const SizedBox(height: 10),
                          Text(
                            cards.isEmpty ? l10n.savedEmptyBody : l10n.savedBody,
                            style: TextStyle(fontSize: 15, height: 1.5, color: g.bodyText),
                          ),
                        ],
                      ),
                    ),
                    for (final card in cards) ...[
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: g.border),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: SizedBox(
                                      width: 48,
                                      height: 60,
                                      child: FittedBox(
                                        fit: BoxFit.cover,
                                        clipBehavior: Clip.hardEdge,
                                        child: WalletPhoto(
                                          imageData: card.photoImageData,
                                          imageType: card.photoImageType,
                                          size: 60,
                                        ),
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
                                        const SizedBox(height: 2),
                                        Text(
                                          [card.holderName, ?card.documentNumber].join(' · '),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(fontSize: 14, color: g.bodyText),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          [
                                            if (card.validUntil != null)
                                              l10n.savedValidUntil(date.format(card.validUntil!)),
                                            added(card.addedAt),
                                          ].join(' · '),
                                          style: TextStyle(fontSize: 13, color: g.muted),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Divider(height: 1, color: g.subtleBorder),
                            TextButton.icon(
                              onPressed: () => ref.read(walletProvider.notifier).remove(card.id),
                              style: TextButton.styleFrom(
                                foregroundColor: g.error,
                                minimumSize: const Size.fromHeight(44),
                                shape: const RoundedRectangleBorder(),
                                textStyle: Theme.of(
                                  context,
                                ).textTheme.labelLarge?.copyWith(fontSize: 14, fontWeight: FontWeight.w700),
                              ),
                              icon: const Icon(Icons.delete_outline, size: 18),
                              label: Text(l10n.savedRemove),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: guidedBottomButtonPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GuidedButton(label: l10n.docScanQrTitle, icon: Icons.qr_code_scanner, onPressed: onScanQr),
                    const SizedBox(height: 14),
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
