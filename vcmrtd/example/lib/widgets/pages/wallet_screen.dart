import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vcmrtd/vcmrtd.dart';
import 'package:vcmrtdapp/providers/wallet_provider.dart';

/// Lists the documents added via "Add to Wallet". Example-app-only: cards
/// live in memory ([walletProvider]), so this list is empty again after a
/// restart — there is no real wallet or issuance backend behind it.
class WalletScreen extends ConsumerWidget {
  final VoidCallback onBackPressed;

  const WalletScreen({super.key, required this.onBackPressed});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = ref.watch(walletProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet'),
        leading: IconButton(tooltip: 'Back', icon: const Icon(Icons.arrow_back), onPressed: onBackPressed),
      ),
      body: cards.isEmpty ? const _EmptyWallet() : _WalletList(cards: cards),
    );
  }
}

class _EmptyWallet extends StatelessWidget {
  const _EmptyWallet();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_balance_wallet_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text('Your wallet is empty', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              'Scan a document and tap "Add to Wallet" to see it here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}

class _WalletList extends ConsumerWidget {
  final List<WalletCard> cards;
  const _WalletList({required this.cards});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: cards.length,
      itemBuilder: (context, index) {
        final card = cards[cards.length - 1 - index]; // most recently added first
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _WalletCardTile(card: card, onRemove: () => ref.read(walletProvider.notifier).remove(card.id)),
        );
      },
    );
  }
}

class _WalletCardTile extends StatelessWidget {
  final WalletCard card;
  final VoidCallback onRemove;
  const _WalletCardTile({required this.card, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(card.photoImageData, width: 56, height: 56, fit: BoxFit.cover),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(card.holderName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    card.documentNumber != null
                        ? '${card.documentType.displayName} · ${card.documentNumber}'
                        : card.documentType.displayName,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            IconButton(tooltip: 'Remove', icon: const Icon(Icons.delete_outline), onPressed: onRemove),
          ],
        ),
      ),
    );
  }
}
