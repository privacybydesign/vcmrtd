import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vcmrtd/vcmrtd.dart';
import 'package:idem/providers/proofing_session_provider.dart';
import 'package:idem/providers/wallet_provider.dart';
import 'package:intl/intl.dart';
import 'package:idem/theme/brand_theme.dart';
import 'package:idem/theme/text_styles.dart';
import 'package:idem/widgets/guided/guided_widgets.dart';
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
    final brand = context.brand;

    if (context.guided != null && hasCards) {
      return _GuidedWalletHome(
        cards: cards,
        onDocumentTypeSelected: onDocumentTypeSelected,
        onSettingsPressed: onSettingsPressed,
        onScanQrPressed: onScanQrPressed,
        showQrScanOption: showQrScanOption,
        connectedRelyingParty: activeProofingSession?.info.relyingParty,
      );
    }
    if (context.guided != null) {
      return _GuidedHome(
        onDocumentTypeSelected: onDocumentTypeSelected,
        onSettingsPressed: onSettingsPressed,
        onScanQrPressed: onScanQrPressed,
        showQrScanOption: showQrScanOption,
        connectedRelyingParty: activeProofingSession?.info.relyingParty,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: brand.appBarLogoAsset != null
            ? Image.asset(brand.appBarLogoAsset!, height: 32, semanticLabel: brand.appBarTitle)
            : Text(
                brand.appBarTitle,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22),
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
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: brand.homeBackgroundGradient ?? const [Color(0xFF6b6868), Colors.white],
            stops: const [0.0, 0.3],
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
            if (context.brand.showPoweredByIdem) const _PoweredByIdem(),
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
              if (context.brand.showPoweredByIdem) const _PoweredByIdem(),
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
      color: context.brand.proofingBannerColor ?? Colors.indigo[900],
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
      accentColor: context.brand.documentOptionAccent ?? const Color(0xFF6b6868),
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
      accentColor: context.brand.documentOptionAccent ?? const Color(0xFF4CAF50),
      onTap: () => onDocumentTypeSelected(DocumentType.identityCard),
    ),
    const SizedBox(height: 16),
    _OptionCard(
      context: context,
      title: 'Driving Licence',
      subtitle: 'Use a machine readable driving licence. Currently works primarily with Dutch licences.',
      icon: Icons.directions_car,
      accentColor: context.brand.documentOptionAccent ?? const Color(0xFF2196F3),
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
    accentColor: context.brand.documentOptionAccent ?? const Color(0xFF9C27B0),
    onTap: onScanQrPressed,
  );
}

Widget _advancedSettingsOption(BuildContext context, VoidCallback onSettingsPressed) {
  return _OptionCard(
    context: context,
    title: 'Advanced settings',
    subtitle: 'Ocr Engine, Face Verification and more',
    icon: Icons.settings,
    accentColor: context.brand.documentOptionAccent ?? const Color(0xFF757575),
    onTap: onSettingsPressed,
  );
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final accent = brand.accent ?? const Color(0xFF6b6868);
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
              decoration: BoxDecoration(color: accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(40)),
              child: brand.markAsset != null
                  ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: Image.asset(brand.markAsset!, excludeFromSemantics: true),
                    )
                  : Icon(Icons.document_scanner, size: 40, color: accent),
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
    final brand = context.brand;
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
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: brand.ink ?? const Color(0xFF212121),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: TextStyle(fontSize: 14, color: brand.mutedText ?? const Color(0xFF666666)),
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
                    decoration: BoxDecoration(
                      color: brand.badgeBackground ?? accentColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      badgeText!,
                      style: TextStyle(
                        color: brand.badgeForeground ?? Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
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

/// Attribution line on white-label builds, under the settings entry.
class _PoweredByIdem extends StatelessWidget {
  const _PoweredByIdem();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Text(
        'Powered by Idem',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, color: context.brand.mutedText ?? Colors.grey[600]),
      ),
    );
  }
}

/// Home in the guided layout: a dark hero explaining the three steps, then
/// the document choice. Settings sits in the hero instead of a card.
class _GuidedHome extends StatelessWidget {
  const _GuidedHome({
    required this.onDocumentTypeSelected,
    required this.onSettingsPressed,
    required this.onScanQrPressed,
    required this.showQrScanOption,
    required this.connectedRelyingParty,
  });

  final Function(DocumentType) onDocumentTypeSelected;
  final VoidCallback onSettingsPressed;
  final VoidCallback onScanQrPressed;
  final bool showQrScanOption;
  final String? connectedRelyingParty;

  @override
  Widget build(BuildContext context) {
    final g = context.guided!;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: g.surface,
        body: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _GuidedHero(onSettingsPressed: onSettingsPressed, connectedRelyingParty: connectedRelyingParty),
            ),
            SliverFillRemaining(
              hasScrollBody: false,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Which document do you have?',
                        style: g.heading(18, weight: FontWeight.w600, color: g.slate),
                      ),
                      const SizedBox(height: 16),
                      _GuidedDocumentOption(
                        title: 'Passport',
                        subtitle: 'Any machine-readable passport',
                        icon: Icons.portrait_outlined,
                        badge: 'Most common',
                        highlighted: true,
                        onTap: () => onDocumentTypeSelected(DocumentType.passport),
                      ),
                      const SizedBox(height: 12),
                      _GuidedDocumentOption(
                        title: 'Identity card',
                        subtitle: 'Machine-readable ID card with chip',
                        icon: Icons.badge_outlined,
                        onTap: () => onDocumentTypeSelected(DocumentType.identityCard),
                      ),
                      const SizedBox(height: 12),
                      _GuidedDocumentOption(
                        title: 'Driving licence',
                        subtitle: 'Dutch driving licences work best',
                        icon: Icons.directions_car_outlined,
                        onTap: () => onDocumentTypeSelected(DocumentType.drivingLicence),
                      ),
                      const Spacer(),
                      const SizedBox(height: 24),
                      if (showQrScanOption) ...[
                        GuidedButton(
                          label: 'Scan a QR code',
                          icon: Icons.qr_code_scanner,
                          secondary: true,
                          onPressed: onScanQrPressed,
                        ),
                        const SizedBox(height: 14),
                      ],
                      Text(
                        'Powered by Idem',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: g.muted),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuidedHero extends StatelessWidget {
  const _GuidedHero({required this.onSettingsPressed, required this.connectedRelyingParty});

  final VoidCallback onSettingsPressed;
  final String? connectedRelyingParty;

  @override
  Widget build(BuildContext context) {
    final g = context.guided!;
    final brand = context.brand;
    return Container(
      decoration: BoxDecoration(
        color: g.ink,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, MediaQuery.paddingOf(context).top + 20, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Image.asset(g.logoOnDarkAsset, width: 40, height: 40, semanticLabel: brand.appBarTitle),
              const Spacer(),
              GuidedRoundButton(
                icon: Icons.settings_outlined,
                tooltip: 'Settings',
                onDark: true,
                outlined: true,
                onPressed: onSettingsPressed,
              ),
            ],
          ),
          if (connectedRelyingParty != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Connected — will send results to $connectedRelyingParty',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: g.heroEyebrow),
              ),
            ),
          ],
          const SizedBox(height: 28),
          Text(
            'IDENTITY VERIFICATION',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1.04, color: g.heroEyebrow),
          ),
          const SizedBox(height: 10),
          Text('Verify your identity in three steps', style: g.heading(30, color: Colors.white)),
          const SizedBox(height: 10),
          Text(
            'Scan your ID, read its chip with NFC and take a short selfie. Your data stays on this phone until '
            'you choose to share it.',
            style: TextStyle(fontSize: 16, height: 1.5, color: g.heroMuted),
          ),
          const SizedBox(height: 28),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (i, label) in const ['Scan document', 'Read chip', 'Selfie check'].indexed) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 82),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${i + 1}', style: g.heading(14, color: g.heroAccent)),
                        const SizedBox(height: 6),
                        Text(
                          label,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _GuidedDocumentOption extends StatelessWidget {
  const _GuidedDocumentOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.badge,
    this.highlighted = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final String? badge;

  /// The suggested choice: blue border, tile and chevron.
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final g = context.guided!;
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: highlighted ? BorderSide(color: g.action, width: 2) : BorderSide(color: g.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(highlighted ? 15 : 16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: highlighted ? g.actionTint : g.neutralTile,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 24, color: highlighted ? g.action : g.slate),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          title,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: g.ink),
                        ),
                        if (badge != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: g.badgeBackground,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              badge!,
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: g.stepLabel),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(fontSize: 14, color: g.bodyText)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 22, color: highlighted ? g.action : g.muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Home in the guided layout once the wallet holds documents: a compact hero
/// with "New scan", then the saved documents.
class _GuidedWalletHome extends ConsumerWidget {
  const _GuidedWalletHome({
    required this.cards,
    required this.onDocumentTypeSelected,
    required this.onSettingsPressed,
    required this.onScanQrPressed,
    required this.showQrScanOption,
    required this.connectedRelyingParty,
  });

  final List<WalletCard> cards;
  final Function(DocumentType) onDocumentTypeSelected;
  final VoidCallback onSettingsPressed;
  final VoidCallback onScanQrPressed;
  final bool showQrScanOption;
  final String? connectedRelyingParty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.guided!;
    final newestFirst = cards.reversed.toList();
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: g.surface,
        body: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                decoration: BoxDecoration(
                  color: g.ink,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
                ),
                padding: EdgeInsets.fromLTRB(20, MediaQuery.paddingOf(context).top + 20, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Image.asset(g.logoOnDarkAsset, width: 40, height: 40, semanticLabel: context.brand.appBarTitle),
                        const Spacer(),
                        GuidedRoundButton(
                          icon: Icons.settings_outlined,
                          tooltip: 'Settings',
                          onDark: true,
                          outlined: true,
                          onPressed: onSettingsPressed,
                        ),
                      ],
                    ),
                    if (connectedRelyingParty != null) ...[
                      const SizedBox(height: 16),
                      _GuidedConnectedNote(relyingParty: connectedRelyingParty!),
                    ],
                    const SizedBox(height: 20),
                    Text(
                      'YOUR DOCUMENTS',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.04,
                        color: g.heroEyebrow,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      cards.length == 1 ? '1 document on this phone' : '${cards.length} documents on this phone',
                      style: g.heading(26, color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'They stay here until you share or remove them.',
                      style: TextStyle(fontSize: 15, height: 1.5, color: g.heroMuted),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () => _showGuidedNewScanSheet(context, onDocumentTypeSelected),
                      style: g.secondaryButtonStyle.copyWith(
                        minimumSize: const WidgetStatePropertyAll(Size.fromHeight(48)),
                        side: const WidgetStatePropertyAll(BorderSide.none),
                        foregroundColor: WidgetStatePropertyAll(g.ink),
                      ),
                      icon: const Icon(Icons.add, size: 22),
                      label: const Text('New scan'),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              sliver: SliverList.separated(
                itemCount: newestFirst.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final card = newestFirst[i];
                  return _GuidedWalletCard(
                    card: card,
                    onTap: () => showWalletCardDetails(
                      context,
                      card,
                      onRemove: () => ref.read(walletProvider.notifier).remove(card.id),
                    ),
                  );
                },
              ),
            ),
            SliverFillRemaining(
              hasScrollBody: false,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Spacer(),
                      if (showQrScanOption) ...[
                        GuidedButton(
                          label: 'Scan a QR code',
                          icon: Icons.qr_code_scanner,
                          secondary: true,
                          onPressed: onScanQrPressed,
                        ),
                        const SizedBox(height: 14),
                      ],
                      Text(
                        'Powered by Idem',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: g.muted),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuidedConnectedNote extends StatelessWidget {
  const _GuidedConnectedNote({required this.relyingParty});

  final String relyingParty;

  @override
  Widget build(BuildContext context) {
    final g = context.guided!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
      child: Text(
        'Connected — will send results to $relyingParty',
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: g.heroEyebrow),
      ),
    );
  }
}

class _GuidedWalletCard extends StatelessWidget {
  const _GuidedWalletCard({required this.card, required this.onTap});

  final WalletCard card;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final g = context.guided!;
    final type = switch (card.documentType) {
      DocumentType.passport => 'Passport',
      DocumentType.identityCard => 'Identity card',
      DocumentType.drivingLicence => 'Driving licence',
    };
    final now = DateTime.now();
    final added = card.addedAt;
    final addedLabel = added.year == now.year && added.month == now.month && added.day == now.day
        ? 'Added today'
        : 'Added ${DateFormat('d MMM').format(added)}';
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: g.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
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
                    child: WalletPhoto(imageData: card.photoImageData, imageType: card.photoImageType, size: 60),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.holderName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: g.ink),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      card.documentNumber == null ? type : '$type · ${card.documentNumber}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, color: g.bodyText),
                    ),
                    const SizedBox(height: 2),
                    Text(addedLabel, style: TextStyle(fontSize: 13, color: g.muted)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: g.muted),
            ],
          ),
        ),
      ),
    );
  }
}

void _showGuidedNewScanSheet(BuildContext context, Function(DocumentType) onDocumentTypeSelected) {
  final g = context.guided!;
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (sheetContext) {
      void pick(DocumentType type) {
        Navigator.of(sheetContext).pop();
        onDocumentTypeSelected(type);
      }

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Which document do you have?',
                style: g.heading(18, weight: FontWeight.w600, color: g.slate),
              ),
              const SizedBox(height: 16),
              _GuidedDocumentOption(
                title: 'Passport',
                subtitle: 'Any machine-readable passport',
                icon: Icons.portrait_outlined,
                badge: 'Most common',
                highlighted: true,
                onTap: () => pick(DocumentType.passport),
              ),
              const SizedBox(height: 12),
              _GuidedDocumentOption(
                title: 'Identity card',
                subtitle: 'Machine-readable ID card with chip',
                icon: Icons.badge_outlined,
                onTap: () => pick(DocumentType.identityCard),
              ),
              const SizedBox(height: 12),
              _GuidedDocumentOption(
                title: 'Driving licence',
                subtitle: 'Dutch driving licences work best',
                icon: Icons.directions_car_outlined,
                onTap: () => pick(DocumentType.drivingLicence),
              ),
            ],
          ),
        ),
      );
    },
  );
}
