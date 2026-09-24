import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:mrz_capture/mrz_capture.dart';
import 'package:vcmrtd/extensions.dart';
import 'package:vcmrtd/vcmrtd.dart';
import 'package:idem/utils/document_dates.dart';

/// Points at one identity-proofing session this device claimed. See
/// identity-proofing-service's docs/session-model.md for the API this talks
/// to. [token] only identifies the session in the `/api/v1/app/{token}`
/// paths; [deviceToken] is what authorizes this device.
class ProofingSessionRef {
  final String apiBase;
  final String token;

  /// This device's credential for the session (`X-Device-Token`), issued by
  /// [ProofingSessionClient.claimHandover]. The server rejects every call
  /// without the current device's token, so knowing the session token alone
  /// isn't enough to act on it. Kept in memory only - a killed app loses it,
  /// and the web app hands the session back over with a fresh handover QR.
  final String? deviceToken;

  const ProofingSessionRef({required this.apiBase, required this.token, this.deviceToken});

  ProofingSessionRef withDeviceToken(String deviceToken) =>
      ProofingSessionRef(apiBase: apiBase, token: token, deviceToken: deviceToken);

  static ProofingSessionRef? parse(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri == null) return null;

    if (uri.scheme == 'vcmrtd') {
      final token = uri.queryParameters['token'];
      final api = uri.queryParameters['api'];
      if (token == null || token.isEmpty || api == null || api.isEmpty) return null;
      return ProofingSessionRef(apiBase: api, token: token);
    }

    if ((uri.scheme == 'https' || uri.scheme == 'http') && uri.pathSegments.length >= 2) {
      // https://{host}/s/{token}
      if (uri.pathSegments[uri.pathSegments.length - 2] != 's') return null;
      final token = uri.pathSegments.last;
      if (token.isEmpty) return null;
      final apiBase = '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
      return ProofingSessionRef(apiBase: apiBase, token: token);
    }

    return null;
  }
}

/// A scanned QR code or tapped deep link pointing at a session: a
/// short-lived, single-use grant token ([ProofingHandoverLink]) - the empty
/// native slot's claim token, or a handover from the device that held it.
/// A link carrying the session token itself ([ProofingSessionTokenLink]) is
/// still recognised, only to tell the user it no longer works: the session
/// token doesn't authorize a device. Neither creates a session.
sealed class ProofingSessionLink {
  const ProofingSessionLink();

  String get apiBase;

  /// Accepts `vcmrtd://verify?handover=...&api=...` (the claim/handover QR's
  /// and deep link's shape) plus the old session-token shapes
  /// [ProofingSessionRef.parse] accepts.
  static ProofingSessionLink? parse(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri != null && uri.scheme == 'vcmrtd' && uri.queryParameters.containsKey('handover')) {
      final handover = uri.queryParameters['handover'];
      final api = uri.queryParameters['api'];
      if (handover == null || handover.isEmpty || api == null || api.isEmpty) return null;
      return ProofingHandoverLink(apiBase: api, handoverToken: handover);
    }
    // The Web App's own handover QR (`https://.../proofing?handover=...`)
    // moves the browser part to another browser, not to this app.
    if (uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        (uri.queryParameters['handover'] ?? '').isNotEmpty) {
      return ProofingBrowserHandoverLink('${uri.scheme}://${uri.authority}');
    }
    final ref = ProofingSessionRef.parse(raw);
    return ref == null ? null : ProofingSessionTokenLink(ref);
  }
}

/// A handover QR for the Web App's browser slot: recognised only to tell the
/// user to open it in a browser instead.
class ProofingBrowserHandoverLink extends ProofingSessionLink {
  @override
  final String apiBase;
  const ProofingBrowserHandoverLink(this.apiBase);
}

class ProofingSessionTokenLink extends ProofingSessionLink {
  final ProofingSessionRef ref;
  const ProofingSessionTokenLink(this.ref);

  @override
  String get apiBase => ref.apiBase;
}

class ProofingHandoverLink extends ProofingSessionLink {
  @override
  final String apiBase;
  final String handoverToken;
  const ProofingHandoverLink({required this.apiBase, required this.handoverToken});
}

/// This device's own access to a session, as the server sees it
/// (api.appSessionView.device).
class ProofingDeviceAccess {
  /// False once another device took over this device's slot - see
  /// [ProofingSessionInfo.accessLost].
  final bool authorized;
  final String? role; // "native" | "web"
  final String? state; // "active" | "inactive"

  const ProofingDeviceAccess({required this.authorized, this.role, this.state});

  factory ProofingDeviceAccess.fromJson(Map<String, dynamic> json) => ProofingDeviceAccess(
    authorized: json['authorized'] as bool? ?? false,
    role: json['role'] as String?,
    state: json['state'] as String?,
  );
}

/// [ProofingSessionInfo.lifecycle] values.
const proofingLifecycleActive = 'ACTIVE';
const proofingLifecycleComplete = 'COMPLETE';
const proofingLifecycleExpired = 'EXPIRED';
const proofingLifecycleCancelled = 'CANCELLED';

/// What the app needs after fetching a session: what to collect, who's
/// asking, how long it has. Mirrors api.appSessionView on the server.
class ProofingSessionInfo {
  final String id;
  final String relyingParty;
  final List<String> requestedAttributes;
  final DateTime expiresAt;

  /// The session's Active Authentication challenge (hex-encoded RND.IFD),
  /// relayed unchanged to the chip's INTERNAL AUTHENTICATE command. The
  /// server checks the AA response against this exact value
  /// (`aaChallengeMatches` in sessions.go), so any other nonce — e.g. one
  /// fetched from an unrelated server — makes a genuine chip look cloned.
  /// Null when the server response doesn't carry one, in which case Active
  /// Authentication should be skipped for this session.
  final String? aaChallenge;

  /// The ordered capture steps a tenant-defined "flow" wants for this
  /// session, drawn from "document_capture"/"nfc_read"/"selfie"/"liveness"/
  /// "face_match". Null when the session wasn't created against a flow
  /// definition (today's default for every session), in which case vcmrtd's
  /// own hard-coded screen sequence applies.
  ///
  /// Only partially acted on (see routing.dart): the face-verification
  /// screen is skipped when none of "selfie"/"liveness"/"face_match" are
  /// present. Every step is independently optional server-side — a flow can
  /// ask for "face_match" without "nfc_read" (in which case [referencePhoto]
  /// carries the comparison image instead of DG2) — but vcmrtd can't act on
  /// "document_capture"/"nfc_read" being absent yet: skipping the NFC read
  /// still needs a routing path from the MRZ scan straight to face
  /// verification, which hasn't been built (needs explicit sign-off - see
  /// [referencePhoto]'s doc comment for why it's parsed but unused so far).
  final List<String>? steps;

  /// The comparison photo the relying party supplied at session creation for
  /// face_match, present when the resolved flow's steps ask for "face_match"
  /// without "nfc_read" (mirrors api.appSessionView.referencePhoto — required
  /// server-side in exactly that case, since there's no DG2 to fall back to).
  /// Null whenever "nfc_read" is present or in flow-less sessions, where DG2
  /// remains the comparison source as before.
  ///
  /// Parsed but not consumed by any screen yet: using it means running face
  /// verification straight after the MRZ/document scan, bypassing NFC
  /// reading entirely - the same not-yet-approved routing change
  /// [steps] documents above. Nothing reads this field until that lands.
  final ProofingPhotoInfo? referencePhoto;

  /// Which client performs the selfie/liveness/face_match cluster: "browser"
  /// (the default — identity-proofing-service's own browser hosted flow does
  /// it, not this app) or "native" (vcmrtd does it on-device, as it always
  /// has). Mirrors api.appSessionView.SelfieLocation on the server, which is
  /// always resolved (never null/empty) — "browser" even for a session with
  /// no flow at all, though it's meaningless there since [steps] being null
  /// already means vcmrtd's unconditional default sequence applies regardless
  /// of this field.
  final String selfieLocation;

  /// The session's server-side status (api.appSessionView.status) — see
  /// [proofingSessionFinished]. A flow session stays "in_progress" after its
  /// last step; it only gets its outcome once submitted
  /// ([ProofingSessionClient.submitSession]).
  final String status;

  /// How many times the relying party has reset this session
  /// (`POST /api/v1/sessions/{id}/reset`). An increase means the server has
  /// dropped every step collected so far and the user has to start over —
  /// see ProofingSessionWatcher.
  final int resetCount;

  /// Opaque value to pass back as `?since=` to
  /// [ProofingSessionClient.waitForChange]. Null from a server that predates
  /// session reset, in which case there is nothing to watch for.
  final String? changeKey;

  /// The server's own view of where the session stands: ACTIVE, COMPLETE
  /// (submitted - it has its outcome), EXPIRED or CANCELLED. Null from a
  /// server that predates device handover.
  final String? lifecycle;

  /// Every step of the flow has a result and the session is waiting to be
  /// submitted ([ProofingSessionClient.submitSession]) - by this device or
  /// the other one holding a slot.
  final bool readyToSubmit;

  /// The step the server expects next ("" once every step is done), and the
  /// steps it already holds a result for. The server decides these - the app
  /// never derives them from its own local progress.
  final String? currentStep;
  final List<String> completedSteps;

  /// This device's access to the session; null before claiming, or from a
  /// server that predates device handover.
  final ProofingDeviceAccess? device;

  /// The chip access key the MRZ step stored, present only while
  /// [currentStep] is nfc_read - so a device that took the session over
  /// reads the chip without rescanning the MRZ.
  final ProofingChipAccess? chipAccess;

  /// The photo the face step compares against (the chip's DG2, or the
  /// relying party's referencePhoto), present only while the face step is
  /// current and runs in this app - so a device that took over can run it
  /// without reading the chip itself.
  final ProofingPhotoInfo? faceReference;

  ProofingSessionInfo({
    required this.id,
    required this.relyingParty,
    required this.requestedAttributes,
    required this.expiresAt,
    this.aaChallenge,
    this.steps,
    this.referencePhoto,
    this.selfieLocation = 'browser',
    this.status = 'opened',
    this.resetCount = 0,
    this.changeKey,
    this.lifecycle,
    this.readyToSubmit = false,
    this.currentStep,
    this.completedSteps = const [],
    this.device,
    this.chipAccess,
    this.faceReference,
  });

  /// Why this device can no longer act on the session, judging by the view
  /// alone, or null while it still may. An error response (see
  /// [ProofingSessionAccessException]) is the other way the server says so.
  ProofingAccessDenial? get accessLost {
    if (device != null && !device!.authorized) return ProofingAccessDenial.handedOver;
    if (lifecycle == proofingLifecycleExpired || status == 'expired') return ProofingAccessDenial.expired;
    if (lifecycle == proofingLifecycleCancelled || status == 'cancelled') return ProofingAccessDenial.cancelled;
    // Deliberately not compared against [expiresAt] on this device's clock:
    // the server decides expiry, and a skewed phone clock mustn't end a
    // session that's still valid.
    return null;
  }

  factory ProofingSessionInfo.fromJson(Map<String, dynamic> json) => ProofingSessionInfo(
    id: json['id'] as String,
    relyingParty: json['relyingParty'] as String,
    requestedAttributes: (json['requestedAttributes'] as List<dynamic>? ?? const []).cast<String>(),
    expiresAt: DateTime.parse(json['expiresAt'] as String),
    aaChallenge: json['aaChallenge'] as String?,
    steps: (json['steps'] as List<dynamic>?)?.cast<String>(),
    referencePhoto: json['referencePhoto'] != null
        ? ProofingPhotoInfo.fromJson(json['referencePhoto'] as Map<String, dynamic>)
        : null,
    selfieLocation: json['selfieLocation'] as String? ?? 'browser',
    status: json['status'] as String? ?? 'opened',
    resetCount: json['resetCount'] as int? ?? 0,
    changeKey: json['changeKey'] as String?,
    lifecycle: json['lifecycle'] as String?,
    readyToSubmit: json['readyToSubmit'] as bool? ?? false,
    currentStep: json['currentStep'] as String?,
    completedSteps: (json['completedSteps'] as List<dynamic>? ?? const []).cast<String>(),
    device: json['device'] is Map<String, dynamic>
        ? ProofingDeviceAccess.fromJson(json['device'] as Map<String, dynamic>)
        : null,
    chipAccess: json['chipAccess'] is Map<String, dynamic>
        ? ProofingChipAccess.fromJson(json['chipAccess'] as Map<String, dynamic>)
        : null,
    faceReference: json['faceReference'] is Map<String, dynamic>
        ? ProofingPhotoInfo.fromJson(json['faceReference'] as Map<String, dynamic>)
        : null,
  );
}

/// What opens the chip (BAC/PACE, or BAP for a driving licence), derived
/// from the MRZ. Sent with the document_capture step and handed back by the
/// server while nfc_read is the current step (api.appSessionView.chipAccess),
/// so another device can resume straight at the chip read.
class ProofingChipAccess {
  final DocumentType documentType;
  final String documentNumber;
  final String countryCode;
  final DateTime? dateOfBirth;
  final DateTime? dateOfExpiry;
  final String? version;
  final String? randomData;
  final String? configuration;

  const ProofingChipAccess({
    required this.documentType,
    required this.documentNumber,
    this.countryCode = '',
    this.dateOfBirth,
    this.dateOfExpiry,
    this.version,
    this.randomData,
    this.configuration,
  });

  factory ProofingChipAccess.fromScannedMrz(ScannedMRZ mrz, DocumentType documentType) => switch (mrz) {
    ScannedPassportMRZ() => ProofingChipAccess(
      documentType: documentType,
      documentNumber: mrz.documentNumber,
      countryCode: mrz.countryCode,
      dateOfBirth: mrz.dateOfBirth,
      dateOfExpiry: mrz.dateOfExpiry,
    ),
    ScannedDriverLicenseMRZ() => ProofingChipAccess(
      documentType: documentType,
      documentNumber: mrz.documentNumber,
      countryCode: mrz.countryCode,
      version: mrz.version,
      randomData: mrz.randomData,
      configuration: mrz.configuration,
    ),
  };

  /// Null when the stored key is incomplete (e.g. from another client).
  static ProofingChipAccess? fromJson(Map<String, dynamic> json) {
    final type = switch (json['documentType']) {
      'passport' => DocumentType.passport,
      'identity_card' => DocumentType.identityCard,
      'drivers_license' => DocumentType.drivingLicence,
      _ => null,
    };
    final number = json['documentNumber'] as String?;
    if (type == null || number == null || number.isEmpty) return null;
    return ProofingChipAccess(
      documentType: type,
      documentNumber: number,
      countryCode: json['countryCode'] as String? ?? '',
      dateOfBirth: DateTime.tryParse(json['dateOfBirth'] as String? ?? ''),
      dateOfExpiry: DateTime.tryParse(json['dateOfExpiry'] as String? ?? ''),
      version: json['version'] as String?,
      randomData: json['randomData'] as String?,
      configuration: json['configuration'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'documentType': switch (documentType) {
      DocumentType.passport => 'passport',
      DocumentType.identityCard => 'identity_card',
      DocumentType.drivingLicence => 'drivers_license',
    },
    'documentNumber': documentNumber,
    if (countryCode.isNotEmpty) 'countryCode': countryCode,
    if (dateOfBirth != null) 'dateOfBirth': ProofingDocumentInfo._dateOnly(dateOfBirth!),
    if (dateOfExpiry != null) 'dateOfExpiry': ProofingDocumentInfo._dateOnly(dateOfExpiry!),
    if (version != null) 'version': version,
    if (randomData != null) 'randomData': randomData,
    if (configuration != null) 'configuration': configuration,
  };

  /// The MRZ the NFC reading screen needs, or null when this key can't open
  /// the chip (a passport key without its dates, a licence key without its
  /// MRZ fields).
  ScannedMRZ? toScannedMrz() {
    if (documentType == DocumentType.drivingLicence) {
      if (version == null || randomData == null || configuration == null) return null;
      return ScannedDriverLicenseMRZ(
        documentNumber: documentNumber,
        countryCode: countryCode,
        version: version!,
        randomData: randomData!,
        configuration: configuration!,
      );
    }
    if (dateOfBirth == null || dateOfExpiry == null) return null;
    return ScannedPassportMRZ(
      documentNumber: documentNumber,
      countryCode: countryCode,
      dateOfBirth: dateOfBirth!,
      dateOfExpiry: dateOfExpiry!,
      documentType: documentType,
    );
  }
}

/// What a claim returns: this device's credential (folded into [ref]) and
/// the session's current state.
class ProofingSessionClaim {
  final ProofingSessionRef ref;
  final ProofingSessionInfo info;
  const ProofingSessionClaim({required this.ref, required this.info});
}

/// What a step endpoint (or `POST .../submit`) returns once the server
/// stored that step's result (api.stepResponse): the server, not the app,
/// decides what comes next.
class ProofingStepResponse {
  final String status;
  final List<String> completedSteps;
  final String? currentStep;
  final String? lifecycle;
  final String? errorCode;

  /// Every step has a result: the session waits for a submit - see
  /// [ProofingSessionInfo.readyToSubmit].
  final bool readyToSubmit;

  /// The server already had this step: nothing was stored, this is just
  /// the current state (a retry, or the other device got there first).
  final bool alreadyRecorded;

  const ProofingStepResponse({
    required this.status,
    this.completedSteps = const [],
    this.currentStep,
    this.lifecycle,
    this.errorCode,
    this.readyToSubmit = false,
    this.alreadyRecorded = false,
  });

  factory ProofingStepResponse.fromJson(Map<String, dynamic> json) => ProofingStepResponse(
    status: json['status'] as String? ?? '',
    completedSteps: (json['completedSteps'] as List<dynamic>? ?? const []).cast<String>(),
    currentStep: json['currentStep'] as String?,
    lifecycle: json['lifecycle'] as String?,
    errorCode: json['errorCode'] as String?,
    readyToSubmit: json['readyToSubmit'] as bool? ?? false,
    alreadyRecorded: json['alreadyRecorded'] as bool? ?? false,
  );

  /// The same shape from a session view, for a caller that had to fetch the
  /// session instead (see [ProofingStepsIncompleteException]).
  factory ProofingStepResponse.fromSessionInfo(ProofingSessionInfo info) => ProofingStepResponse(
    status: info.status,
    completedSteps: info.completedSteps,
    currentStep: info.currentStep,
    lifecycle: info.lifecycle,
    readyToSubmit: info.readyToSubmit,
  );

  /// Whether the session was submitted and has its outcome. Keyed on
  /// lifecycle alone: an empty or missing currentStep doesn't mean complete
  /// (after the last step the session waits for [readyToSubmit]'s submit,
  /// and the server omits currentStep for a session without a flow).
  bool get complete => lifecycle == proofingLifecycleComplete;
}

/// `POST .../submit` refused because not every step has a result yet (409
/// steps_incomplete) - e.g. a reset landed in between. Not an access
/// refusal: the app continues at the server's current step.
class ProofingStepsIncompleteException implements Exception {
  const ProofingStepsIncompleteException();

  @override
  String toString() => 'ProofingStepsIncompleteException';
}

/// Whether [status] means the session has an outcome and can no longer
/// change (or be reset): needs_review plus every terminal status.
bool proofingSessionFinished(String status) =>
    const ['needs_review', 'approved', 'rejected', 'expired', 'cancelled'].contains(status);

/// Why the server refused this device access to a session.
enum ProofingAccessDenial {
  /// Another device took the session over (403 device_handed_over).
  handedOver,

  /// The session expired (410 session_expired).
  expired,

  /// The session was cancelled.
  cancelled,

  /// No valid device credential for a session that is bound to a device
  /// (401 device_unauthorized).
  unauthorized,

  /// The session is already finished, so nothing can be submitted anymore
  /// (409 session_complete).
  complete,

  /// The session doesn't exist (anymore) - a plain 404/410 without a code.
  gone,

  /// A plain session QR scanned after another device already claimed it
  /// (409 device_already_claimed): the user needs the handover QR instead.
  alreadyClaimed,

  /// Handover token unknown (404 handover_invalid), expired (410
  /// handover_expired) or already claimed (409 handover_used).
  handoverInvalid,
  handoverExpired,
  handoverUsed,

  /// A link carrying the session token itself (410 claim_token_required, or
  /// recognised locally): it can't claim anything any more.
  claimTokenRequired,

  /// The browser's own handover QR, scanned in this app.
  browserHandover;

  /// Whether this ends the local verification for good: the app must drop
  /// the session, not retry. The rest only refuse one claim attempt.
  bool get endsSession => switch (this) {
    handedOver || expired || cancelled || unauthorized || complete || gone => true,
    alreadyClaimed ||
    handoverInvalid ||
    handoverExpired ||
    handoverUsed ||
    claimTokenRequired ||
    browserHandover => false,
  };

  /// What to tell the user.
  String get message => switch (this) {
    handedOver => 'This verification session has been handed over to another device.',
    expired => 'This verification session has expired. Please start a new verification.',
    cancelled => 'This verification session was cancelled. Please start a new verification.',
    unauthorized => 'This device is no longer allowed to continue this verification session.',
    complete => 'This verification session is already complete.',
    gone => 'This verification session no longer exists. Please start a new verification.',
    alreadyClaimed =>
      'This verification session is already open on another device. To continue here, scan the handover QR code '
          'shown in the browser.',
    handoverInvalid => 'This handover QR code is not valid. Ask for a new one in the browser.',
    handoverExpired => 'This handover QR code has expired. Ask for a new one in the browser.',
    handoverUsed => 'This handover QR code was already used. Ask for a new one in the browser.',
    claimTokenRequired =>
      'This QR code is from an older version of the verification service and can no longer be used. '
          'Ask for a new one in the browser.',
    browserHandover =>
      'This QR code moves the browser part of the verification to another browser. Open it with your '
          "phone's camera instead, or scan the QR code the browser shows for the IDEM app.",
  };
}

/// Thrown by every [ProofingSessionClient] call when the server refuses this
/// device access to the session - see [ProofingAccessDenial].
class ProofingSessionAccessException implements Exception {
  final ProofingAccessDenial reason;
  final int statusCode;
  const ProofingSessionAccessException(this.reason, this.statusCode);

  @override
  String toString() => 'ProofingSessionAccessException(${reason.name}, $statusCode)';
}

/// Maps a refused response to a [ProofingSessionAccessException], or null if
/// [response] isn't an access refusal (success, or an ordinary failure such
/// as a 400 for a malformed body). The server's `code` decides; the status
/// code alone only for the unambiguous cases, since 409 also means e.g.
/// "the face_match reference isn't there yet".
ProofingSessionAccessException? proofingAccessDenialFor(http.Response response) {
  final reason = switch (_errorCodeOf(response)) {
    'device_handed_over' => ProofingAccessDenial.handedOver,
    'session_expired' => ProofingAccessDenial.expired,
    'device_unauthorized' => ProofingAccessDenial.unauthorized,
    'session_complete' => ProofingAccessDenial.complete,
    'device_already_claimed' => ProofingAccessDenial.alreadyClaimed,
    'handover_invalid' => ProofingAccessDenial.handoverInvalid,
    'handover_expired' => ProofingAccessDenial.handoverExpired,
    'handover_used' => ProofingAccessDenial.handoverUsed,
    'claim_token_required' => ProofingAccessDenial.claimTokenRequired,
    _ => switch (response.statusCode) {
      401 || 403 => ProofingAccessDenial.unauthorized,
      404 || 410 => ProofingAccessDenial.gone,
      _ => null,
    },
  };
  return reason == null ? null : ProofingSessionAccessException(reason, response.statusCode);
}

/// The `code` of an error response, or null when it has none (or isn't JSON).
String? _errorCodeOf(http.Response response) {
  try {
    final body = json.decode(response.body);
    if (body is Map<String, dynamic>) return body['code'] as String?;
  } catch (_) {
    // not JSON
  }
  return null;
}

/// Whether [steps] asks for a face-verification stage that THIS APP should
/// perform itself: it must actually request one (see [stepsRequestAny]) AND
/// [selfieLocation] must not be exactly "browser" — any other value
/// (today only "native", but also an unrecognised future one) means vcmrtd
/// stays the performer, so a client this old never silently drops a face
/// check the session actually needs just because it doesn't recognise a new
/// location value. A null [steps] (no flow at all) always means vcmrtd's own
/// unconditional face step, regardless of [selfieLocation] — see
/// [ProofingSessionInfo.selfieLocation]'s doc comment.
bool nativeFaceVerificationRequested(List<String>? steps, String selfieLocation) {
  if (steps == null) return true;
  if (!stepsRequestAny(steps, [stepFaceVerification, stepSelfie, stepLiveness, stepFaceMatch])) return false;
  return selfieLocation != 'browser';
}

/// [ProofingSessionInfo.steps] values. Mirrors flow.Step in
/// identity-proofing-service's backend/internal/flow/flow.go — keep in sync
/// with that list.
const stepDocumentCapture = 'document_capture';
const stepNfcRead = 'nfc_read';
// stepFaceVerification is the aggregate "the complete live face-verification
// stage" step (flow.StepFaceVerification server-side) — distinct from the
// three granular sub-steps below, which a flow can also list individually.
// Every stepsRequestAny([stepSelfie, stepLiveness, stepFaceMatch]) call site
// must also include this one, or a flow that lists "face_verification"
// (rather than spelling out selfie/liveness/face_match) is silently treated
// as not needing any face step at all: vcmrtd skips its own
// face-verification screen and submits the result straight after NFC,
// before the browser hosted flow ever gets a chance to run it either.
const stepFaceVerification = 'face_verification';
const stepSelfie = 'selfie';
const stepLiveness = 'liveness';
const stepFaceMatch = 'face_match';

/// Whether [steps] calls for any of [anyOf]. A null [steps] means the
/// session wasn't created against a flow definition, so every step is
/// implicitly wanted — same "unrestricted" rule [_attrRequested] applies to
/// requestedAttributes, applied here to steps instead.
bool stepsRequestAny(List<String>? steps, List<String> anyOf) {
  if (steps == null) return true;
  return anyOf.any(steps.contains);
}

/// The identity read off the document's DG1/MRZ, plus DG11 extras when the
/// document carries them. Mirrors api.documentInfo on the server —
/// provisional field shape, not an ICAO/ISO standard encoding, until the
/// shared result schema (identity-proofing-service issue #5) settles it.
/// [toJson]'s `includeDG11Extras` lets [buildProofingResultBody] drop
/// personalNumber/placeOfBirth before this ever reaches [toJson] with the
/// full object still intact — see that function for why.
class ProofingDocumentInfo {
  final String? type;
  final String? number;
  final String? issuingState;
  final String? nationality;
  final String? firstName;
  final String? lastName;
  final String? displayName;
  final String? sex;
  final DateTime? dateOfBirth;
  final DateTime? dateOfExpiry;
  final String? personalNumber;
  final String? placeOfBirth;
  final ProofingDocumentValidityInfo? validity;

  const ProofingDocumentInfo({
    this.type,
    this.number,
    this.issuingState,
    this.nationality,
    this.firstName,
    this.lastName,
    this.displayName,
    this.sex,
    this.dateOfBirth,
    this.dateOfExpiry,
    this.personalNumber,
    this.placeOfBirth,
    this.validity,
  });

  /// Builds from the full parsed document, not just its MRZ, so DG11 extras
  /// (personalNumber, placeOfBirth) and the DG11-preferring displayName are
  /// included when the document carries them.
  factory ProofingDocumentInfo.fromPassportData(PassportData data) => ProofingDocumentInfo(
    type: data.mrz.documentCode,
    number: data.mrz.documentNumber,
    issuingState: data.mrz.country,
    nationality: data.mrz.nationality,
    firstName: data.mrz.firstName,
    lastName: data.mrz.lastName,
    displayName: data.displayName,
    sex: data.mrz.gender,
    dateOfBirth: data.mrz.dateOfBirth,
    dateOfExpiry: data.mrz.dateOfExpiry,
    personalNumber: data.personalNumber,
    placeOfBirth: data.placeOfBirth?.join(', '),
    // PassportMRZ asserts every ICAO 9303 check digit (document number, date
    // of birth, date of expiry, composite) while parsing and throws on a
    // mismatch, so a PassportMRZ that exists here already passed all four —
    // there's nothing left to verify beyond expiry, which parsing doesn't
    // check.
    validity: ProofingDocumentValidityInfo(
      documentNumberCheckDigitValid: true,
      dateOfBirthCheckDigitValid: true,
      dateOfExpiryCheckDigitValid: true,
      compositeCheckDigitValid: true,
      notExpired: data.mrz.dateOfExpiry.isAfter(DateTime.now()),
    ),
  );

  /// Builds from a driving licence's DG1. Unlike the passport MRZ, DG1 here
  /// carries no nationality or sex, so those are left unset; [type] is the
  /// wire-format document type rather than an MRZ document code, since
  /// driving licences have no MRZ to read one from.
  factory ProofingDocumentInfo.fromDrivingLicenceData(DrivingLicenceData data) => ProofingDocumentInfo(
    type: documentTypeToString(DocumentType.drivingLicence),
    number: data.documentNumber,
    issuingState: data.issuingMemberState,
    firstName: data.holderOtherName,
    lastName: data.holderSurname,
    displayName: '${data.holderOtherName} ${data.holderSurname}'.trim(),
    dateOfBirth: parseDrivingLicenceDate(data.dateOfBirth),
    dateOfExpiry: parseDrivingLicenceDate(data.dateOfExpiry),
    placeOfBirth: data.placeOfBirth.isNotEmpty ? data.placeOfBirth : null,
  );

  /// Builds from a "document_capture"-only scan (no "nfc_read" - see
  /// routing.dart's _afterDocumentCaptured) — the OCR/VIZ read or manual
  /// entry that derives the BAC/PACE key, not a chip read. Only the handful
  /// of fields that capture actually produces are set: no name, no sex, no
  /// nationality, no personalNumber/placeOfBirth (DG11-only), no
  /// [validity] (nothing here has had its check digits verified the way a
  /// chip-read [PassportMRZ] has). This is deliberately a partial result,
  /// not a stand-in for a full one.
  factory ProofingDocumentInfo.fromScannedMrz(ScannedMRZ mrz) => switch (mrz) {
    ScannedPassportMRZ() => ProofingDocumentInfo(
      type: documentTypeToString(mrz.documentType),
      number: mrz.documentNumber,
      issuingState: mrz.countryCode,
      dateOfBirth: mrz.dateOfBirth,
      dateOfExpiry: mrz.dateOfExpiry,
    ),
    ScannedDriverLicenseMRZ() => ProofingDocumentInfo(
      type: documentTypeToString(mrz.documentType),
      number: mrz.documentNumber,
      issuingState: mrz.countryCode,
    ),
  };

  /// [includeDG11Extras] false omits personalNumber/placeOfBirth — used when
  /// the session's requestedAttributes asked for "dg1" but not "dg11", the
  /// same split the server's buildResult applies to documentInfo.
  Map<String, dynamic> toJson({bool includeDG11Extras = true}) => {
    if (type != null) 'type': type,
    if (number != null) 'number': number,
    if (issuingState != null) 'issuingState': issuingState,
    if (nationality != null) 'nationality': nationality,
    if (firstName != null) 'firstName': firstName,
    if (lastName != null) 'lastName': lastName,
    if (displayName != null) 'displayName': displayName,
    if (sex != null) 'sex': sex,
    if (dateOfBirth != null) 'dateOfBirth': _dateOnly(dateOfBirth!),
    if (dateOfExpiry != null) 'dateOfExpiry': _dateOnly(dateOfExpiry!),
    if (includeDG11Extras && personalNumber != null && personalNumber!.isNotEmpty) 'personalNumber': personalNumber,
    if (includeDG11Extras && placeOfBirth != null && placeOfBirth!.isNotEmpty) 'placeOfBirth': placeOfBirth,
    if (validity != null) 'validity': validity!.toJson(),
  };

  static String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// ICAO 9303 MRZ check-digit results plus a plain expiry check. Mirrors
/// api.documentValidityInfo on the server. Passport-only — driving licences
/// have no MRZ to compute these from.
class ProofingDocumentValidityInfo {
  final bool? documentNumberCheckDigitValid;
  final bool? dateOfBirthCheckDigitValid;
  final bool? dateOfExpiryCheckDigitValid;
  final bool? compositeCheckDigitValid;
  final bool? notExpired;

  const ProofingDocumentValidityInfo({
    this.documentNumberCheckDigitValid,
    this.dateOfBirthCheckDigitValid,
    this.dateOfExpiryCheckDigitValid,
    this.compositeCheckDigitValid,
    this.notExpired,
  });

  Map<String, dynamic> toJson() => {
    if (documentNumberCheckDigitValid != null) 'documentNumberCheckDigitValid': documentNumberCheckDigitValid,
    if (dateOfBirthCheckDigitValid != null) 'dateOfBirthCheckDigitValid': dateOfBirthCheckDigitValid,
    if (dateOfExpiryCheckDigitValid != null) 'dateOfExpiryCheckDigitValid': dateOfExpiryCheckDigitValid,
    if (compositeCheckDigitValid != null) 'compositeCheckDigitValid': compositeCheckDigitValid,
    if (notExpired != null) 'notExpired': notExpired,
  };
}

/// The raw face image off the chip's DG2 data group, or the live selfie
/// captured during face verification. Mirrors api.photoInfo on the server.
class ProofingPhotoInfo {
  final String imageBase64;
  final String mimeType;

  const ProofingPhotoInfo({required this.imageBase64, required this.mimeType});

  factory ProofingPhotoInfo.fromJson(Map<String, dynamic> json) =>
      ProofingPhotoInfo(imageBase64: json['imageBase64'] as String, mimeType: json['mimeType'] as String);

  factory ProofingPhotoInfo.fromImage(Uint8List bytes, ImageType? type) => ProofingPhotoInfo(
    imageBase64: base64Encode(bytes),
    mimeType: switch (type) {
      ImageType.jpeg => 'image/jpeg',
      ImageType.jpeg2000 => 'image/jp2',
      null => 'image/jpeg',
    },
  );

  factory ProofingPhotoInfo.fromSelfie(Uint8List bytes) =>
      ProofingPhotoInfo(imageBase64: base64Encode(bytes), mimeType: _sniffImageMimeType(bytes));

  static const _pngSignature = [0x89, 0x50, 0x4E, 0x47];

  static bool _isPng(Uint8List bytes) {
    if (bytes.length < _pngSignature.length) return false;
    for (var i = 0; i < _pngSignature.length; i++) {
      if (bytes[i] != _pngSignature[i]) return false;
    }
    return true;
  }

  static String _sniffImageMimeType(Uint8List bytes) => _isPng(bytes) ? 'image/png' : 'image/jpeg';

  Map<String, dynamic> toJson() => {'imageBase64': imageBase64, 'mimeType': mimeType};
}

/// The raw chip evidence identity-proofing-service needs to independently
/// run Passive Authentication (EF.SOD signature against a CSCA trust anchor,
/// plus per-data-group hash verification) and Active/Chip Authentication
/// (challenge-response signature against the chip's public key) — see that
/// service's internal/mrtdverify package. Mirrors api.mrtdEvidenceRequest.
///
/// The server computes and stores its own chipChecks verdict from this
/// evidence; it never trusts a chipChecks claim the app might send instead
/// (there is no such field any more on this client — see
/// [buildProofingResultBody]).
class ProofingMrtdEvidence {
  /// The raw EF.SOD (Security Object Document) exactly as read off the
  /// chip, hex-encoded.
  final String efSod;

  /// Every data group actually read off the chip, keyed "DG1".."DG16", each
  /// value hex-encoded exactly as read — not re-derived from parsed fields,
  /// since Passive Authentication hashes these bytes and compares against
  /// the signed hash list in [efSod].
  final Map<String, String> dataGroups;

  /// Which entry in [dataGroups] carries the Active Authentication public
  /// key (tag 0x6F wrapping a SubjectPublicKeyInfo): "DG15" for
  /// passports/ID cards, "DG13" for EU driving licences. Null when the chip
  /// doesn't support Active Authentication.
  final String? aaKeyDataGroup;

  /// The Active Authentication challenge sent to the chip and its signed
  /// response, both hex-encoded. Set together with [aaKeyDataGroup], never
  /// alone.
  final String? nonce;
  final String? aaSignature;

  /// Selects which Passive Authentication path identity-proofing-service
  /// runs — "icao" (passports/ID cards, requires DG1+DG2) or
  /// "eu_driving_licence" (generic hash/signature check against whatever
  /// data groups were submitted, no DG2 requirement). Mirrors
  /// api.mrtdEvidenceRequest.DocumentType/documentTypeICAO/
  /// documentTypeEUDrivingLicence on the server; must match [aaKeyDataGroup]
  /// ("DG15"->"icao", "DG13"->"eu_driving_licence") or the server will
  /// route to the wrong verification path.
  final String documentType;

  const ProofingMrtdEvidence({
    required this.efSod,
    required this.dataGroups,
    required this.documentType,
    this.aaKeyDataGroup,
    this.nonce,
    this.aaSignature,
  });

  /// Builds from what vcmrtd already captured while reading the chip —
  /// [result]'s `dataGroups`/`efSod`/`nonce`/`aaSignature` are exactly the
  /// raw bytes this needs, no separate raw-evidence capture required.
  /// [aaKeyDataGroup] is "DG15" for passports/ID cards, "DG13" for EU
  /// driving licences (the caller knows which, from the document type it's
  /// already handling) — Active Authentication is only reported as
  /// attempted when that data group was actually read AND a nonce/signature
  /// pair was actually captured; a chip that doesn't support AA (no such
  /// data group) or where AA wasn't attempted reports neither. [documentType]
  /// must be the matching "icao"/"eu_driving_licence" value — see the field
  /// doc comment.
  factory ProofingMrtdEvidence.fromRawDocumentData(
    RawDocumentData result, {
    required String aaKeyDataGroup,
    required String documentType,
  }) {
    final nonce = result.nonce;
    final signature = result.aaSignature;
    final aaAttempted = result.dataGroups.containsKey(aaKeyDataGroup) && nonce != null && signature != null;
    return ProofingMrtdEvidence(
      efSod: result.efSod,
      dataGroups: result.dataGroups,
      documentType: documentType,
      aaKeyDataGroup: aaAttempted ? aaKeyDataGroup : null,
      nonce: aaAttempted ? nonce.hex() : null,
      aaSignature: aaAttempted ? signature.hex() : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'efSod': efSod,
    'dataGroups': dataGroups,
    'documentType': documentType,
    if (aaKeyDataGroup != null) 'aaKeyDataGroup': aaKeyDataGroup,
    if (nonce != null) 'nonce': nonce,
    if (aaSignature != null) 'aaSignature': aaSignature,
  };
}

/// Face-verification outcome, mirroring [FaceVerificationOutcome].
/// [faceMatchScore] is null for the Iris SDK, which doesn't expose one.
class ProofingBiometricsInfo {
  final double? faceMatchScore; // DG2 vs. live face, 0..1
  final bool? faceVerified;
  final String? livenessResult; // "passed" | "failed" | "not_performed"
  final String? engine; // "on_device" | "iris"

  const ProofingBiometricsInfo({this.faceMatchScore, this.faceVerified, this.livenessResult, this.engine});

  Map<String, dynamic> toJson() => {
    if (faceMatchScore != null) 'faceMatchScore': faceMatchScore,
    if (faceVerified != null) 'faceVerified': faceVerified,
    if (livenessResult != null) 'livenessResult': livenessResult,
    if (engine != null) 'engine': engine,
  };
}

/// App build and device platform. Not gated by the session's
/// requestedAttributes server-side — it's operational metadata, not part of
/// the identity result.
class ProofingDeviceInfo {
  final String? appVersion;
  final String? devicePlatform;

  const ProofingDeviceInfo({this.appVersion, this.devicePlatform});

  Map<String, dynamic> toJson() => {
    if (appVersion != null) 'appVersion': appVersion,
    if (devicePlatform != null) 'devicePlatform': devicePlatform,
  };
}

/// Attribute keys a relying party can list in a session's
/// requestedAttributes to opt into part of the result. Mirrors
/// attrDocument/attrDG11/attrDG2/attrFaceImage/attrChipChecks/attrBiometrics
/// in identity-proofing-service's backend/internal/api/sessions.go — keep in
/// sync with that list.
const _attrDocument = 'dg1';
const _attrDG11 = 'dg11';
const _attrDG2 = 'dg2';
const _attrFaceImage = 'face_image';
const _attrChipChecks = 'chip_checks';
const _attrBiometrics = 'biometrics';
const _attrSelfie = 'selfie';

/// Whether any of [keys] was requested. Mirrors the server's attrRequested:
/// an empty [requestedAttributes] list is unrestricted (matches everything)
/// — today's default, and every session created before a relying party
/// opted into filtering — so only a relying party that actually lists
/// attributes narrows the result down to just those.
bool _attrRequested(List<String> requestedAttributes, List<String> keys) {
  if (requestedAttributes.isEmpty) return true;
  return keys.any(requestedAttributes.contains);
}

/// Builds the JSON body for `POST .../result`, keeping only the parts
/// [requestedAttributes] asked for — the same data-minimisation boundary
/// identity-proofing-service's buildResult applies server-side (see that
/// package's docs/session-model.md, "Result shape and attribute
/// filtering"). [requestedAttributes] must come from the fetched
/// [ProofingSessionInfo] (i.e. from the token the QR/deep link carried, not
/// from the QR payload itself — the QR only encodes apiBase/token; the
/// session's requestedAttributes is what the app-facing GET returns for
/// that token), so a party can't get more collected than what its own
/// session actually requested.
///
/// This exists so the data never leaves the device in the first place for
/// anything the relying party didn't ask for, rather than relying solely on
/// the server dropping it after receiving it. [device] is never gated, same
/// as server-side — it's operational metadata, not part of the identity
/// result.
Map<String, dynamic> buildProofingResultBody({
  required String status,
  String? errorCode,
  required List<String> requestedAttributes,
  ProofingDocumentInfo? document,
  ProofingPhotoInfo? photo,
  ProofingPhotoInfo? selfie,
  ProofingMrtdEvidence? mrtdEvidence,
  ProofingBiometricsInfo? biometrics,
  ProofingDeviceInfo? device,
}) {
  final includeDocument = document != null && _attrRequested(requestedAttributes, [_attrDocument]);
  final includeDG11 = _attrRequested(requestedAttributes, [_attrDG11]);
  final includePhoto = photo != null && _attrRequested(requestedAttributes, [_attrDG2, _attrFaceImage]);
  final includeSelfie = selfie != null && _attrRequested(requestedAttributes, [_attrSelfie]);
  final includeMrtdEvidence = mrtdEvidence != null && _attrRequested(requestedAttributes, [_attrChipChecks]);
  final includeBiometrics = biometrics != null && _attrRequested(requestedAttributes, [_attrBiometrics]);

  return {
    'status': status,
    if (errorCode != null) 'errorCode': errorCode,
    if (includeDocument) 'document': document.toJson(includeDG11Extras: includeDG11),
    if (includePhoto) 'photo': photo.toJson(),
    if (includeSelfie) 'selfie': selfie.toJson(),
    if (includeMrtdEvidence) 'mrtdEvidence': mrtdEvidence.toJson(),
    if (includeBiometrics) 'biometrics': biometrics.toJson(),
    if (device != null) 'device': device.toJson(),
  };
}

/// Builds the JSON body for `POST .../steps/nfc` — the nfc_read step, used
/// instead of [buildProofingResultBody]/`POST .../result` whenever the
/// session's face-verification stage is deferred to the browser hosted flow
/// (see [nativeFaceVerificationRequested]). Only document/photo/device are
/// gated by [requestedAttributes], the same as the single-shot body;
/// [mrtdEvidence] is always included, unconditionally — unlike the result
/// body's `chip_checks`-gated inclusion, this is the raw evidence the step
/// endpoint needs to run Passive/Active Authentication itself, not part of
/// what the relying party asked to receive back, and the endpoint rejects a
/// submission without it (`mrtdEvidence is required`). There is no
/// status/errorCode/selfie/biometrics here — the server decides the session's
/// status once every step (including the browser's own selfie submission)
/// has landed and the session is submitted (see
/// [ProofingSessionClient.submitSession]).
///
/// [faceStepFollows]: the flow has a face step, so the photo is sent
/// whatever requestedAttributes says - it's what that step compares against
/// (server-side, or on a device that takes the session over), and the same
/// DG2 is in [mrtdEvidence] anyway.
Map<String, dynamic> buildProofingNfcStepBody({
  required List<String> requestedAttributes,
  ProofingDocumentInfo? document,
  ProofingPhotoInfo? photo,
  required ProofingMrtdEvidence mrtdEvidence,
  ProofingDeviceInfo? device,
  bool faceStepFollows = false,
}) {
  final includeDocument = document != null && _attrRequested(requestedAttributes, [_attrDocument]);
  final includeDG11 = _attrRequested(requestedAttributes, [_attrDG11]);
  final includePhoto =
      photo != null && (faceStepFollows || _attrRequested(requestedAttributes, [_attrDG2, _attrFaceImage]));

  return {
    if (includeDocument) 'document': document.toJson(includeDG11Extras: includeDG11),
    if (includePhoto) 'photo': photo.toJson(),
    'mrtdEvidence': mrtdEvidence.toJson(),
    if (device != null) 'device': device.toJson(),
  };
}

/// Talks to identity-proofing-service's app-facing session API
/// (`/api/v1/app/{token}`) — the vcmrtd-side counterpart of the
/// relying party's `/api/v1/sessions` API. Separate from
/// [PassportIssuer]/[DefaultPassportIssuer]: that talks to go-passport-issuer
/// for a different purpose (nonce-based active authentication, server-side
/// verification, IRMA issuance) and this doesn't touch that contract.
///
/// Every call after claiming carries the device credential
/// ([ProofingSessionRef.deviceToken]) and throws
/// [ProofingSessionAccessException] when the server refuses this device -
/// expired, handed over to another device, already complete.
class ProofingSessionClient {
  const ProofingSessionClient();

  static Map<String, String> _headers(ProofingSessionRef ref, {bool json = false}) => {
    if (json) 'Content-Type': 'application/json',
    if (ref.deviceToken != null) 'X-Device-Token': ref.deviceToken!,
  };

  static Uri _appUri(ProofingSessionRef ref, [String path = '']) =>
      Uri.parse('${ref.apiBase}/api/v1/app/${ref.token}$path');

  /// Throws for anything but a 200: a [ProofingSessionAccessException] when
  /// the server refused this device access, a plain [Exception] otherwise.
  static void _check(http.Response response, String what) {
    if (response.statusCode == 200) return;
    final denial = proofingAccessDenialFor(response);
    if (denial != null) throw denial;
    if (response.statusCode == 429)
      throw Exception('$what failed: too many attempts, please wait a moment and try again');
    throw Exception('$what failed: ${response.statusCode} ${response.body}');
  }

  /// Claims the native slot with a grant token (single-use, short-lived):
  /// the empty slot's claim token, or a handover from the device holding
  /// it, which the server then revokes. The session itself - and every step
  /// already done - stays as it was.
  Future<ProofingSessionClaim> claimHandover(ProofingHandoverLink link) async {
    final response = await http.post(
      Uri.parse('${link.apiBase}/api/v1/app/handover/${Uri.encodeComponent(link.handoverToken)}/claim'),
    );
    _check(response, 'Taking over the session');
    return _claimFromJson(link.apiBase, json.decode(response.body) as Map<String, dynamic>);
  }

  static ProofingSessionClaim _claimFromJson(String apiBase, Map<String, dynamic> body) => ProofingSessionClaim(
    ref: ProofingSessionRef(
      apiBase: apiBase,
      token: body['token'] as String,
      deviceToken: body['deviceToken'] as String,
    ),
    info: ProofingSessionInfo.fromJson(body['session'] as Map<String, dynamic>),
  );

  /// The session's current state, as the server sees it.
  Future<ProofingSessionInfo> fetchSession(ProofingSessionRef ref) async {
    final response = await http.get(_appUri(ref), headers: _headers(ref));
    _check(response, 'Fetching the session');
    return ProofingSessionInfo.fromJson(json.decode(response.body));
  }

  /// Long-polls `GET /api/v1/app/{token}/events` until the session's view
  /// differs from [since] (a previous [ProofingSessionInfo.changeKey]) or
  /// the server's wait window elapses, then returns the current view. Unlike
  /// [fetchSession] this never marks anything server-side; it's purely for
  /// noticing changes such as a reset or a handover.
  /// [httpClient], when given, carries the request, so closing it aborts
  /// the wait (see ProofingSessionWatcher.pause).
  Future<ProofingSessionInfo> waitForChange(ProofingSessionRef ref, String since, {http.Client? httpClient}) async {
    final uri = _appUri(ref, '/events').replace(queryParameters: {'since': since});
    final response = await (httpClient?.get(uri, headers: _headers(ref)) ?? http.get(uri, headers: _headers(ref)));
    _check(response, 'Watching the session');
    return ProofingSessionInfo.fromJson(json.decode(response.body));
  }

  /// Tells the server whether this device is actively working on the
  /// session (app in the foreground) or not (backgrounded) - see
  /// ProofingSessionCoordinator. Returns the session's current state, which
  /// is what the app checks before it lets the user continue. Refused with
  /// 409 session_complete once the session was submitted, so the
  /// coordinator stops reporting at that point.
  Future<ProofingSessionInfo> reportDeviceState(ProofingSessionRef ref, {required bool active}) async {
    final response = await http.post(
      _appUri(ref, '/device/state'),
      headers: _headers(ref, json: true),
      body: json.encode({'state': active ? 'active' : 'inactive'}),
    );
    _check(response, 'Reporting the device state');
    return ProofingSessionInfo.fromJson(json.decode(response.body));
  }

  /// Submits the outcome. [status] must be one of: approved, rejected,
  /// needs_review, cancelled. Body shape mirrors the server's
  /// appResultRequest (document/photo/selfie/mrtdEvidence/biometrics/device) — each
  /// part is sent only when [requestedAttributes] asked for it, [device]
  /// excepted. The server computes and stores its own chipChecks verdict
  /// from [mrtdEvidence] — this client has no way to send a self-reported
  /// one; there's nothing to trust there. [requestedAttributes] should be
  /// the calling session's `ProofingSessionInfo.requestedAttributes`, so
  /// nothing is filtered against a list the app made up itself. See
  /// [buildProofingResultBody].
  ///
  /// Only for sessions without a flow (the step endpoints require one) and
  /// flows the step endpoints can't carry yet (document_capture without
  /// nfc_read, a face step without a chip read).
  Future<void> submitResult(
    ProofingSessionRef ref, {
    required String status,
    String? errorCode,
    required List<String> requestedAttributes,
    ProofingDocumentInfo? document,
    ProofingPhotoInfo? photo,
    ProofingPhotoInfo? selfie,
    ProofingMrtdEvidence? mrtdEvidence,
    ProofingBiometricsInfo? biometrics,
    ProofingDeviceInfo? device,
  }) async {
    final response = await http.post(
      _appUri(ref, '/result'),
      headers: _headers(ref, json: true),
      body: json.encode(
        buildProofingResultBody(
          status: status,
          errorCode: errorCode,
          requestedAttributes: requestedAttributes,
          document: document,
          photo: photo,
          selfie: selfie,
          mrtdEvidence: mrtdEvidence,
          biometrics: biometrics,
          device: device,
        ),
      ),
    );
    _check(response, 'Submitting the result');
  }

  /// Tells the server the user just began [step] (`POST .../steps/{step}/start`)
  /// — called the moment the step starts, not when its evidence is
  /// submitted, so the session moves to in_progress and the audit log gets
  /// that step's own in_progress row right away. Idempotent server-side.
  /// Callers go through [markActiveProofingStepStarted], which never lets a
  /// failure here interrupt the user.
  Future<void> markStepStarted(ProofingSessionRef ref, String step) async {
    final response = await http.post(_appUri(ref, '/steps/$step/start'), headers: _headers(ref));
    _check(response, 'Marking step $step started');
  }

  /// Submits the document_capture step - the identity read off the MRZ scan
  /// or typed in manually - the moment it's captured, with the [chipAccess]
  /// key so another device can resume at the chip read. The server then
  /// names the next step; a later [submitNfcStep] with a chip-read
  /// `document` replaces this copy.
  Future<ProofingStepResponse> submitDocumentCaptureStep(
    ProofingSessionRef ref, {
    required ProofingDocumentInfo document,
    ProofingChipAccess? chipAccess,
  }) async {
    final response = await http.post(
      _appUri(ref, '/steps/document_capture'),
      headers: _headers(ref, json: true),
      body: json.encode({'document': document.toJson(), 'chipAccess': ?chipAccess?.toJson()}),
    );
    _check(response, 'Submitting the document step');
    return ProofingStepResponse.fromJson(json.decode(response.body));
  }

  /// Submits the nfc_read step the moment the chip read completes, whether
  /// or not a face step follows. Its chip-read `document` replaces the
  /// MRZ copy [submitDocumentCaptureStep] sent. See
  /// [buildProofingNfcStepBody].
  Future<ProofingStepResponse> submitNfcStep(
    ProofingSessionRef ref, {
    required List<String> requestedAttributes,
    ProofingDocumentInfo? document,
    ProofingPhotoInfo? photo,
    required ProofingMrtdEvidence mrtdEvidence,
    ProofingDeviceInfo? device,
    bool faceStepFollows = false,
  }) async {
    final response = await http.post(
      _appUri(ref, '/steps/nfc'),
      headers: _headers(ref, json: true),
      body: json.encode(
        buildProofingNfcStepBody(
          requestedAttributes: requestedAttributes,
          document: document,
          photo: photo,
          mrtdEvidence: mrtdEvidence,
          device: device,
          faceStepFollows: faceStepFollows,
        ),
      ),
    );
    _check(response, 'Submitting the nfc step');
    return ProofingStepResponse.fromJson(json.decode(response.body));
  }

  /// Submits the face step this app performed itself (selfieLocation
  /// "native") the moment it completes: the live selfie only - the server
  /// computes liveness and the face match against the DG2 photo it already
  /// holds from [submitNfcStep], never trusting an on-device score.
  Future<ProofingStepResponse> submitSelfieStep(ProofingSessionRef ref, {required ProofingPhotoInfo selfie}) async {
    final response = await http.post(
      _appUri(ref, '/steps/selfie'),
      headers: _headers(ref, json: true),
      body: json.encode({'image': selfie.imageBase64, 'mimeType': selfie.mimeType}),
    );
    _check(response, 'Submitting the face verification step');
    return ProofingStepResponse.fromJson(json.decode(response.body));
  }

  /// Submits the session once every step of its flow has a result
  /// ([ProofingSessionInfo.readyToSubmit]) - only now does the server give
  /// it its outcome (lifecycle COMPLETE, status approved/rejected/...).
  /// Either device holding a slot may submit, and submitting again (a
  /// double tap, a retry after a network error, the other device having
  /// submitted first) just returns the finished state with alreadyRecorded,
  /// so this is safe to retry. Throws [ProofingStepsIncompleteException]
  /// when a step still lacks a result.
  ///
  /// Flow sessions only: a session without a flow still sends its single
  /// result through [submitResult].
  Future<ProofingStepResponse> submitSession(ProofingSessionRef ref) async {
    final response = await http.post(_appUri(ref, '/submit'), headers: _headers(ref));
    if (response.statusCode == 409 && _errorCodeOf(response) == 'steps_incomplete') {
      throw const ProofingStepsIncompleteException();
    }
    _check(response, 'Submitting the verification');
    return ProofingStepResponse.fromJson(json.decode(response.body));
  }
}
