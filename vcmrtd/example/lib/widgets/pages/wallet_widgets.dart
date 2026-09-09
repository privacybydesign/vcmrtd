import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vcmrtd/vcmrtd.dart';
import 'package:vcmrtdapp/providers/wallet_provider.dart';
import 'package:vcmrtdapp/services/jpeg2000_converter.dart';

/// Reusable pieces for showing the in-app "wallet" (the documents added via
/// "Add to Wallet") on the document type selection / home screen.
///
/// Example-app-only: cards live in memory ([walletProvider]), so this list is
/// empty again after a restart — there is no real wallet or issuance backend
/// behind it.
class WalletEmptyState extends StatelessWidget {
  const WalletEmptyState({super.key});

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

class WalletList extends ConsumerWidget {
  final List<WalletCard> cards;
  const WalletList({super.key, required this.cards});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: cards.length,
      itemBuilder: (context, index) {
        final card = cards[cards.length - 1 - index]; // most recently added first
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: WalletCardTile(
            card: card,
            onTap: () =>
                showWalletCardDetails(context, card, onRemove: () => ref.read(walletProvider.notifier).remove(card.id)),
          ),
        );
      },
    );
  }
}

class WalletCardTile extends StatelessWidget {
  final WalletCard card;
  final VoidCallback onTap;
  const WalletCardTile({super.key, required this.card, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: WalletPhoto(imageData: card.photoImageData, imageType: card.photoImageType, size: 56),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.holderName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      card.documentNumber != null
                          ? '${card.documentType.displayName} · ${card.documentNumber}'
                          : card.documentType.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shows the full details of a single wallet card in a bottom sheet, with the
/// option to remove it from the wallet.
void showWalletCardDetails(BuildContext context, WalletCard card, {required VoidCallback onRemove}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (sheetContext) => _WalletCardDetailsSheet(
      card: card,
      onRemove: () {
        onRemove();
        Navigator.of(sheetContext).pop();
      },
    ),
  );
}

class _WalletCardDetailsSheet extends StatelessWidget {
  final WalletCard card;
  final VoidCallback onRemove;
  const _WalletCardDetailsSheet({required this.card, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: WalletPhoto(imageData: card.photoImageData, imageType: card.photoImageType, size: 120),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              card.holderName,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              card.documentType.displayName,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),
            if (card.documentNumber != null) _DetailRow(label: 'Document number', value: card.documentNumber!),
            _DetailRow(label: 'Added', value: _formatAddedAt(card.addedAt)),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: onRemove,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Remove from wallet'),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatAddedAt(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }
}

/// A wallet card's photo, sized to a fixed square. Handles JPEG2000 (the
/// format most passport/DL chips actually store the photo in, which
/// Image.memory cannot decode) by converting it via the native
/// jpeg2000_converter service, same as [ProfilePictureWidget] does elsewhere.
class WalletPhoto extends StatefulWidget {
  final Uint8List imageData;
  final ImageType? imageType;
  final double size;

  const WalletPhoto({super.key, required this.imageData, required this.imageType, required this.size});

  @override
  State<WalletPhoto> createState() => _WalletPhotoState();
}

class _WalletPhotoState extends State<WalletPhoto> {
  Uint8List? _converted;
  bool _converting = false;

  @override
  void initState() {
    super.initState();
    if (widget.imageType == ImageType.jpeg2000) _convert();
  }

  Future<void> _convert() async {
    setState(() => _converting = true);
    final result = await decodeImage(widget.imageData, context);
    if (!mounted) return;
    setState(() {
      _converted = result;
      _converting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bytes = widget.imageType == ImageType.jpeg2000 ? _converted : widget.imageData;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: bytes == null
          ? Container(
              color: Colors.grey[200],
              child: Center(
                child: _converting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(Icons.person, color: Colors.grey[400]),
              ),
            )
          : Image.memory(
              bytes,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: Colors.grey[200],
                child: Center(child: Icon(Icons.person, color: Colors.grey[400])),
              ),
            ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
