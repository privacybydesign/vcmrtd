import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:idem/providers/wallet_provider.dart';
import 'package:idem/widgets/guided/guided_widgets.dart';
import 'package:idem/widgets/pages/choose_document_screen.dart';
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
    final cards = ref.watch(walletProvider).reversed.toList();
    final date = DateFormat('d MMM y');
    final now = DateTime.now();
    String added(DateTime at) => at.year == now.year && at.month == now.month && at.day == now.day
        ? 'added today'
        : 'added ${DateFormat('d MMM').format(at)}';

    return GuidedStatusBar(
      onDark: false,
      child: Scaffold(
        backgroundColor: g.surface,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GuidedTopBar(
                leading: GuidedRoundButton(icon: Icons.chevron_left, tooltip: 'Back', onPressed: onBack),
                center: const GuidedTopBarTitle('Saved documents'),
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
                          Text(switch (cards.length) {
                            0 => 'No documents on this phone',
                            1 => '1 document on this phone',
                            final n => '$n documents on this phone',
                          }, style: g.heading(24, height: 1.25)),
                          const SizedBox(height: 10),
                          Text(
                            cards.isEmpty
                                ? 'After you share a document, you can save it here so you don’t have to scan it again.'
                                : 'When you scan a QR code, you can pick one of these instead of scanning your ID again. '
                                      'They are only shared when you agree.',
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
                                          guidedDocumentTypeName(card.documentType),
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
                                            if (card.validUntil != null) 'Valid until ${date.format(card.validUntil!)}',
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
                                foregroundColor: const Color(0xFFB3261E),
                                minimumSize: const Size.fromHeight(44),
                                shape: const RoundedRectangleBorder(),
                                textStyle: Theme.of(
                                  context,
                                ).textTheme.labelLarge?.copyWith(fontSize: 14, fontWeight: FontWeight.w700),
                              ),
                              icon: const Icon(Icons.delete_outline, size: 18),
                              label: const Text('Remove from this phone'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GuidedButton(label: 'Scan QR code', icon: Icons.qr_code_scanner, onPressed: onScanQr),
                    const SizedBox(height: 14),
                    Text(
                      'Powered by Idem',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: g.muted),
                    ),
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
