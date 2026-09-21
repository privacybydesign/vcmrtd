import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vcmrtd/vcmrtd.dart';
import 'package:face_verification/face_verification.dart';
import 'package:mrz_capture/mrz_capture.dart';
import 'package:idem/providers/face_engine_provider.dart';
import 'package:idem/providers/liveness_mode_provider.dart';
import 'package:idem/utils/document_dates.dart';
import 'package:idem/services/flow_step_plan.dart';
import 'package:idem/widgets/pages/document_capture_only_result_screen.dart';
import 'package:idem/widgets/pages/document_selection_screen.dart';
import 'package:idem/widgets/pages/face_verification_entry_screen.dart';
import 'package:idem/widgets/pages/driving_licence_data_screen.dart';
import 'package:idem/widgets/pages/manual_entry_route_params.dart';
import 'package:idem/widgets/pages/nfc_reading_screen.dart';
import 'package:idem/widgets/pages/passport_data_screen.dart';
import 'package:idem/providers/proofing_session_provider.dart';
import 'package:idem/services/face_verification_outcome.dart';
import 'package:idem/widgets/pages/proofing_session_consent_screen.dart';
import 'package:idem/services/proofing_session_client.dart';
import 'package:idem/widgets/pages/qr_scanner_screen.dart';
import 'package:idem/widgets/pages/scanner_wrapper.dart';
import 'package:idem/widgets/pages/settings_screen.dart';

/// The photo + issue date to seed face verification with, straight off the
/// just-read [document] — used to jump into face verification immediately
/// after NFC reading succeeds, before the document data screen is shown.
(Uint8List, DateTime?) _faceVerificationInputFor(DocumentData document, DocumentType documentType) {
  return switch (documentType) {
    DocumentType.passport ||
    DocumentType.identityCard => ((document as PassportData).photoImageData, document.dateOfIssue),
    DocumentType.drivingLicence => (
      (document as DrivingLicenceData).photoImageData,
      parseDrivingLicenceDate(document.dateOfIssue),
    ),
  };
}

const _faceVerificationPath = '/face_verification';
const _documentCaptureResultPath = '/document_capture_result';
const _settingsPath = '/settings';
const _qrScannerPath = '/qr_scanner';
const _proofingConsentPath = '/proofing_consent';

/// The pinned session's flow steps, or null if there is no pinned session or
/// it wasn't created against a flow — the single place every route builder
/// below reads this from, to compute its [FlowStepPlan] (and, for
/// /nfc_reading, to also decide whether face verification runs next).
List<String>? _activeSteps(BuildContext context) =>
    ProviderScope.containerOf(context).read(activeProofingSessionProvider)?.info.steps;

/// The pinned session's selfieLocation, defaulting to "browser" (matching
/// [ProofingSessionInfo.selfieLocation]'s own default) when there's no
/// pinned session at all — meaningless in that case since [_activeSteps]
/// being null already means vcmrtd's unconditional default sequence applies.
String _activeSelfieLocation(BuildContext context) =>
    ProviderScope.containerOf(context).read(activeProofingSessionProvider)?.info.selfieLocation ?? 'browser';

/// Where a just-captured document (MRZ scan or manual entry) leads next,
/// given the pinned session's flow. Shared by /mrz_reader's onMrzScanned and
/// /manual_entry's onManualEntryComplete, since both just produce a
/// [ScannedMRZ] and from here on the decision is identical.
///
/// A null [ProofingSessionInfo.steps] — no pinned session at all, or one
/// created without a flow — means every step is implicitly wanted, so this
/// always falls through to the unchanged nfc_read path: opening the app
/// outside a QR/deep-link session always runs the full
/// document_capture -> nfc_read -> face_verification sequence, never a
/// flow-driven subset.
void _afterDocumentCaptured(BuildContext context, ScannedMRZ scannedMrz, DocumentType documentType) {
  final activeSession = ProviderScope.containerOf(context).read(activeProofingSessionProvider);
  final steps = activeSession?.info.steps;

  if (steps == null || steps.contains(stepNfcRead)) {
    context.pushNfcReadingScreen(NfcReadingRouteParams(scannedMRZ: scannedMrz, documentType: documentType));
    return;
  }

  // steps is non-null and omits "nfc_read" here, so this is a genuine
  // document_capture-only (or document_capture + selfie/liveness/face_match)
  // flow, not a fallback for something broken - the server guarantees
  // "nfc_read" never appears without "document_capture", but not the
  // reverse. There's no chip read at all in this branch, so there's no
  // DocumentData/RawDocumentData to carry forward, only what the scan/manual
  // entry itself produced.
  if (stepsRequestAny(steps, [stepFaceVerification, stepSelfie, stepLiveness, stepFaceMatch])) {
    final referencePhoto = activeSession!.info.referencePhoto;
    context.pushFaceVerificationScreenForScannedMrz(
      // Null when the flow doesn't need an identity comparison (selfie- or
      // liveness-only) - FaceVerificationEntryScreen already runs fine
      // without a comparison photo in that case, same as it always has.
      referencePhotoBytes: referencePhoto != null ? base64Decode(referencePhoto.imageBase64) : null,
      scannedMrz: scannedMrz,
      documentType: documentType,
    );
    return;
  }

  context.pushDocumentCaptureOnlyResultScreen(session: activeSession!, scannedMrz: scannedMrz);
}

/// Where accepting a session's consent leads next — normally vcmrtd's own
/// document-scan entry point, but a flow whose steps omit "document_capture"
/// skips that entirely. The server guarantees "nfc_read" never appears
/// without "document_capture", so the only thing such a flow can still ask
/// for is selfie/liveness/face_match — a real, supported configuration (pure
/// biometric verification against a supplied referencePhoto, no document
/// scan at all), not a fallback for something broken.
///
/// Uses `go` rather than `push` throughout, matching the unconditional
/// `context.go('/select_doc_type')` this replaces — none of these entry
/// points should leave the consent screen underneath them in the stack.
void _afterConsent(BuildContext context, ActiveProofingSession session) {
  final steps = session.info.steps;
  if (steps == null || steps.contains(stepDocumentCapture)) {
    context.go('/select_doc_type');
    return;
  }

  if (stepsRequestAny(steps, [stepFaceVerification, stepSelfie, stepLiveness, stepFaceMatch])) {
    final referencePhoto = session.info.referencePhoto;
    context.go(
      _faceVerificationPath,
      extra: {'nfcImageBytes': referencePhoto != null ? base64Decode(referencePhoto.imageBase64) : null},
    );
    return;
  }

  // Degenerate: a flow with none of document_capture/nfc_read/selfie/
  // liveness/face_match at all - nothing to capture, submit immediately.
  context.go(_documentCaptureResultPath, extra: {'session': session});
}

/// Exposes [_proofingConsentPath] so a tapped vcmrtd:// deep link
/// (VcMrtdApp._openProofingLink in main.dart) can push the consent screen
/// directly, the same way [_handleScannedQr] does for a scanned QR.
const proofingConsentPath = _proofingConsentPath;

/// Handles a scanned QR: if it's an identity-proofing session handoff, fetch
/// what the relying party wants and hand it to [ProofingSessionConsentScreen]
/// for the user to accept or decline before anything is pinned — see that
/// route below, which is the only place [activeProofingSessionProvider] gets
/// set. Any other QR content is left for the original debug behaviour — it's
/// shown, not acted on, since this scanner isn't scoped to just proofing
/// handoffs.
Future<void> _handleScannedQr(BuildContext context, String value) async {
  final messenger = ScaffoldMessenger.of(context);
  final router = GoRouter.of(context);
  final container = ProviderScope.containerOf(context);

  final sessionRef = ProofingSessionRef.parse(value);
  if (sessionRef == null) {
    router.pop();
    messenger.showSnackBar(SnackBar(content: Text('QR code scanned: $value')));
    return;
  }

  try {
    final info = await container.read(proofingSessionClientProvider).fetchSession(sessionRef);
    if (info.requestedAttributes.isEmpty) {
      router.pop();
      messenger.showSnackBar(const SnackBar(content: Text('This session does not specify what to collect')));
      return;
    }
    router.pop();
    router.push(_proofingConsentPath, extra: {'ref': sessionRef, 'info': info});
  } catch (e) {
    router.pop();
    messenger.showSnackBar(SnackBar(content: Text('Could not connect to the relying party: $e')));
  }
}

extension CustomRouteExtensions on BuildContext {
  void pushNfcReadingScreen(NfcReadingRouteParams params) {
    final path = Uri(path: '/nfc_reading', queryParameters: params.toQueryParams());
    push(path.toString());
  }

  void pushMrzReaderScreen(MrzReaderRouteParams params) {
    final path = Uri(path: '/mrz_reader', queryParameters: params.toQueryParams());
    push(path.toString());
  }

  void pushManualEntryScreen(ManualEntryRouteParams params) {
    final path = Uri(path: '/manual_entry', queryParameters: params.toQueryParams());
    push(path.toString());
  }

  void pushFaceVerificationScreen(
    Uint8List nfcImageBytes, {
    DateTime? issueDate,
    required DocumentData document,
    required RawDocumentData result,
    required DocumentType documentType,
  }) {
    push(
      _faceVerificationPath,
      extra: {
        'nfcImageBytes': nfcImageBytes,
        'issueDate': issueDate,
        'document': document,
        'result': result,
        'documentType': documentType,
      },
    );
  }

  /// Same route as [pushFaceVerificationScreen], for a session with no chip
  /// read to carry a DocumentData/RawDocumentData forward from — see
  /// [_afterDocumentCaptured]/[_afterConsent]. [referencePhotoBytes] is the
  /// relying party's supplied comparison image (api.referencePhoto), used in
  /// place of DG2 for face_match; null when the flow doesn't need an
  /// identity comparison at all. [scannedMrz]/[documentType] are null for a
  /// flow whose steps omit "document_capture" too (no document scan
  /// happened at all, not just no chip read).
  void pushFaceVerificationScreenForScannedMrz({
    Uint8List? referencePhotoBytes,
    ScannedMRZ? scannedMrz,
    DocumentType? documentType,
  }) {
    push(
      _faceVerificationPath,
      extra: {'nfcImageBytes': referencePhotoBytes, 'scannedMrz': scannedMrz, 'documentType': documentType},
    );
  }

  /// Terminal route for a session with no chip-read document data to show a
  /// review screen for (see [_afterDocumentCaptured]/[_afterConsent]) —
  /// submits [scannedMrz] (if any — null for a flow that skipped
  /// document_capture entirely) plus [faceVerification] (if that ran)
  /// directly.
  void pushDocumentCaptureOnlyResultScreen({
    required ActiveProofingSession session,
    ScannedMRZ? scannedMrz,
    FaceVerificationOutcome? faceVerification,
  }) {
    push(
      _documentCaptureResultPath,
      extra: {'session': session, 'scannedMrz': scannedMrz, 'faceVerification': faceVerification},
    );
  }

  void pushSettingsScreen() {
    push(_settingsPath);
  }

  void pushQrScannerScreen() {
    push(_qrScannerPath);
  }
}

final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

GoRouter createRouter({ScannerWidgetBuilder? scannerBuilder, FaceVerificationEngine? faceVerificationEngine}) {
  return GoRouter(
    initialLocation: '/select_doc_type',
    observers: [routeObserver],
    routes: [
      GoRoute(
        path: '/select_doc_type',
        builder: (context, state) {
          return DocumentTypeSelectionScreen(
            onDocumentTypeSelected: (docType) {
              context.pushMrzReaderScreen(MrzReaderRouteParams(documentType: docType));
            },
            onSettingsPressed: context.pushSettingsScreen,
            onScanQrPressed: context.pushQrScannerScreen,
          );
        },
      ),
      GoRoute(
        path: _settingsPath,
        builder: (context, state) => SettingsScreen(onBackPressed: context.pop),
      ),
      GoRoute(
        path: _qrScannerPath,
        builder: (context, state) => QrScannerScreen(
          routeObserver: routeObserver,
          onBack: context.pop,
          onScanned: (value) => _handleScannedQr(context, value),
        ),
      ),
      GoRoute(
        path: _proofingConsentPath,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          final sessionRef = extra['ref'] as ProofingSessionRef;
          final info = extra['info'] as ProofingSessionInfo;

          return ProofingSessionConsentScreen(
            info: info,
            onConsent: () {
              final session = ActiveProofingSession(ref: sessionRef, info: info, openedAt: DateTime.now());
              ProviderScope.containerOf(context).read(activeProofingSessionProvider.notifier).set(session);
              _afterConsent(context, session);
            },
            onDecline: () => context.go('/select_doc_type'),
          );
        },
      ),
      GoRoute(
        path: '/mrz_reader',
        builder: (context, state) {
          final params = MrzReaderRouteParams.fromQueryParams(state.uri.queryParameters);
          final plan = FlowStepPlan.fromSteps(_activeSteps(context), selfieLocation: _activeSelfieLocation(context));
          return ScannerWrapper(
            documentType: params.documentType,
            onMrzScanned: (result) => _afterDocumentCaptured(context, result, params.documentType),
            onManualEntry: () {
              context.pushManualEntryScreen(ManualEntryRouteParams(documentType: params.documentType));
            },
            onBack: context.pop,
            scannerBuilder: scannerBuilder,
            stepNumber: plan.documentCaptureStepNumber ?? FlowStepPlan.defaultPlan.documentCaptureStepNumber!,
            totalSteps: plan.totalSteps,
          );
        },
      ),
      GoRoute(
        path: '/manual_entry',
        builder: (context, state) {
          final params = ManualEntryRouteParams.fromQueryParams(state.uri.queryParameters);
          return ManualEntryScreen(
            documentType: params.documentType,
            onBack: context.pop,
            onManualEntryComplete: (scannedMrz) => _afterDocumentCaptured(context, scannedMrz, params.documentType),
          );
        },
      ),
      GoRoute(
        path: '/nfc_reading',
        builder: (context, state) {
          final params = NfcReadingRouteParams.fromQueryParams(state.uri.queryParameters);
          final steps = _activeSteps(context);
          final selfieLocation = _activeSelfieLocation(context);
          final plan = FlowStepPlan.fromSteps(steps, selfieLocation: selfieLocation);
          return NfcReadingScreen(
            params: params,
            stepNumber: plan.nfcReadStepNumber ?? FlowStepPlan.defaultPlan.nfcReadStepNumber!,
            totalSteps: plan.totalSteps,
            onSuccess: (document, result) {
              if (!nativeFaceVerificationRequested(steps, selfieLocation)) {
                // Either none of the face-verification screen's outputs were
                // asked for at all, or they were but the session's
                // selfieLocation says the browser hosted flow performs that
                // stage instead of this app (see
                // nativeFaceVerificationRequested) - either way, go straight
                // to the result screen instead of collecting a selfie
                // ourselves. Safe to skip as a whole rather than partially:
                // the server guarantees "face_match" never appears without
                // "nfc_read" being present too (flow.Validate), and we're
                // already past NFC reading here, so there's no case where
                // skipping loses a comparison photo we'd otherwise have
                // needed. The result screen's own submission logic (see
                // ProofingResultSubmission.submitProofingResult) is what
                // actually tells apart "nothing to submit" from "hand off to
                // the browser" - both reach it the same way, with
                // face_verification: null.
                context.go(
                  '/result',
                  extra: {
                    'document': document,
                    'result': result,
                    'document_type': params.documentType,
                    'face_verification': null,
                  },
                );
                return;
              }
              final (nfcImageBytes, issueDate) = _faceVerificationInputFor(document, params.documentType);
              context.pushFaceVerificationScreen(
                nfcImageBytes,
                issueDate: issueDate,
                document: document,
                result: result,
                documentType: params.documentType,
              );
            },
          );
        },
      ),
      GoRoute(
        path: '/result',
        builder: (context, state) {
          final s = state.extra as Map<String, dynamic>;
          final ty = s['document_type'] as DocumentType;
          final document = s['document'] as DocumentData;
          final result = s['result'] as RawDocumentData;
          final faceVerification = s['face_verification'] as FaceVerificationOutcome?;
          final plan = FlowStepPlan.fromSteps(_activeSteps(context), selfieLocation: _activeSelfieLocation(context));

          return switch (ty) {
            DocumentType.passport || DocumentType.identityCard => PassportDataScreen(
              document: document,
              passportDataResult: result,
              documentType: ty,
              faceVerification: faceVerification,
              onBackPressed: () => context.go('/select_doc_type'),
              stepNumber: plan.resultStepNumber,
              totalSteps: plan.totalSteps,
            ),
            DocumentType.drivingLicence => DrivingLicenceDataScreen(
              drivingLicence: document as DrivingLicenceData,
              drivingLicenceDataResult: result,
              faceVerification: faceVerification,
              onBackPressed: () => context.go('/select_doc_type'),
              stepNumber: plan.resultStepNumber,
              totalSteps: plan.totalSteps,
            ),
          };
        },
      ),
      GoRoute(
        path: _documentCaptureResultPath,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return DocumentCaptureOnlyResultScreen(
            session: extra['session'] as ActiveProofingSession,
            scannedMrz: extra['scannedMrz'] as ScannedMRZ?,
            faceVerification: extra['faceVerification'] as FaceVerificationOutcome?,
            onBackPressed: () => context.go('/select_doc_type'),
          );
        },
      ),
      GoRoute(
        path: _faceVerificationPath,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          final nfcImageBytes = extra['nfcImageBytes'] as Uint8List?;
          final issueDate = extra['issueDate'] as DateTime?;
          final document = extra['document'] as DocumentData?;
          final result = extra['result'] as RawDocumentData?;
          final scannedMrz = extra['scannedMrz'] as ScannedMRZ?;
          final documentType = extra['documentType'] as DocumentType?;
          final engineChoice = ProviderScope.containerOf(context).read(faceEngineProvider);
          final livenessMode = ProviderScope.containerOf(context).read(livenessModeProvider);
          final plan = FlowStepPlan.fromSteps(_activeSteps(context), selfieLocation: _activeSelfieLocation(context));

          // Passing verification continues on to the document data screen
          // when this ran after a chip read (document/result set); a
          // session with no chip data (see _afterDocumentCaptured/
          // _afterConsent) has nothing for that screen to show, so it
          // submits directly instead. An explicit cancel/back pops back to
          // wherever this was pushed from either way.
          void goToResult(FaceVerificationOutcome outcome) {
            if (document != null && result != null) {
              context.go(
                '/result',
                extra: {
                  'document': document,
                  'result': result,
                  'document_type': documentType,
                  'face_verification': outcome,
                },
              );
              return;
            }
            final session = ProviderScope.containerOf(context).read(activeProofingSessionProvider)!;
            context.pushDocumentCaptureOnlyResultScreen(session: session, scannedMrz: scannedMrz, faceVerification: outcome);
          }

          final stepNumber = plan.faceVerificationStepNumber ?? FlowStepPlan.defaultPlan.faceVerificationStepNumber!;

          if (faceVerificationEngine != null) {
            return FaceVerificationEntryScreen.withEngine(
              engine: faceVerificationEngine,
              nfcImageBytes: nfcImageBytes,
              onBackPressed: context.pop,
              onVerified: goToResult,
              engineChoice: engineChoice,
              livenessMode: livenessMode,
              photoIssueDate: issueDate,
              stepNumber: stepNumber,
              totalSteps: plan.totalSteps,
            );
          }

          return FaceVerificationEntryScreen(
            nfcImageBytes: nfcImageBytes,
            onBackPressed: context.pop,
            onVerified: goToResult,
            engineChoice: engineChoice,
            livenessMode: livenessMode,
            photoIssueDate: issueDate,
            stepNumber: stepNumber,
            totalSteps: plan.totalSteps,
          );
        },
      ),
    ],
  );
}
