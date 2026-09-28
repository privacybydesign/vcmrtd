import 'dart:math' as math;

import 'package:vcmrtd/vcmrtd.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:idem/custom/custom_logger_extension.dart';
import 'package:idem/l10n/l10n.dart';
import 'package:idem/providers/active_authenticiation_provider.dart';
import 'package:idem/providers/face_api_provider.dart';
import 'package:idem/providers/face_engine_provider.dart';
import 'package:idem/providers/passport_issuer_provider.dart';
import 'package:idem/providers/proofing_session_provider.dart';
import 'package:idem/services/proofing_session_client.dart';
import 'package:idem/widgets/common/animated_nfc_status_widget.dart';
import 'package:idem/widgets/common/nfc_reading_animation.dart';
import 'package:idem/widgets/pages/nfc_guidance_screen.dart';
import 'package:idem/providers/reader_providers.dart';
import 'package:mrz_capture/mrz_capture.dart';

import '../../routing.dart';
import 'package:idem/theme/brand_theme.dart';
import 'package:idem/widgets/guided/guided_widgets.dart';

class NfcReadingRouteParams {
  final ScannedMRZ scannedMRZ;
  final DocumentType documentType;

  NfcReadingRouteParams({required this.scannedMRZ, required this.documentType});

  Map<String, String> toQueryParams() {
    final baseParams = {
      'doc_number': scannedMRZ.documentNumber,
      'country_code': scannedMRZ.countryCode,
      'document_type': switch (documentType) {
        DocumentType.passport => 'passport',
        DocumentType.identityCard => 'identity_card',
        DocumentType.drivingLicence => 'drivers_license',
      },
    };

    if (scannedMRZ is ScannedPassportMRZ) {
      final passport = scannedMRZ as ScannedPassportMRZ;
      baseParams['date_of_birth'] = passport.dateOfBirth.toIso8601String();
      baseParams['date_of_expiry'] = passport.dateOfExpiry.toIso8601String();
    } else if (scannedMRZ is ScannedDriverLicenseMRZ) {
      final driverLicense = scannedMRZ as ScannedDriverLicenseMRZ;
      baseParams['version'] = driverLicense.version;
      baseParams['random_data'] = driverLicense.randomData;
      baseParams['configuration'] = driverLicense.configuration;
    }

    return baseParams;
  }

  static NfcReadingRouteParams fromQueryParams(Map<String, String> params) {
    final docType = params['document_type']!;
    final documentType = switch (docType) {
      'passport' => DocumentType.passport,
      'identity_card' => DocumentType.identityCard,
      'drivers_license' => DocumentType.drivingLicence,
      _ => throw Exception('unexpected document type: $docType'),
    };

    final scannedMRZ = switch (documentType) {
      DocumentType.passport || DocumentType.identityCard => ScannedPassportMRZ(
        documentNumber: params['doc_number']!,
        countryCode: params['country_code']!,
        dateOfBirth: DateTime.parse(params['date_of_birth']!),
        dateOfExpiry: DateTime.parse(params['date_of_expiry']!),
        documentType: documentType,
      ),
      DocumentType.drivingLicence => ScannedDriverLicenseMRZ(
        documentNumber: params['doc_number']!,
        countryCode: params['country_code']!,
        version: params['version']!,
        randomData: params['random_data']!,
        configuration: params['configuration']!,
      ),
    };

    return NfcReadingRouteParams(scannedMRZ: scannedMRZ, documentType: documentType);
  }
}

class NfcReadingScreen extends ConsumerStatefulWidget {
  const NfcReadingScreen({
    required this.params,
    required this.onSuccess,
    this.stepNumber = 2,
    this.totalSteps = 4,
    super.key,
  });

  final NfcReadingRouteParams params;

  final Function(DocumentData, RawDocumentData) onSuccess;

  /// Step badge numbers — default to vcmrtd's fixed 4-step sequence (this
  /// screen is always step 2 there) so any caller not passing these
  /// explicitly keeps today's behaviour; routing.dart passes a session's
  /// actual FlowStepPlan values when a QR/deep-link flow governs the
  /// numbering.
  final int stepNumber;
  final int totalSteps;

  @override
  ConsumerState<NfcReadingScreen> createState() => _NfcReadingScreenState();
}

class _NfcReadingScreenState extends ConsumerState<NfcReadingScreen> with RouteAware {
  List<String> get _readingStepTitles {
    final l10n = context.l10n;
    return [l10n.docNfcStepStart, l10n.docNfcStepDetails, l10n.docNfcStepPhoto, l10n.docNfcStepAlmostDone];
  }

  List<String> get _readingStepSubtitles {
    final l10n = context.l10n;
    return [
      l10n.docNfcStepStartSubtitle,
      l10n.docNfcStepDetailsSubtitle,
      l10n.docNfcStepPhotoSubtitle,
      l10n.docNfcStepAlmostDoneSubtitle,
    ];
  }

  late ScannedMRZ scannedMRZ;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) routeObserver.subscribe(this, route);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  /// Fires when a route pushed on top of this one (face verification) is
  /// popped back to it. If the read already succeeded, there is nothing left
  /// to do on this screen - re-showing the completed checklist would be a
  /// dead end, so drop back to the guidance screen and let the user tap
  /// through the (quick) NFC read again to continue.
  @override
  void didPopNext() {
    final readerProvider = switch (widget.params.documentType) {
      DocumentType.passport => passportReaderProvider,
      DocumentType.identityCard => identityCardReaderProvider,
      DocumentType.drivingLicence => drivingLicenceReaderProvider,
    };
    final state = ref.read(readerProvider(scannedMRZ));
    if (state is DocumentReaderSuccess) {
      ref.read(readerProvider(scannedMRZ).notifier).reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    scannedMRZ = widget.params.scannedMRZ;
    widget.params.documentType.toString().logInfo();
    final readerProvider = switch (widget.params.documentType) {
      DocumentType.passport => passportReaderProvider,
      DocumentType.identityCard => identityCardReaderProvider,
      DocumentType.drivingLicence => drivingLicenceReaderProvider,
    };

    final state = ref.watch(readerProvider(scannedMRZ));

    if (state is DocumentReaderPending) {
      return NfcGuidanceScreen(
        onStartReading: startReading,
        onBack: context.pop,
        documentType: widget.params.documentType,
        stepNumber: widget.stepNumber,
        totalSteps: widget.totalSteps,
      );
    }

    final nfcState = _mapState(state);
    final readingStep = _readingStepForState(state);
    final tip = _tipForState(state, readingStep);

    final guided = context.guided;
    if (guided != null) {
      return _buildGuided(context, guided, state: state, nfcState: nfcState, readingStep: readingStep, tip: tip);
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    if (nfcState != NFCReadingState.success && nfcState != NFCReadingState.error) ...[
                      NfcReadingAnimation(documentType: widget.params.documentType),
                      const SizedBox(height: 16),
                    ],
                    Center(
                      child: AnimatedNFCStatusWidget(
                        state: nfcState,
                        message: '',
                        progress: progressForState(state),
                        onRetry: retry,
                        onCancel: () => _handleBack(context),
                        tip: tip,
                      ),
                    ),
                    if (readingStep != null) ...[
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: _buildStepChecklist(currentStep: readingStep, nfcState: nfcState),
                      ),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Maps the reader state to an index into [_readingStepTitles]. Regresses
  /// to step 0 on failure/cancellation, since the user needs to reposition
  /// the document and start the reading flow again.
  int? _readingStepForState(DocumentReaderState state) {
    return switch (state) {
      DocumentReaderConnecting() || DocumentReaderReadingCardAccess() || DocumentReaderAuthenticating() => 0,
      DocumentReaderReadingCOM() => 1,
      DocumentReaderReadingDataGroup(dataGroup: 'DG1') => 1,
      DocumentReaderReadingDataGroup() => 2,
      DocumentReaderReadingSOD() || DocumentReaderActiveAuthentication() || DocumentReaderSuccess() => 3,
      DocumentReaderFailed() || DocumentReaderCancelled() || DocumentReaderCancelling() => 0,
      // Keep showing whichever step the read was actually on when the
      // connection dropped - regressing to step 0 here would read as a full
      // failure, when this is just a retry in progress.
      DocumentReaderReconnecting(:final previousState) => _readingStepForState(previousState),
      _ => null,
    };
  }

  /// The contextual tip to show for the current state, or null to hide it.
  /// Surfaces the "seems stuck" tip the instant a connection is lost - both
  /// while it's actively being retried, and after retries are exhausted with
  /// a tag-lost/timeout failure - and swaps it back out the instant the
  /// connection recovers, since a silent retry loop otherwise looks
  /// identical to a healthy read to the user. [_firstTip] only shows during
  /// [DocumentReaderConnecting] - the phase before `nfc.connect()` has
  /// resolved, where the user still has to find the chip - since every later
  /// phase (including [DocumentReaderReadingCardAccess] and
  /// [DocumentReaderAuthenticating]) only runs once a connection is already
  /// established. Every state past that shows the steady "don't move" tip -
  /// individual reading phases finish at wildly different speeds, so a tip
  /// tied to the current phase would often swap out before it could actually
  /// be read.
  String? _tipForState(DocumentReaderState state, int? readingStep) {
    final isConnectionLost =
        state is DocumentReaderReconnecting ||
        (state is DocumentReaderFailed &&
            (state.error == DocumentReadingError.tagLost || state.error == DocumentReadingError.timeoutWaitingForTag));
    if (isConnectionLost) {
      return context.l10n.docNfcTipStuck;
    }
    if (readingStep == null) return null;
    return state is DocumentReaderConnecting ? context.l10n.docNfcTipFirst : context.l10n.docNfcTipHoldSteady;
  }

  /// Checklist card of reading steps, e.g. a checkmark for a done step, a
  /// small spinner for the current one, and an outlined circle for steps
  /// still ahead.
  Widget _buildStepChecklist({required int currentStep, required NFCReadingState nfcState}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < _readingStepTitles.length; index++)
            _buildStepRow(
              index: index,
              currentStep: currentStep,
              nfcState: nfcState,
              isLast: index == _readingStepTitles.length - 1,
            ),
        ],
      ),
    );
  }

  /// A step row with its status icon connected to the next row by a
  /// vertical line, filled in green once this step is done.
  Widget _buildStepRow({
    required int index,
    required int currentStep,
    required NFCReadingState nfcState,
    required bool isLast,
  }) {
    final isDone = index < currentStep;
    final isCurrent = index == currentStep;

    final brand = context.brand;
    final titleColor = switch ((isDone, isCurrent)) {
      (true, _) => brand.ink ?? const Color(0xFF212121),
      (_, true) => nfcStateColor(nfcState, brand),
      _ => Colors.grey[500],
    };

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              _buildStepStatusIcon(isDone: isDone, isCurrent: isCurrent, nfcState: nfcState),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: isDone ? brand.success ?? const Color(0xFF4CAF50) : Colors.grey[300],
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _readingStepTitles[index],
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: titleColor),
                  ),
                  const SizedBox(height: 2),
                  Text(_readingStepSubtitles[index], style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepStatusIcon({required bool isDone, required bool isCurrent, required NFCReadingState nfcState}) {
    if (isDone) {
      return Icon(Icons.check_circle, color: context.brand.success ?? const Color(0xFF4CAF50), size: 22);
    }
    if (isCurrent) {
      if (nfcState == NFCReadingState.error) {
        return const Icon(Icons.error, color: Color(0xFFF44336), size: 22);
      }
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation(nfcStateColor(nfcState, context.brand)),
        ),
      );
    }
    return Icon(Icons.circle_outlined, color: Colors.grey[400], size: 22);
  }

  /// Guided layout: a progress ring over a checklist of what's been read.
  Widget _buildGuided(
    BuildContext context,
    GuidedStyle g, {
    required DocumentReaderState state,
    required NFCReadingState nfcState,
    required int? readingStep,
    required String? tip,
  }) {
    final docName = switch (widget.params.documentType) {
      DocumentType.passport => 'passport',
      DocumentType.identityCard => 'ID card',
      DocumentType.drivingLicence => 'driving licence',
    };
    final failed = nfcState == NFCReadingState.error;
    final done = nfcState == NFCReadingState.success;
    final (title, subtitle) = switch (state) {
      DocumentReaderConnecting() => ('Hold your phone on the $docName', tip ?? context.l10n.docNfcTipFirst),
      DocumentReaderReconnecting() => ('Connection lost', context.l10n.docNfcTipStuck),
      DocumentReaderCancelled() || DocumentReaderCancelling() => ('Reading stopped', 'Start again when you are ready.'),
      DocumentReaderFailed() => (
        'Reading failed',
        tip ?? 'Check that the $docName lies flat under your phone and try again.',
      ),
      DocumentReaderSuccess() => ('Chip read', 'Your $docName is genuine.'),
      _ => ('Don’t move your phone', 'Keep it on the $docName until reading is complete.'),
    };
    final ringColor = failed
        ? const Color(0xFFD1293D)
        : done
        ? g.success
        : g.action;
    final percent = (progressForState(state) * 100).round().clamp(0, 100);

    return GuidedStatusBar(
      onDark: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GuidedTopBar(
                leading: GuidedRoundButton(
                  icon: Icons.close,
                  tooltip: 'Cancel reading',
                  onPressed: () => _handleBack(context),
                ),
                center: Image.asset(g.markAsset, width: 32, height: 32, semanticLabel: context.brand.appBarTitle),
              ),
              const GuidedStepBar(step: 2),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: SizedBox(
                          width: 200,
                          height: 200,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              TweenAnimationBuilder<double>(
                                tween: Tween(end: percent / 100),
                                duration: const Duration(milliseconds: 400),
                                builder: (context, value, _) => CustomPaint(
                                  painter: _ProgressRingPainter(value: value, color: ringColor, track: g.actionTint),
                                ),
                              ),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (failed)
                                    Icon(Icons.error_outline, size: 56, color: ringColor)
                                  else if (done)
                                    Icon(Icons.check, size: 64, color: ringColor)
                                  else
                                    Text('$percent%', style: g.heading(44)),
                                  const SizedBox(height: 2),
                                  Text(
                                    failed ? 'Not read' : (done ? 'Complete' : 'Reading chip'),
                                    style: TextStyle(fontSize: 14, color: g.bodyText),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(title, textAlign: TextAlign.center, style: g.heading(24, height: 1.25)),
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, height: 1.5, color: g.bodyText),
                      ),
                      if (readingStep != null) ...[
                        const SizedBox(height: 32),
                        _GuidedReadingChecklist(
                          style: g,
                          currentStep: readingStep,
                          failed: failed,
                          complete: done,
                          documentName: docName,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (failed)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                  child: GuidedButton(label: 'Try again', icon: Icons.refresh, onPressed: retry),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return StepBadgeTopBar(
      icon: Icons.arrow_back,
      onBack: () => _handleBack(context),
      current: widget.stepNumber,
      total: widget.totalSteps,
      label: context.l10n.docReadDocument(widget.params.documentType.name),
    );
  }

  NFCReadingState _mapState(DocumentReaderState state) {
    return switch (state) {
      DocumentReaderPending() => NFCReadingState.idle,
      DocumentReaderCancelled() => NFCReadingState.error,
      DocumentReaderCancelling() => NFCReadingState.cancelling,
      DocumentReaderFailed() => NFCReadingState.error,
      DocumentReaderConnecting() => NFCReadingState.connecting,
      DocumentReaderReadingCardAccess() => NFCReadingState.authenticating,
      DocumentReaderAuthenticating() => NFCReadingState.authenticating,
      DocumentReaderReadingDataGroup() ||
      DocumentReaderReadingSOD() ||
      DocumentReaderReadingCOM() => NFCReadingState.reading,
      DocumentReaderActiveAuthentication() => NFCReadingState.authenticating,
      DocumentReaderSuccess() => NFCReadingState.success,
      // Keep the visual state (color/icon) matching whatever step this is a
      // retry of - the reposition tip is what actually flags the connection
      // loss, this shouldn't also read as a harder failure.
      DocumentReaderReconnecting(:final previousState) => _mapState(previousState),
      _ => throw Exception('unexpected state: $state'),
    };
  }

  /// Back-arrow tap: explicitly cancels any in-flight read (same as the
  /// "Cancel" button) before leaving, rather than relying solely on the
  /// reader provider's autoDispose cleanup.
  Future<void> _handleBack(BuildContext context) async {
    await cancel();
    if (context.mounted) Navigator.maybePop(context);
  }

  Future<void> cancel() async {
    final readerProvider = switch (widget.params.documentType) {
      DocumentType.passport => passportReaderProvider,
      DocumentType.identityCard => identityCardReaderProvider,
      DocumentType.drivingLicence => drivingLicenceReaderProvider,
    };

    await ref.read(readerProvider(scannedMRZ).notifier).cancel();
  }

  Future<void> retry() async {
    final readerProvider = switch (widget.params.documentType) {
      DocumentType.passport => passportReaderProvider,
      DocumentType.identityCard => identityCardReaderProvider,
      DocumentType.drivingLicence => drivingLicenceReaderProvider,
    };

    ref.read(readerProvider(scannedMRZ).notifier).reset();
    startReading();
  }

  Future<void> startReading() async {
    markActiveProofingStepStarted(ProviderScope.containerOf(context), stepNfcRead);
    try {
      final readerProvider = switch (widget.params.documentType) {
        DocumentType.passport => passportReaderProvider,
        DocumentType.identityCard => identityCardReaderProvider,
        DocumentType.drivingLicence => drivingLicenceReaderProvider,
      };

      NonceAndSessionId? nonceAndSessionId;

      final activeSession = ref.read(activeProofingSessionProvider);
      ref.read(issuerFaceVerificationProvider.notifier).set(null);
      if (activeSession == null && ref.read(faceEngineProvider) == FaceEngineChoice.regula) {
        // Standalone Regula needs the issuer to match, and the issuer's verify
        // call needs this session's nonce, so the chip read signs it too.
        try {
          final startValidation = await ref.read(passportIssuerProvider).startSessionAtPassportIssuer();
          ref.read(issuerFaceVerificationProvider.notifier).set(startValidation.faceVerification);
          if (startValidation.faceVerification != null || ref.read(activeAuthenticationProvider)) {
            nonceAndSessionId = startValidation.nonceAndSessionId;
          }
        } catch (e) {
          // Without the issuer the face step falls back to the on-device engine.
          debugPrint('passport issuer unavailable for face verification: $e');
        }
      }
      if (nonceAndSessionId == null && ref.read(activeAuthenticationProvider)) {
        if (activeSession != null) {
          // Pinned to an identity-proofing-service session: the chip must
          // sign that session's own aaChallenge, since the server verifies
          // the AA response against it byte-for-byte and otherwise reports a
          // genuine chip as CHIP_CLONE_DETECTED. A missing aaChallenge (older
          // or mismatched server responses) just skips Active Authentication,
          // the same as an unsupported chip does.
          final aaChallenge = activeSession.info.aaChallenge;
          if (aaChallenge != null && aaChallenge.isNotEmpty) {
            nonceAndSessionId = NonceAndSessionId(nonce: aaChallenge, sessionId: activeSession.info.id);
          }
        } else {
          // No pinned proofing session (standalone scan straight into the
          // local wallet) — fall back to the legacy passport-issuer flow.
          final startValidation = await ref.read(passportIssuerProvider).startSessionAtPassportIssuer();
          nonceAndSessionId = startValidation.nonceAndSessionId;
        }
      }
      final result = await ref
          .read(readerProvider(scannedMRZ).notifier)
          .readDocument(iosNfcMessages: _createIosNfcMessageMapper(), activeAuthenticationParams: nonceAndSessionId);
      if (result != null) {
        final (document, passportDataResult) = result;
        widget.onSuccess(document, passportDataResult);
      }
    } catch (e) {
      debugPrint('failed to read document: $e');
    }
  }

  IosNfcMessageMapper _createIosNfcMessageMapper() {
    String progressFormatter(double progress) {
      const numStages = 10;
      final prog = (progress * numStages).toInt();
      return '🟢' * prog + '⚪️' * (numStages - prog);
    }

    final l10n = context.l10n;
    final docType = widget.params.documentType.name;

    return (state) {
      final progress = progressFormatter(progressForState(state));

      final message = switch (state) {
        DocumentReaderPending() => l10n.docIosNfcHoldClose(docType),
        DocumentReaderCancelled() => l10n.docIosNfcCancelled,
        DocumentReaderCancelling() => l10n.docIosNfcCancelling,
        DocumentReaderFailed() => l10n.docIosNfcFailed,
        DocumentReaderConnecting() => l10n.docIosNfcConnecting,
        DocumentReaderReadingCOM() => l10n.docIosNfcReadingFile('Ef.COM'),
        DocumentReaderReadingCardAccess() => l10n.docIosNfcReadingFile('Ef.CardAccess'),
        DocumentReaderAuthenticating() => l10n.docIosNfcAuthenticating,
        DocumentReaderReadingDataGroup() => l10n.docIosNfcReadingData(docType),
        DocumentReaderReadingSOD() => l10n.docIosNfcReadingFile('Ef.SOD'),
        DocumentReaderActiveAuthentication() => l10n.docIosNfcSecurityCheck,
        DocumentReaderSuccess() => l10n.docIosNfcSuccess,
        // This is the only feedback visible while iOS's own NFC sheet covers
        // the app - without it, a lost connection looks identical to a
        // healthy read in progress until every retry is exhausted.
        DocumentReaderReconnecting() => l10n.docIosNfcReconnecting,
        _ => '',
      };

      return '$progress\n$message';
    };
  }
}

/// The four reading steps as a bordered list: done rows get a green check,
/// the current row is tinted with a spinner, later rows an empty ring.
class _GuidedReadingChecklist extends StatelessWidget {
  const _GuidedReadingChecklist({
    required this.style,
    required this.currentStep,
    required this.failed,
    required this.complete,
    required this.documentName,
  });

  final GuidedStyle style;
  final int currentStep;
  final bool failed;
  final bool complete;
  final String documentName;

  @override
  Widget build(BuildContext context) {
    final g = style;
    final labels = [
      ('Secure connection set up', 'Setting up a secure connection'),
      ('Personal details read', 'Reading personal details'),
      ('${_capitalize(documentName)} photo read', 'Reading $documentName photo'),
      ('Chip is genuine', 'Checking the chip is genuine'),
    ];
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: g.subtleBorder),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final (i, (doneLabel, activeLabel)) in labels.indexed)
            _row(
              g,
              label: i < currentStep || complete ? doneLabel : activeLabel,
              state: i < currentStep || complete
                  ? _RowState.done
                  : i == currentStep
                  ? (failed ? _RowState.failed : _RowState.current)
                  : _RowState.pending,
              divider: i < labels.length - 1,
            ),
        ],
      ),
    );
  }

  Widget _row(GuidedStyle g, {required String label, required _RowState state, required bool divider}) {
    final Widget icon = switch (state) {
      _RowState.done => Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(color: g.success, shape: BoxShape.circle),
        child: const Icon(Icons.check, size: 16, color: Colors.white),
      ),
      _RowState.current => SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 3, color: g.action, backgroundColor: g.actionTintStrong),
      ),
      _RowState.failed => const Icon(Icons.error, size: 24, color: Color(0xFFD1293D)),
      _RowState.pending => Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: g.placeholder, width: 2),
        ),
      ),
    };
    final current = state == _RowState.current;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: current ? g.actionTint.withValues(alpha: 0.5) : null,
        border: divider ? Border(bottom: BorderSide(color: g.subtleBorder)) : null,
      ),
      child: Row(
        children: [
          icon,
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: current ? FontWeight.w700 : FontWeight.w600,
                color: current ? g.action : (state == _RowState.pending ? g.muted : g.ink),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _capitalize(String s) => s[0].toUpperCase() + s.substring(1);
}

enum _RowState { done, current, failed, pending }

class _ProgressRingPainter extends CustomPainter {
  _ProgressRingPainter({required this.value, required this.color, required this.track});

  final double value;
  final Color color;
  final Color track;

  static const _stroke = 14.0;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: size.shortestSide / 2 - 12);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke;
    canvas.drawArc(rect, 0, 2 * math.pi, false, paint..color = track);
    if (value > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * value,
        false,
        paint
          ..color = color
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_ProgressRingPainter old) => old.value != value || old.color != color || old.track != track;
}
