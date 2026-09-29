import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vcmrtd/vcmrtd.dart';
import 'package:face_verification/face_verification.dart';
import 'package:mrz_capture/mrz_capture.dart';
import 'package:idem/l10n/l10n.dart';
import 'package:idem/providers/face_engine_provider.dart';
import 'package:idem/providers/face_api_provider.dart';
import 'package:idem/providers/passport_issuer_provider.dart';
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
import 'package:idem/services/proofing_chip_evidence.dart';
import 'package:idem/services/proofing_session_client.dart';
import 'package:idem/widgets/common/issuance_result_dialogs.dart';
import 'package:idem/widgets/common/proofing_step_submission.dart';
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

/// Face verification straight after a chip read, against the chip's photo.
void _pushFaceVerificationAfterChipRead(
  BuildContext context,
  DocumentData document,
  RawDocumentData rawDocument,
  DocumentType documentType,
) {
  final (nfcImageBytes, issueDate) = _faceVerificationInputFor(document, documentType);
  context.pushFaceVerificationScreen(
    nfcImageBytes,
    issueDate: issueDate,
    document: document,
    result: rawDocument,
    documentType: documentType,
  );
}

/// Where every flow starts, and where leaving one ends up.
const selectDocTypePath = '/select_doc_type';
const _mrzReaderPath = '/mrz_reader';
const _manualEntryPath = '/manual_entry';
const _nfcReadingPath = '/nfc_reading';
const _resultPath = '/result';
const _faceVerificationPath = '/face_verification';
const _documentCaptureResultPath = '/document_capture_result';
const _settingsPath = '/settings';
const _qrScannerPath = '/qr_scanner';
const _proofingConsentPath = '/proofing_consent';

/// The step badges [session]'s flow gets; vcmrtd's own default sequence
/// without a pinned session (or one created without a flow).
FlowStepPlan _planFor(ActiveProofingSession? session) =>
    FlowStepPlan.fromSteps(session?.info.steps, selfieLocation: session?.info.selfieLocation ?? 'browser');

/// [_planFor] the pinned session - the single place every route builder
/// below reads its [FlowStepPlan] from.
FlowStepPlan _activePlan(BuildContext context) =>
    _planFor(ProviderScope.containerOf(context).read(activeProofingSessionProvider));

/// The arguments of the /result route (the document data screen).
class ResultRouteArgs {
  final DocumentData document;
  final RawDocumentData rawDocument;
  final DocumentType documentType;
  final FaceVerificationOutcome? faceVerification;

  /// The step badges; the pinned session's when null.
  final FlowStepPlan? plan;

  /// Set when every step was already sent to the session as it completed:
  /// the screen only confirms that, nothing is left to submit.
  final String? submittedTo;
  final bool browserFaceStep;

  const ResultRouteArgs({
    required this.document,
    required this.rawDocument,
    required this.documentType,
    this.faceVerification,
    this.plan,
    this.submittedTo,
    this.browserFaceStep = false,
  });
}

/// Continues [session] where the step [response] just received says, once
/// [completedStep] has been sent - see [_continueAtServerStep]. Nothing to do
/// when the step failed ([response] null) or the screen is gone.
void _continueAfterStep(
  BuildContext context,
  ActiveProofingSession session,
  ProofingStepResponse? response, {
  required String completedStep,
  ScannedMRZ? scannedMrz,
  DocumentType? documentType,
  DocumentData? document,
  RawDocumentData? rawDocument,
  FaceVerificationOutcome? faceOutcome,
  FlowStepPlan? plan,
}) {
  if (response == null || !context.mounted) return;
  _continueAtServerStep(
    context,
    session,
    lifecycle: response.lifecycle,
    readyToSubmit: response.readyToSubmit,
    currentStep: response.currentStep ?? _localStepAfter(session.info.steps!, completedStep),
    scannedMrz: scannedMrz,
    documentType: documentType,
    document: document,
    rawDocument: rawDocument,
    faceOutcome: faceOutcome,
    plan: plan,
  );
}

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
///
/// A flow session with document_capture gets the scanned identity the moment
/// the scan completes (`POST .../steps/document_capture`), before anything
/// else happens, and then continues wherever the server says
/// ([_continueAtServerStep]) - not where this route happens to lead.
Future<void> _afterDocumentCaptured(BuildContext context, ScannedMRZ scannedMrz, DocumentType documentType) async {
  final activeSession = ProviderScope.containerOf(context).read(activeProofingSessionProvider);
  final steps = activeSession?.info.steps;

  if (activeSession != null && steps != null && steps.contains(stepDocumentCapture)) {
    final response = await _submitDocumentCaptureStep(context, activeSession, scannedMrz, documentType);
    if (!context.mounted) return;
    _continueAfterStep(
      context,
      activeSession,
      response,
      completedStep: stepDocumentCapture,
      scannedMrz: scannedMrz,
      documentType: documentType,
    );
    return;
  }

  // No flow (or none with a document step): vcmrtd's own sequence.
  if (steps == null || steps.contains(stepNfcRead)) {
    context.pushNfcReadingScreen(NfcReadingRouteParams(scannedMRZ: scannedMrz, documentType: documentType));
    return;
  }
  if (stepsRequestFace(steps)) {
    context.pushFaceVerificationScreenForScannedMrz(
      referencePhotoBytes: _photoBytes(activeSession!.info.referencePhoto),
      scannedMrz: scannedMrz,
      documentType: documentType,
    );
  }
}

/// The step after [step] in [steps], for a server that doesn't name one.
String _localStepAfter(List<String> steps, String step) {
  final i = steps.indexOf(step);
  return i >= 0 && i + 1 < steps.length ? steps[i + 1] : '';
}

/// Continues [session] where the server says it stands - [lifecycle],
/// [readyToSubmit] and [currentStep] from the step response (or the session
/// view) that just arrived, never this app's own idea of what comes next.
/// After the last step the session isn't finished yet: it waits to be
/// submitted ([readyToSubmit]), which this app then does right away - the
/// last step is also the submit. What the screen the user came from
/// already has ([scannedMrz], the chip read's
/// [document]/[rawDocument], a [faceOutcome]) only fills in what the next
/// screen needs. [resume] is a fresh start on this device (after connecting
/// or a handover): screens are gone to instead of pushed.
void _continueAtServerStep(
  BuildContext context,
  ActiveProofingSession session, {
  required String? lifecycle,
  required String currentStep,
  bool readyToSubmit = false,
  bool resume = false,
  ScannedMRZ? scannedMrz,
  DocumentType? documentType,
  DocumentData? document,
  RawDocumentData? rawDocument,
  FaceVerificationOutcome? faceOutcome,
  FlowStepPlan? plan,
}) {
  final info = session.info;
  final chipRead = document != null && rawDocument != null && documentType != null;

  void showChipResult({bool browserFaceStep = false}) {
    ProviderScope.containerOf(context).read(activeProofingSessionProvider.notifier).set(null);
    context.goResultScreen(
      ResultRouteArgs(
        document: document!,
        rawDocument: rawDocument!,
        documentType: documentType!,
        faceVerification: faceOutcome,
        // The session is unpinned by the time /result builds.
        plan: plan ?? _planFor(session),
        submittedTo: info.relyingParty,
        browserFaceStep: browserFaceStep,
      ),
    );
  }

  // Already submitted (by the other device): the verification is done.
  if (lifecycle == proofingLifecycleComplete) {
    ProviderScope.containerOf(context).read(proofingSessionCoordinatorProvider).reportCompleted(session.ref);
    return;
  }

  // Every step has a result: submit it now. An empty currentStep means the
  // server has nothing left to collect either; submitting lets it decide.
  if (readyToSubmit || currentStep.isEmpty) {
    _submitProofingSession(context, session);
    return;
  }

  if (currentStep == stepDocumentCapture) {
    context.go(selectDocTypePath);
    return;
  }

  if (currentStep == stepNfcRead) {
    // The chip's access key: from the scan just done here, or - on a device
    // that took over after the MRZ step - the one the server kept.
    final mrz = scannedMrz ?? info.chipAccess?.toScannedMrz();
    final type = scannedMrz != null ? documentType : info.chipAccess?.documentType;
    if (mrz == null || type == null) {
      context.go(selectDocTypePath);
      return;
    }
    final params = NfcReadingRouteParams(scannedMRZ: mrz, documentType: type);
    if (resume) {
      context.go(_nfcReadingLocation(params));
    } else {
      context.pushNfcReadingScreen(params);
    }
    return;
  }

  if (_isFaceStep(currentStep)) {
    if (!nativeFaceVerificationRequested(info.steps, info.selfieLocation)) {
      // The browser runs the face step; this app's part is done. The
      // listener keeps watching.
      if (chipRead) return showChipResult(browserFaceStep: true);
      _finishProofingSession(
        context,
        title: context.l10n.proofingContinueInBrowserTitle,
        message: context.l10n.proofingContinueInBrowserFace,
      );
      return;
    }
    if (chipRead) {
      _pushFaceVerificationAfterChipRead(context, document, rawDocument, documentType);
      return;
    }
    // No chip read on this device (it took the session over): compare
    // against the photo the server holds - the chip's, from the device that
    // read it, or the relying party's referencePhoto.
    final photo = info.faceReference ?? info.referencePhoto;
    final reference = _photoBytes(photo);
    if (!resume && scannedMrz != null) {
      context.pushFaceVerificationScreenForScannedMrz(
        referencePhotoBytes: reference,
        scannedMrz: scannedMrz,
        documentType: documentType,
      );
    } else {
      context.go(_faceVerificationPath, extra: {'nfcImageBytes': reference});
    }
    return;
  }

  // A step this app doesn't perform: another client has it.
  _finishProofingSession(
    context,
    title: context.l10n.proofingContinueInBrowserTitle,
    message: context.l10n.proofingContinueInBrowserNextStep,
  );
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
/// `context.go(selectDocTypePath)` this replaces — none of these entry
/// points should leave the consent screen underneath them in the stack.
///
/// The server decides where the session stands: a session claimed through a
/// handover (or re-opened) continues at the server's
/// [ProofingSessionInfo.currentStep] rather than at the start - see
/// [_resumeAtServerStep].
void _afterConsent(BuildContext context, ActiveProofingSession session) {
  if (_resumeAtServerStep(context, session)) return;
  final steps = session.info.steps;
  if (steps == null || steps.contains(stepDocumentCapture)) {
    context.go(selectDocTypePath);
    return;
  }

  if (stepsRequestFace(steps)) {
    context.go(_faceVerificationPath, extra: {'nfcImageBytes': _photoBytes(session.info.referencePhoto)});
    return;
  }

  // Degenerate: a flow with none of document_capture/nfc_read/selfie/
  // liveness/face_match at all - nothing to capture, submit immediately.
  context.go(_documentCaptureResultPath, extra: {'session': session});
}

bool _isFaceStep(String step) => faceSteps.contains(step);

Uint8List? _photoBytes(ProofingPhotoInfo? photo) => photo == null ? null : base64Decode(photo.imageBase64);

/// Continues [session] where the server says it stands, when that's
/// somewhere other than the start of this app's own part - returns whether
/// it did. A device that took the session over after the MRZ step goes
/// straight to the chip read, with the access key the server kept.
bool _resumeAtServerStep(BuildContext context, ActiveProofingSession session) {
  final info = session.info;
  // Every step already has a result: submit it.
  if (info.readyToSubmit && info.lifecycle != proofingLifecycleComplete) {
    _submitProofingSession(context, session);
    return true;
  }
  final current = info.currentStep;
  if (current == null) return false; // a server that doesn't say

  // Only lifecycle says the session is complete; an empty currentStep alone
  // doesn't (the server used to send "" for flow-less sessions too).
  if (info.lifecycle == proofingLifecycleComplete) {
    _finishProofingSession(
      context,
      title: context.l10n.proofingNothingLeftTitle,
      message: context.l10n.proofingSessionAlreadyComplete,
    );
    return true;
  }
  if (current.isEmpty || current == stepDocumentCapture) return false;
  _continueAtServerStep(context, session, lifecycle: info.lifecycle, currentStep: current, resume: true);
  return true;
}

/// This app's part of the pinned session is over: unpin it (the listener
/// keeps running - see ProofingSessionWatcher), go back to the start, and
/// tell the user.
void _finishProofingSession(BuildContext context, {required String title, required String message}) {
  final router = GoRouter.of(context);
  ProviderScope.containerOf(context).read(activeProofingSessionProvider.notifier).set(null);
  router.go(selectDocTypePath);
  _showInfoAfterNavigation(router, title: title, message: message);
}

/// Shows an info dialog on top of whatever screen the router just went to.
void _showInfoAfterNavigation(GoRouter router, {required String title, required String message}) {
  final navigatorKey = router.routerDelegate.navigatorKey;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    DialogHelpers.showInfoDialog(context: context, title: title, message: message);
  });
}

/// Submits [session] the moment its last step has a result
/// (`POST .../submit`) - only now does the server give it its outcome,
/// which the app never shows. Safe to retry: a retry after a network error
/// or the other device having submitted first just returns the finished
/// state. Ending the verification and telling the user it's done is left to
/// main.dart's ProofingSessionCompleted handling, the same path a submit on
/// the other device takes; an expired session is refused by the server and
/// ends with that message instead. When a step still lacks a result after
/// all (e.g. a reset landed in between), the user continues at the server's
/// current step.
Future<void> _submitProofingSession(BuildContext context, ActiveProofingSession session) async {
  final container = ProviderScope.containerOf(context);
  final router = GoRouter.of(context);
  final client = container.read(proofingSessionClientProvider);
  final l10n = context.l10n;
  var stepsIncomplete = false;
  final response = await submitProofingStep(
    context,
    session: session,
    what: l10n.proofingWhatVerification,
    submit: () async {
      try {
        return await client.submitSession(session.ref);
      } on ProofingStepsIncompleteException {
        stepsIncomplete = true;
        final info = await client.fetchSession(session.ref);
        container.read(activeProofingSessionProvider.notifier).updateInfo(session.ref, info);
        return ProofingStepResponse.fromSessionInfo(info);
      }
    },
  );
  if (response == null || !context.mounted) return;
  if (response.complete) {
    container.read(proofingSessionCoordinatorProvider).reportCompleted(session.ref);
    return;
  }
  final step = response.currentStep ?? '';
  if (!stepsIncomplete || step.isEmpty) return;
  _continueAtServerStep(
    context,
    container.read(activeProofingSessionProvider) ?? session,
    lifecycle: response.lifecycle,
    currentStep: step,
    resume: true,
  );
  _showInfoAfterNavigation(
    router,
    title: l10n.proofingNotFinishedTitle,
    message: l10n.proofingNotFinishedMessage(session.info.relyingParty),
  );
}

/// Sends the MRZ scan's (or manual entry's) identity to the pinned flow
/// session the moment it's captured (`POST .../steps/document_capture`),
/// with the chip access key so another device could continue at the chip
/// read. Sent whatever requestedAttributes says, like mrtdEvidence on the
/// nfc step: it's the step's own evidence, and the server filters what the
/// relying party gets back. Returns the server's response (it names the
/// next step), or null when it wasn't stored.
Future<ProofingStepResponse?> _submitDocumentCaptureStep(
  BuildContext context,
  ActiveProofingSession session,
  ScannedMRZ scannedMrz,
  DocumentType documentType,
) {
  final client = ProviderScope.containerOf(context).read(proofingSessionClientProvider);
  return submitProofingStep(
    context,
    session: session,
    what: context.l10n.proofingWhatDocumentDetails,
    submit: () => client.submitDocumentCaptureStep(
      session.ref,
      document: ProofingDocumentInfo.fromScannedMrz(scannedMrz),
      chipAccess: ProofingChipAccess.fromScannedMrz(scannedMrz, documentType),
    ),
  );
}

/// Sends the chip read's result to the pinned flow session the moment the
/// read completes (`POST .../steps/nfc`, which also carries
/// document_capture's identity). Returns the server's response, or null
/// when it wasn't stored.
Future<ProofingStepResponse?> _submitNfcStep(
  BuildContext context,
  ActiveProofingSession session,
  DocumentData document,
  RawDocumentData result,
  DocumentType documentType,
) {
  final evidence = ProofingChipEvidence.from(document, result, documentType);
  final client = ProviderScope.containerOf(context).read(proofingSessionClientProvider);
  return submitProofingStep(
    context,
    session: session,
    what: context.l10n.proofingWhatDocumentIdentity,
    submit: () async => client.submitNfcStep(
      session.ref,
      requestedAttributes: session.info.requestedAttributes,
      document: evidence.document,
      photo: evidence.photo,
      mrtdEvidence: evidence.mrtdEvidence,
      device: await currentProofingDeviceInfo(),
      faceStepFollows: stepsRequestFace(session.info.steps),
    ),
  );
}

/// Sends the face step this app performed to the pinned flow session the
/// moment it completes (`POST .../steps/selfie`). Returns the server's
/// response, or null when it wasn't stored.
Future<ProofingStepResponse?> _submitFaceStep(
  BuildContext context,
  ActiveProofingSession session,
  FaceVerificationOutcome outcome,
) async {
  final transactionId = outcome.livenessTransactionId;
  final selfie = outcome.selfieImageBytes;
  if (transactionId == null && selfie == null) {
    DialogHelpers.showInfoDialog(
      context: context,
      title: context.l10n.proofingFaceIncompleteTitle,
      message: context.l10n.proofingFaceIncompleteMessage,
    );
    return null;
  }
  final client = ProviderScope.containerOf(context).read(proofingSessionClientProvider);
  return submitProofingStep(
    context,
    session: session,
    what: context.l10n.proofingWhatFaceVerification,
    submit: () => transactionId != null
        ? client.submitSelfieStep(session.ref, livenessTransactionId: transactionId)
        : client.submitSelfieStep(session.ref, selfie: ProofingPhotoInfo.fromSelfie(selfie!)),
  );
}

/// Sends the user back to the very start of [session]'s flow — the same
/// screen accepting its consent leads to (normally /select_doc_type). Used
/// when the relying party resets the session (see main.dart's
/// `_onProofingSessionReset`): `go` drops whatever screen the user was on,
/// including a running MRZ scan or NFC read (their reader state is
/// autoDispose), so nothing collected before the reset is carried over.
void restartProofingSessionFlow(BuildContext context, ActiveProofingSession session) => _afterConsent(context, session);

/// Claims the session a scanned QR / tapped deep link points at - through
/// the session's own token, or a handover token taking it over from another
/// device - and pushes [ProofingSessionConsentScreen] with the server's
/// current view of it, for the user to accept or decline before anything is
/// pinned (see that route below, the only place
/// [activeProofingSessionProvider] gets set). Returns what to tell the user
/// when that didn't work, or null. Used by [_handleScannedQr] and by
/// main.dart for a tapped vcmrtd:// link; [beforePush] runs right before
/// navigating either way, so the QR scanner can pop itself first.
Future<String?> openProofingSessionLink(
  GoRouter router,
  ProviderContainer container,
  String value, {
  VoidCallback? beforePush,
}) async {
  final link = ProofingSessionLink.parse(value);
  if (link == null) return currentL10n.proofingNotAVerificationLink;
  try {
    final claim = await container.read(proofingSessionCoordinatorProvider).connect(link);
    // The session's language from its first screen on, consent included.
    container.read(appLocaleProvider.notifier).useSessionLanguage(claim.info.language);
    // Took over a session this app had pinned with an older credential: that
    // one is revoked now, so it mustn't be used for anything any more.
    final pinned = container.read(activeProofingSessionProvider);
    if (pinned != null && pinned.ref.token == claim.ref.token && pinned.ref.deviceToken != claim.ref.deviceToken) {
      container.read(activeProofingSessionProvider.notifier).set(null);
    }
    if (claim.info.requestedAttributes.isEmpty) return currentL10n.proofingSessionNoAttributes;
    beforePush?.call();
    router.push(_proofingConsentPath, extra: {'ref': claim.ref, 'info': claim.info});
    return null;
  } on ProofingSessionAccessException catch (e) {
    return e.reason.message;
  } catch (e) {
    return currentL10n.proofingConnectFailed('$e');
  }
}

/// Handles a scanned QR: an identity-proofing session or handover QR goes
/// through [openProofingSessionLink]. Any other QR content is left for the
/// original debug behaviour — it's shown, not acted on, since this scanner
/// isn't scoped to just proofing handoffs.
Future<void> _handleScannedQr(BuildContext context, String value) async {
  final messenger = ScaffoldMessenger.of(context);
  final router = GoRouter.of(context);
  final container = ProviderScope.containerOf(context);

  if (ProofingSessionLink.parse(value) == null) {
    router.pop();
    messenger.showSnackBar(SnackBar(content: Text(context.l10n.proofingQrScanned(value))));
    return;
  }

  var popped = false;
  final error = await openProofingSessionLink(
    router,
    container,
    value,
    beforePush: () {
      popped = true;
      router.pop();
    },
  );
  if (error == null) return;
  if (!popped) router.pop();
  messenger.showSnackBar(SnackBar(content: Text(error)));
}

String _nfcReadingLocation(NfcReadingRouteParams params) =>
    Uri(path: _nfcReadingPath, queryParameters: params.toQueryParams()).toString();

extension CustomRouteExtensions on BuildContext {
  void pushNfcReadingScreen(NfcReadingRouteParams params) {
    push(_nfcReadingLocation(params));
  }

  void pushMrzReaderScreen(MrzReaderRouteParams params) {
    push(Uri(path: _mrzReaderPath, queryParameters: params.toQueryParams()).toString());
  }

  void pushManualEntryScreen(ManualEntryRouteParams params) {
    push(Uri(path: _manualEntryPath, queryParameters: params.toQueryParams()).toString());
  }

  /// Replaces the stack with the document data screen.
  void goResultScreen(ResultRouteArgs args) {
    go(_resultPath, extra: args);
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
    initialLocation: selectDocTypePath,
    observers: [routeObserver],
    routes: [
      GoRoute(
        path: selectDocTypePath,
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
              final session = ActiveProofingSession(ref: sessionRef, info: info);
              ProviderScope.containerOf(context).read(activeProofingSessionProvider.notifier).set(session);
              _afterConsent(context, session);
            },
            onDecline: () => context.go(selectDocTypePath),
          );
        },
      ),
      GoRoute(
        path: _mrzReaderPath,
        builder: (context, state) {
          final params = MrzReaderRouteParams.fromQueryParams(state.uri.queryParameters);
          // Document reading starts as soon as the MRZ camera opens.
          markActiveProofingStepStarted(ProviderScope.containerOf(context), stepDocumentCapture);
          final plan = _activePlan(context);
          return ScannerWrapper(
            documentType: params.documentType,
            onMrzScanned: (result) => _afterDocumentCaptured(context, result, params.documentType),
            onManualEntry: () {
              context.pushManualEntryScreen(ManualEntryRouteParams(documentType: params.documentType));
            },
            onBack: context.pop,
            scannerBuilder: scannerBuilder,
            stepNumber: plan.documentCaptureStepNumber ?? FlowStepPlan.defaultDocumentCaptureStep,
            totalSteps: plan.totalSteps,
          );
        },
      ),
      GoRoute(
        path: _manualEntryPath,
        builder: (context, state) {
          final params = ManualEntryRouteParams.fromQueryParams(state.uri.queryParameters);
          markActiveProofingStepStarted(ProviderScope.containerOf(context), stepDocumentCapture);
          final plan = _activePlan(context);
          return ManualEntryScreen(
            documentType: params.documentType,
            onBack: context.pop,
            onManualEntryComplete: (scannedMrz) => _afterDocumentCaptured(context, scannedMrz, params.documentType),
            stepNumber: plan.documentCaptureStepNumber ?? FlowStepPlan.defaultDocumentCaptureStep,
            totalSteps: plan.totalSteps,
          );
        },
      ),
      GoRoute(
        path: _nfcReadingPath,
        builder: (context, state) {
          final params = NfcReadingRouteParams.fromQueryParams(state.uri.queryParameters);
          final plan = _activePlan(context);
          return NfcReadingScreen(
            params: params,
            stepNumber: plan.nfcReadStepNumber ?? FlowStepPlan.defaultNfcReadStep,
            totalSteps: plan.totalSteps,
            onSuccess: (document, result) async {
              // Without a flow, face verification always follows (a
              // flow-less session still sends one result from the data
              // screen). A flow session gets the chip read's result the
              // moment it completes, and then continues wherever the server
              // says.
              final session = ProviderScope.containerOf(context).read(activeProofingSessionProvider);
              if (session == null || session.info.steps == null) {
                _pushFaceVerificationAfterChipRead(context, document, result, params.documentType);
                return;
              }
              final response = await _submitNfcStep(context, session, document, result, params.documentType);
              if (!context.mounted) return;
              _continueAfterStep(
                context,
                session,
                response,
                completedStep: stepNfcRead,
                scannedMrz: params.scannedMRZ,
                documentType: params.documentType,
                document: document,
                rawDocument: result,
                plan: plan,
              );
            },
          );
        },
      ),
      GoRoute(
        path: _resultPath,
        builder: (context, state) {
          final args = state.extra as ResultRouteArgs;
          final plan = args.plan ?? _activePlan(context);

          return switch (args.documentType) {
            DocumentType.passport || DocumentType.identityCard => PassportDataScreen(
              document: args.document as PassportData,
              passportDataResult: args.rawDocument,
              documentType: args.documentType,
              faceVerification: args.faceVerification,
              submittedTo: args.submittedTo,
              browserFaceStep: args.browserFaceStep,
              onBackPressed: () => context.go(selectDocTypePath),
              stepNumber: plan.resultStepNumber,
              totalSteps: plan.totalSteps,
            ),
            DocumentType.drivingLicence => DrivingLicenceDataScreen(
              drivingLicence: args.document as DrivingLicenceData,
              drivingLicenceDataResult: args.rawDocument,
              faceVerification: args.faceVerification,
              submittedTo: args.submittedTo,
              browserFaceStep: args.browserFaceStep,
              onBackPressed: () => context.go(selectDocTypePath),
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
            onBackPressed: () => context.go(selectDocTypePath),
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
          final providers = ProviderScope.containerOf(context);
          final engineChoice = providers.read(faceEngineProvider);
          final livenessMode = providers.read(livenessModeProvider);
          final proofingSession = providers.read(activeProofingSessionProvider);
          // Without a QR session, Regula runs against the passport issuer, which matches too.
          final issuerFace = proofingSession == null && result != null
              ? providers.read(issuerFaceVerificationProvider)
              : null;
          final faceVerification = proofingSession != null
              ? proofingSession.info.faceVerification
              : issuerFace == null
              ? null
              : ProofingFaceVerification(provider: faceProviderRegula, faceApiUrl: issuerFace.faceApiUrl);
          final Future<FaceMatch?> Function(String)? matchFace = issuerFace == null
              ? null
              : (transactionId) async {
                  final issuer = providers.read(passportIssuerProvider);
                  final raw = result!.copyWith(livenessTransactionId: transactionId);
                  final response = documentType == DocumentType.drivingLicence
                      ? await issuer.verifyDrivingLicence(raw)
                      : await issuer.verifyPassport(raw);
                  return response.faceMatch;
                };
          final plan = _planFor(proofingSession);

          // Passing verification continues on to the document data screen
          // when this ran after a chip read (document/result set); a
          // session with no chip data (see _afterDocumentCaptured/
          // _afterConsent) has nothing for that screen to show, so it
          // submits directly instead. An explicit cancel/back pops back to
          // wherever this was pushed from either way.
          Future<void> goToResult(FaceVerificationOutcome outcome) async {
            // A flow session whose chip read was already sent gets the face
            // step the moment it completes too, and that ends this app's part.
            final session = providers.read(activeProofingSessionProvider);
            if (session != null && session.info.steps != null) {
              final response = await _submitFaceStep(context, session, outcome);
              if (!context.mounted) return;
              _continueAfterStep(
                context,
                session,
                response,
                completedStep: stepFaceVerification,
                scannedMrz: scannedMrz,
                documentType: documentType,
                document: document,
                rawDocument: result,
                faceOutcome: outcome,
                plan: plan,
              );
              return;
            }
            if (document != null && result != null) {
              context.goResultScreen(
                ResultRouteArgs(
                  document: document,
                  rawDocument: result,
                  documentType: documentType!,
                  faceVerification: outcome,
                  plan: plan,
                ),
              );
              return;
            }
            context.pushDocumentCaptureOnlyResultScreen(
              session: session!,
              scannedMrz: scannedMrz,
              faceVerification: outcome,
            );
          }

          final stepNumber = plan.faceVerificationStepNumber ?? FlowStepPlan.defaultFaceVerificationStep;
          // Native face verification: the camera opens with this screen.
          markActiveProofingStepStarted(providers, stepFaceVerification);

          return FaceVerificationEntryScreen(
            nfcImageBytes: nfcImageBytes,
            onBackPressed: context.pop,
            onVerified: goToResult,
            engineChoice: engineChoice,
            livenessMode: livenessMode,
            faceVerification: faceVerification,
            matchFace: matchFace,
            photoIssueDate: issueDate,
            stepNumber: stepNumber,
            totalSteps: plan.totalSteps,
            testEngine: faceVerificationEngine,
          );
        },
      ),
    ],
  );
}
