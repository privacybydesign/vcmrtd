import 'dart:async';

import 'package:vcmrtd/vcmrtd.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:vcmrtdapp/custom/custom_logger_extension.dart';
import 'package:vcmrtdapp/providers/active_authenticiation_provider.dart';
import 'package:vcmrtdapp/providers/passport_issuer_provider.dart';
import 'package:vcmrtdapp/widgets/common/animated_nfc_status_widget.dart';
import 'package:vcmrtdapp/widgets/common/nfc_reading_animation.dart';
import 'package:vcmrtdapp/widgets/pages/nfc_guidance_screen.dart';
import 'package:vcmrtdapp/providers/reader_providers.dart';
import 'package:mrz_capture/mrz_capture.dart';

import '../../routing.dart';

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
  const NfcReadingScreen({required this.params, required this.onSuccess, super.key});

  final NfcReadingRouteParams params;

  final Function(DocumentData, RawDocumentData) onSuccess;

  @override
  ConsumerState<NfcReadingScreen> createState() => _NfcReadingScreenState();
}

class _NfcReadingScreenState extends ConsumerState<NfcReadingScreen> with RouteAware {
  static const _readingStepTitles = ['Start reading', 'Reading details', 'Getting photo', 'Almost done'];

  static const _readingStepSubtitles = [
    'Connecting to the chip',
    'Getting personal data',
    'Getting the document photo',
    'Verifying document security',
  ];

  static const _firstTip = 'Place your document behind your phone and move it around until it buzzes or beeps.';

  static const _holdSteadyTip = "Keep your phone and the document still - this can take a moment.";

  static const _stuckTip =
      'Reading was interrupted. Slowly lift your phone off the document and place '
      'it back down until it buzzes or beeps again.';

  static const _stuckTipDelay = Duration(seconds: 2);

  late ScannedMRZ scannedMRZ;

  Timer? _stuckTipTimer;
  bool _connectionSeemsStuck = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) routeObserver.subscribe(this, route);
  }

  @override
  void dispose() {
    _stuckTipTimer?.cancel();
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  void _handleReaderStateChange(DocumentReaderState? previous, DocumentReaderState next) {
    if (next is! DocumentReaderReconnecting) {
      _stuckTipTimer?.cancel();
      _stuckTipTimer = null;
      if (_connectionSeemsStuck) setState(() => _connectionSeemsStuck = false);
      return;
    }

    if (_stuckTipTimer != null || _connectionSeemsStuck) return;
    _stuckTipTimer = Timer(_stuckTipDelay, () {
      if (!mounted) return;
      setState(() => _connectionSeemsStuck = true);
    });
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
    ref.listen(readerProvider(scannedMRZ), _handleReaderStateChange);

    if (state is DocumentReaderPending) {
      return NfcGuidanceScreen(
        onStartReading: startReading,
        onBack: context.pop,
        documentType: widget.params.documentType,
      );
    }

    final nfcState = _mapState(state);
    final readingStep = _readingStepForState(state);
    final tip = _tipForState(state, readingStep);

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
  /// [_firstTip] only shows during [DocumentReaderConnecting] - the phase
  /// before `nfc.connect()` has resolved, where the user still has to find
  /// the chip - since every later
  /// phase (including [DocumentReaderReadingCardAccess] and
  /// [DocumentReaderAuthenticating]) only runs once a connection is already
  /// established. Every state past that shows the steady "don't move" tip -
  /// individual reading phases finish at wildly different speeds, so a tip
  /// tied to the current phase would often swap out before it could actually
  /// be read.
  String? _tipForState(DocumentReaderState state, int? readingStep) {
    final isTerminalConnectionFailure =
        state is DocumentReaderFailed &&
        (state.error == DocumentReadingError.tagLost || state.error == DocumentReadingError.timeoutWaitingForTag);
    if (_connectionSeemsStuck || isTerminalConnectionFailure) {
      return _stuckTip;
    }
    if (readingStep == null) return null;
    return state is DocumentReaderConnecting ? _firstTip : _holdSteadyTip;
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

    final titleColor = switch ((isDone, isCurrent)) {
      (true, _) => const Color(0xFF212121),
      (_, true) => nfcStateColor(nfcState),
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
                    color: isDone ? const Color(0xFF4CAF50) : Colors.grey[300],
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
      return const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 22);
    }
    if (isCurrent) {
      if (nfcState == NFCReadingState.error) {
        return const Icon(Icons.error, color: Color(0xFFF44336), size: 22);
      }
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(nfcStateColor(nfcState))),
      );
    }
    return Icon(Icons.circle_outlined, color: Colors.grey[400], size: 22);
  }

  Widget _buildTopBar(BuildContext context) {
    return StepBadgeTopBar(
      icon: Icons.arrow_back,
      onBack: () => _handleBack(context),
      current: 2,
      total: 4,
      label: 'Read ${widget.params.documentType.displayName}',
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
    try {
      final readerProvider = switch (widget.params.documentType) {
        DocumentType.passport => passportReaderProvider,
        DocumentType.identityCard => identityCardReaderProvider,
        DocumentType.drivingLicence => drivingLicenceReaderProvider,
      };

      NonceAndSessionId? nonceAndSessionId;

      // TODO: startValidation.faceVerification is parsed but nothing reads it
      // yet, so faceApiUrlProvider still returns the hardcoded default. When
      // the liveness step starts using the announcement, the fetch also has to
      // move out of this branch: the issuer's face verification policy is
      // independent of the active authentication toggle, so with the toggle off
      // the app would never learn that face verification applies.
      if (ref.read(activeAuthenticationProvider)) {
        final startValidation = await ref.read(passportIssuerProvider).startSessionAtPassportIssuer();
        nonceAndSessionId = startValidation.nonceAndSessionId;
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

    final docName = switch (widget.params.documentType) {
      DocumentType.passport => 'passport',
      DocumentType.identityCard => 'identity card',
      DocumentType.drivingLicence => 'driving license',
    };

    return (state) {
      final progress = progressFormatter(progressForState(state));

      final message = switch (state) {
        DocumentReaderPending() => 'Hold your phone close to $docName',
        DocumentReaderCancelled() => 'Session cancelled by user',
        DocumentReaderCancelling() => 'Cancelling...',
        DocumentReaderFailed() => 'Tag lost, try again.',
        DocumentReaderConnecting() => 'Connecting...',
        DocumentReaderReadingCOM() => 'Reading Ef.COM',
        DocumentReaderReadingCardAccess() => 'Reading Ef.CardAccess',
        DocumentReaderAuthenticating() => 'Authenticating',
        DocumentReaderReadingDataGroup() => 'Reading $docName data',
        DocumentReaderReadingSOD() => 'Reading Ef.SOD',
        DocumentReaderActiveAuthentication() => 'Performing security verification...',
        DocumentReaderSuccess() => 'Success!',
        // This is the only feedback visible while iOS's own NFC sheet covers
        // the app - without it, a lost connection looks identical to a
        // healthy read in progress until every retry is exhausted.
        DocumentReaderReconnecting() => 'Connection lost. Slowly lift your phone and place it back down.',
        _ => '',
      };

      return '$progress\n$message';
    };
  }
}
