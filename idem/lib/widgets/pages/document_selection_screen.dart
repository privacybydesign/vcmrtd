import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vcmrtd/vcmrtd.dart';
import 'package:idem/providers/proofing_session_provider.dart';
import 'package:idem/providers/wallet_provider.dart';
import 'package:idem/theme/text_styles.dart';
import 'package:idem/widgets/pages/wallet_widgets.dart';

/// Home screen: shows the scanning options when the wallet is empty, or just
/// the wallet when it holds at least one card — a new scan is then started
/// via the "+" button in the app bar. The QR scan and advanced settings
/// entries are always shown at the bottom, in both states — except QR scan,
/// hidden once a proofing session is already connected (see the app bar
/// banner below): scanning another QR while one is pinned doesn't make
/// sense, and there's nothing to gain from offering it.
class DocumentTypeSelectionScreen extends ConsumerWidget {
  final Function(DocumentType) onDocumentTypeSelected;
  final VoidCallback onSettingsPressed;
  final VoidCallback onScanQrPressed;

  const DocumentTypeSelectionScreen({
    super.key,
    required this.onDocumentTypeSelected,
    required this.onSettingsPressed,
    required this.onScanQrPressed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = ref.watch(walletProvider);
    final hasCards = cards.isNotEmpty;
    final activeProofingSession = ref.watch(activeProofingSessionProvider);
    final showQrScanOption = activeProofingSession == null;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'VCMRTD',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22),
        ),
        actions: [
          if (hasCards)
            IconButton(
              tooltip: 'New scan',
              icon: const Icon(Icons.add, size: 32),
              onPressed: () => _showNewScanSheet(context),
            ),
        ],
        bottom: activeProofingSession == null
            ? null
            : _ProofingSessionBanner(relyingParty: activeProofingSession.info.relyingParty),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF6b6868), Colors.white],
            stops: [0.0, 0.3],
          ),
        ),
        child: SafeArea(
          child: hasCards
              ? _WalletHome(
                  cards: cards,
                  onSettingsPressed: onSettingsPressed,
                  onScanQrPressed: onScanQrPressed,
                  showQrScanOption: showQrScanOption,
                )
              : _ScanOptionsHome(
                  onDocumentTypeSelected: onDocumentTypeSelected,
                  onSettingsPressed: onSettingsPressed,
                  onScanQrPressed: onScanQrPressed,
                  showQrScanOption: showQrScanOption,
                ),
        ),
      ),
    );
  }

  void _showNewScanSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheetContext) => _NewScanSheet(
        onDocumentTypeSelected: (type) {
          Navigator.of(sheetContext).pop();
          onDocumentTypeSelected(type);
        },
      ),
    );
  }
}

/// Body shown when the wallet is empty: header + the three scan options,
/// with the advanced settings entry pinned at the bottom.
class _ScanOptionsHome extends StatelessWidget {
  final Function(DocumentType) onDocumentTypeSelected;
  final VoidCallback onSettingsPressed;
  final VoidCallback onScanQrPressed;
  final bool showQrScanOption;
  const _ScanOptionsHome({
    required this.onDocumentTypeSelected,
    required this.onSettingsPressed,
    required this.onScanQrPressed,
    required this.showQrScanOption,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Header(),
            const SizedBox(height: 24),
            ..._documentTypeOptions(context, onDocumentTypeSelected),
            if (showQrScanOption) ...[const SizedBox(height: 16), _qrScanOption(context, onScanQrPressed)],
            const SizedBox(height: 16),
            _advancedSettingsOption(context, onSettingsPressed),
          ],
        ),
      ),
    );
  }
}

/// Body shown when the wallet holds at least one card: the wallet list fills
/// the available space, with the advanced settings entry pinned at the
/// bottom (not scrolled away with the list).
class _WalletHome extends StatelessWidget {
  final List<WalletCard> cards;
  final VoidCallback onSettingsPressed;
  final VoidCallback onScanQrPressed;
  final bool showQrScanOption;
  const _WalletHome({
    required this.cards,
    required this.onSettingsPressed,
    required this.onScanQrPressed,
    required this.showQrScanOption,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: WalletList(cards: cards)),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showQrScanOption) ...[_qrScanOption(context, onScanQrPressed), const SizedBox(height: 16)],
              _advancedSettingsOption(context, onSettingsPressed),
            ],
          ),
        ),
      ],
    );
  }
}

/// Slim app bar strip shown while a proofing session is pinned
/// (activeProofingSessionProvider). Deliberately doesn't say "verified" or
/// "authenticated" — connecting the session doesn't check anything, it's
/// only where the eventual result gets sent.
class _ProofingSessionBanner extends StatelessWidget implements PreferredSizeWidget {
  final String relyingParty;
  const _ProofingSessionBanner({required this.relyingParty});

  @override
  Size get preferredSize => const Size.fromHeight(32);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: preferredSize.height,
      color: Colors.indigo[900],
      alignment: Alignment.center,
      child: Text(
        'Connected — will send results to $relyingParty',
        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// Bottom sheet shown after tapping "+" to start a new scan while the wallet
/// already holds cards.
class _NewScanSheet extends StatelessWidget {
  final Function(DocumentType) onDocumentTypeSelected;
  const _NewScanSheet({required this.onDocumentTypeSelected});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 20, 14, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('New scan', style: Theme.of(context).defaultTextStyles.primaryLarge, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ..._documentTypeOptions(context, onDocumentTypeSelected),
          ],
        ),
      ),
    );
  }
}

List<Widget> _documentTypeOptions(BuildContext context, Function(DocumentType) onDocumentTypeSelected) {
  return [
    _OptionCard(
      context: context,
      title: 'Passport',
      subtitle: 'Use a machine readable passport',
      icon: Icons.book,
      accentColor: const Color(0xFF6b6868),
      onTap: () => onDocumentTypeSelected(DocumentType.passport),
      showBadge: true,
      badgeText: 'Most common',
    ),
    const SizedBox(height: 16),
    _OptionCard(
      context: context,
      title: 'Identity Card',
      subtitle: 'Use a machine readable identity card',
      icon: Icons.credit_card,
      accentColor: const Color(0xFF4CAF50),
      onTap: () => onDocumentTypeSelected(DocumentType.identityCard),
    ),
    const SizedBox(height: 16),
    _OptionCard(
      context: context,
      title: 'Driving Licence',
      subtitle: 'Use a machine readable driving licence. Currently works primarily with Dutch licences.',
      icon: Icons.directions_car,
      accentColor: const Color(0xFF2196F3),
      onTap: () => onDocumentTypeSelected(DocumentType.drivingLicence),
    ),
  ];
}

Widget _qrScanOption(BuildContext context, VoidCallback onScanQrPressed) {
  return _OptionCard(
    context: context,
    title: 'Scan QR code',
    subtitle: 'Scan any QR code with the camera',
    icon: Icons.qr_code_scanner,
    accentColor: const Color(0xFF9C27B0),
    onTap: onScanQrPressed,
  );
}

Widget _advancedSettingsOption(BuildContext context, VoidCallback onSettingsPressed) {
  return _OptionCard(
    context: context,
    title: 'Advanced settings',
    subtitle: 'Ocr Engine, Face Verification and more',
    icon: Icons.settings,
    accentColor: const Color(0xFF757575),
    onTap: onSettingsPressed,
  );
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF6b6868).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(40),
              ),
              child: const Icon(Icons.document_scanner, size: 40, color: Color(0xFF6b6868)),
            ),
            const SizedBox(height: 24),
            Text(
              'Verify your Identity',
              style: Theme.of(context).defaultTextStyles.primaryLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Select the type of document you want to use for verification.',
              style: Theme.of(context).defaultTextStyles.secondary,
              textAlign: TextAlign.left,
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.context,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.onTap,
    this.showBadge = false,
    this.badgeText,
  });

  final BuildContext context;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;
  final bool showBadge;
  final String? badgeText;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 122,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Colors.white),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, color: accentColor, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF212121)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: const TextStyle(fontSize: 14, color: Color(0xFF666666)),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (showBadge && badgeText != null)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: accentColor, borderRadius: BorderRadius.circular(12)),
                    child: Text(
                      badgeText!,
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
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
