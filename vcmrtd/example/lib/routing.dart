import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vcmrtd/vcmrtd.dart';
import 'package:face_verification/face_verification.dart';
import 'package:mrz_capture/mrz_capture.dart';
import 'package:vcmrtdapp/providers/face_engine_provider.dart';
import 'package:vcmrtdapp/providers/liveness_mode_provider.dart';
import 'package:vcmrtdapp/utils/document_dates.dart';
import 'package:vcmrtdapp/widgets/pages/document_selection_screen.dart';
import 'package:vcmrtdapp/widgets/pages/face_verification_entry_screen.dart';
import 'package:vcmrtdapp/widgets/pages/driving_licence_data_screen.dart';
import 'package:vcmrtdapp/widgets/pages/manual_entry_route_params.dart';
import 'package:vcmrtdapp/widgets/pages/nfc_reading_screen.dart';
import 'package:vcmrtdapp/widgets/pages/passport_data_screen.dart';
import 'package:vcmrtdapp/providers/proofing_session_provider.dart';
import 'package:vcmrtdapp/services/face_verification_outcome.dart';
import 'package:vcmrtdapp/widgets/pages/proofing_session_consent_screen.dart';
import 'package:vcmrtdapp/services/proofing_session_client.dart';
import 'package:vcmrtdapp/widgets/pages/qr_scanner_screen.dart';
import 'package:vcmrtdapp/widgets/pages/scanner_wrapper.dart';
import 'package:vcmrtdapp/widgets/pages/settings_screen.dart';

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
const _settingsPath = '/settings';
const _qrScannerPath = '/qr_scanner';
const _proofingConsentPath = '/proofing_consent';

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
              ProviderScope.containerOf(context)
                  .read(activeProofingSessionProvider.notifier)
                  .set(ActiveProofingSession(ref: sessionRef, info: info, openedAt: DateTime.now()));
              context.go('/select_doc_type');
            },
            onDecline: () => context.go('/select_doc_type'),
          );
        },
      ),
      GoRoute(
        path: '/mrz_reader',
        builder: (context, state) {
          final params = MrzReaderRouteParams.fromQueryParams(state.uri.queryParameters);
          return ScannerWrapper(
            documentType: params.documentType,
            onMrzScanned: (result) {
              context.pushNfcReadingScreen(
                NfcReadingRouteParams(scannedMRZ: result, documentType: params.documentType),
              );
            },
            onManualEntry: () {
              context.pushManualEntryScreen(ManualEntryRouteParams(documentType: params.documentType));
            },
            onBack: context.pop,
            scannerBuilder: scannerBuilder,
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
            onManualEntryComplete: (scannedMrz) {
              context.pushNfcReadingScreen(
                NfcReadingRouteParams(scannedMRZ: scannedMrz, documentType: params.documentType),
              );
            },
          );
        },
      ),
      GoRoute(
        path: '/nfc_reading',
        builder: (context, state) {
          final params = NfcReadingRouteParams.fromQueryParams(state.uri.queryParameters);
          return NfcReadingScreen(
            params: params,
            onSuccess: (document, result) {
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

          return switch (ty) {
            DocumentType.passport || DocumentType.identityCard => PassportDataScreen(
              document: document,
              passportDataResult: result,
              documentType: ty,
              faceVerification: faceVerification,
              onBackPressed: () => context.go('/select_doc_type'),
            ),
            DocumentType.drivingLicence => DrivingLicenceDataScreen(
              drivingLicence: document as DrivingLicenceData,
              drivingLicenceDataResult: result,
              faceVerification: faceVerification,
              onBackPressed: () => context.go('/select_doc_type'),
            ),
          };
        },
      ),
      GoRoute(
        path: _faceVerificationPath,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          final nfcImageBytes = extra['nfcImageBytes'] as Uint8List?;
          final issueDate = extra['issueDate'] as DateTime?;
          final document = extra['document'] as DocumentData;
          final result = extra['result'] as RawDocumentData;
          final documentType = extra['documentType'] as DocumentType;
          final engineChoice = ProviderScope.containerOf(context).read(faceEngineProvider);
          final livenessMode = ProviderScope.containerOf(context).read(livenessModeProvider);

          // Passing verification continues on to the document data screen; an
          // explicit cancel/back instead pops back to NFC reading, since that's
          // where this route was pushed from.
          void goToResult(FaceVerificationOutcome outcome) => context.go(
            '/result',
            extra: {
              'document': document,
              'result': result,
              'document_type': documentType,
              'face_verification': outcome,
            },
          );

          if (faceVerificationEngine != null) {
            return FaceVerificationEntryScreen.withEngine(
              engine: faceVerificationEngine,
              nfcImageBytes: nfcImageBytes,
              onBackPressed: context.pop,
              onVerified: goToResult,
              engineChoice: engineChoice,
              livenessMode: livenessMode,
              photoIssueDate: issueDate,
            );
          }

          return FaceVerificationEntryScreen(
            nfcImageBytes: nfcImageBytes,
            onBackPressed: context.pop,
            onVerified: goToResult,
            engineChoice: engineChoice,
            livenessMode: livenessMode,
            photoIssueDate: issueDate,
          );
        },
      ),
    ],
  );
}
