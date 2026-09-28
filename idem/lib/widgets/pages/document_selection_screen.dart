import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vcmrtd/vcmrtd.dart';
import 'package:idem/l10n/l10n.dart';
import 'package:idem/providers/proofing_session_provider.dart';
import 'package:idem/providers/wallet_provider.dart';
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

  /// Guided layout only: resumes a proofing session that was accepted but not
  /// finished, in place of scanning a new QR code.
  final VoidCallback? onContinueProofingSession;

  const DocumentTypeSelectionScreen({
    super.key,
    required this.onDocumentTypeSelected,
    required this.onSettingsPressed,
    required this.onScanQrPressed,
    this.onContinueProofingSession,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = ref.watch(walletProvider);
    final hasCards = cards.isNotEmpty;
    final activeProofingSession = ref.watch(activeProofingSessionProvider);
    final showQrScanOption = activeProofingSession == null;
    final brand = context.brand;

    if (context.guided != null) {
      return _GuidedHome(
        onSettingsPressed: onSettingsPressed,
        onScanQrPressed: onScanQrPressed,
        onContinueProofingSession: onContinueProofingSession,
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
              tooltip: context.l10n.docNewScan,
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
        context.l10n.docConnectedBanner(relyingParty),
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
            Text(
              context.l10n.docNewScan,
              style: Theme.of(context).defaultTextStyles.primaryLarge,
              textAlign: TextAlign.center,
            ),
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
      title: context.l10n.docPassport,
      subtitle: context.l10n.docPassportSubtitle,
      icon: Icons.book,
      accentColor: context.brand.documentOptionAccent ?? const Color(0xFF6b6868),
      onTap: () => onDocumentTypeSelected(DocumentType.passport),
      showBadge: true,
      badgeText: context.l10n.docMostCommon,
    ),
    const SizedBox(height: 16),
    _OptionCard(
      context: context,
      title: context.l10n.docIdentityCard,
      subtitle: context.l10n.docIdentityCardSubtitle,
      icon: Icons.credit_card,
      accentColor: context.brand.documentOptionAccent ?? const Color(0xFF4CAF50),
      onTap: () => onDocumentTypeSelected(DocumentType.identityCard),
    ),
    const SizedBox(height: 16),
    _OptionCard(
      context: context,
      title: context.l10n.docDrivingLicence,
      subtitle: context.l10n.docDrivingLicenceSubtitle,
      icon: Icons.directions_car,
      accentColor: context.brand.documentOptionAccent ?? const Color(0xFF2196F3),
      onTap: () => onDocumentTypeSelected(DocumentType.drivingLicence),
    ),
  ];
}

Widget _qrScanOption(BuildContext context, VoidCallback onScanQrPressed) {
  return _OptionCard(
    context: context,
    title: context.l10n.docScanQrTitle,
    subtitle: context.l10n.docScanQrSubtitle,
    icon: Icons.qr_code_scanner,
    accentColor: context.brand.documentOptionAccent ?? const Color(0xFF9C27B0),
    onTap: onScanQrPressed,
  );
}

Widget _advancedSettingsOption(BuildContext context, VoidCallback onSettingsPressed) {
  return _OptionCard(
    context: context,
    title: context.l10n.docAdvancedSettings,
    subtitle: context.l10n.docAdvancedSettingsSubtitle,
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
              context.l10n.docVerifyIdentityTitle,
              style: Theme.of(context).defaultTextStyles.primaryLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.docSelectDocumentTypePrompt,
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

/// Home in the guided layout, where every verification starts from a QR
/// code: the hero leads with "Scan QR code", followed by how it works. Saved
/// documents live under settings, not here.
class _GuidedHome extends StatelessWidget {
  const _GuidedHome({
    required this.onSettingsPressed,
    required this.onScanQrPressed,
    required this.onContinueProofingSession,
    required this.connectedRelyingParty,
  });

  final VoidCallback onSettingsPressed;
  final VoidCallback onScanQrPressed;
  final VoidCallback? onContinueProofingSession;

  /// Set while an accepted proofing session is still open.
  final String? connectedRelyingParty;

  @override
  Widget build(BuildContext context) {
    final g = context.guided!;
    final connected = connectedRelyingParty != null && onContinueProofingSession != null;
    return GuidedStatusBar(
      onDark: true,
      bottomOnDark: false,
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
                padding: EdgeInsets.fromLTRB(20, MediaQuery.paddingOf(context).top + 20, 20, 28),
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
                    const SizedBox(height: 24),
                    Text(
                      'IDENTITY VERIFICATION',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.04,
                        color: g.heroEyebrow,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text('Verify your identity with a QR code', style: g.heading(30, color: Colors.white)),
                    const SizedBox(height: 10),
                    Text(
                      connected
                          ? 'You accepted a request from $connectedRelyingParty. Continue where you left off.'
                          : 'When a ${context.brand.appBarTitle} service asks you to verify who you are, it shows a QR '
                                'code. Scan it here to start.',
                      style: TextStyle(fontSize: 16, height: 1.5, color: g.heroMuted),
                    ),
                    const SizedBox(height: 24),
                    const Center(child: _GuidedQrBadge()),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: connected ? onContinueProofingSession : onScanQrPressed,
                      style: g.primaryButtonStyle.copyWith(
                        minimumSize: const WidgetStatePropertyAll(Size.fromHeight(56)),
                        textStyle: WidgetStatePropertyAll(
                          g.primaryButtonStyle.textStyle?.resolve({})?.copyWith(fontSize: 17),
                        ),
                      ),
                      icon: Icon(connected ? Icons.arrow_forward : Icons.qr_code_scanner, size: 22),
                      label: Text(connected ? 'Continue with $connectedRelyingParty' : 'Scan QR code'),
                    ),
                  ],
                ),
              ),
            ),
            SliverFillRemaining(
              hasScrollBody: false,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'How it works',
                        style: g.heading(16, weight: FontWeight.w600, color: g.slate),
                      ),
                      const SizedBox(height: 14),
                      for (final (i, step) in const [
                        'Scan the QR code shown by the website or app.',
                        'Use a document saved on this phone, or scan your ID.',
                        'Take a quick selfie, then share only what was asked for.',
                      ].indexed) ...[
                        if (i > 0) const SizedBox(height: 14),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 26,
                              height: 26,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(color: g.actionTint, shape: BoxShape.circle),
                              child: Text('${i + 1}', style: g.heading(13, color: g.action)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(step, style: TextStyle(fontSize: 15, height: 1.45, color: g.ink)),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const Spacer(),
                      const SizedBox(height: 24),
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

/// The QR illustration in the home hero: a QR glyph with scan-frame corners.
class _GuidedQrBadge extends StatelessWidget {
  const _GuidedQrBadge();

  @override
  Widget build(BuildContext context) {
    final g = context.guided!;
    return SizedBox(
      width: 140,
      height: 140,
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Center(
                  child: SizedBox(width: 76, height: 76, child: CustomPaint(painter: GuidedQrGlyphPainter())),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: CustomPaint(painter: _ScanCornersPainter(color: g.heroAccent)),
          ),
        ],
      ),
    );
  }
}

class _ScanCornersPainter extends CustomPainter {
  const _ScanCornersPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const len = 24.0, r = 14.0;
    final w = size.width, h = size.height;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    const radius = Radius.circular(r);
    canvas.drawPath(
      Path()
        ..moveTo(0, len)
        ..lineTo(0, r)
        ..arcToPoint(const Offset(r, 0), radius: radius)
        ..lineTo(len, 0)
        ..moveTo(w - len, 0)
        ..lineTo(w - r, 0)
        ..arcToPoint(Offset(w, r), radius: radius)
        ..lineTo(w, len)
        ..moveTo(w, h - len)
        ..lineTo(w, h - r)
        ..arcToPoint(Offset(w - r, h), radius: radius)
        ..lineTo(w - len, h)
        ..moveTo(len, h)
        ..lineTo(r, h)
        ..arcToPoint(Offset(0, h - r), radius: radius)
        ..lineTo(0, h - len),
      paint,
    );
  }

  @override
  bool shouldRepaint(_ScanCornersPainter old) => old.color != color;
}
