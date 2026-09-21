import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:mrz_capture/mrz_capture.dart';
import 'package:vcmrtd/extensions.dart';
import 'package:vcmrtd/vcmrtd.dart';
import 'package:idem/utils/document_dates.dart';

/// Points at one identity-proofing session, resolved from a scanned QR code
/// or deep link. See identity-proofing-service's docs/session-model.md for
/// the API this talks to.
///
/// The `qr` field of that service's create-session response is a plain URL
/// (`https://{host}/s/{token}`); its `deepLink` is a custom-scheme URL
/// (`vcmrtd://verify?token=...&api=...`). Both encode the same two things —
/// which API to call, and the token that authorises acting on the session —
/// so [parse] accepts either shape.
class ProofingSessionRef {
  final String apiBase;
  final String token;

  const ProofingSessionRef({required this.apiBase, required this.token});

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

  ProofingSessionInfo({
    required this.id,
    required this.relyingParty,
    required this.requestedAttributes,
    required this.expiresAt,
    this.aaChallenge,
    this.steps,
    this.referencePhoto,
    this.selfieLocation = 'browser',
  });

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
  );
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
/// has landed (see identity-proofing-service's evaluateSessionCompletion).
Map<String, dynamic> buildProofingNfcStepBody({
  required List<String> requestedAttributes,
  ProofingDocumentInfo? document,
  ProofingPhotoInfo? photo,
  required ProofingMrtdEvidence mrtdEvidence,
  ProofingDeviceInfo? device,
}) {
  final includeDocument = document != null && _attrRequested(requestedAttributes, [_attrDocument]);
  final includeDG11 = _attrRequested(requestedAttributes, [_attrDG11]);
  final includePhoto = photo != null && _attrRequested(requestedAttributes, [_attrDG2, _attrFaceImage]);

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
class ProofingSessionClient {
  const ProofingSessionClient();

  Future<ProofingSessionInfo> fetchSession(ProofingSessionRef ref) async {
    final response = await http.get(Uri.parse('${ref.apiBase}/api/v1/app/${ref.token}'));
    if (response.statusCode != 200) {
      throw Exception('Fetching the session failed: ${response.statusCode} ${response.body}');
    }
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
      Uri.parse('${ref.apiBase}/api/v1/app/${ref.token}/result'),
      headers: {'Content-Type': 'application/json'},
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
    if (response.statusCode != 200) {
      throw Exception('Submitting the result failed: ${response.statusCode} ${response.body}');
    }
  }

  /// Submits the nfc_read step and stops there — used instead of
  /// [submitResult] whenever [nativeFaceVerificationRequested] is false: the
  /// session's flow wants face verification, but performed by the browser
  /// hosted flow, not this app. The server holds the session at whatever
  /// status the accumulated steps imply (typically in_progress) until the
  /// browser's own `POST .../steps/selfie` lands — see
  /// identity-proofing-service's evaluateSessionCompletion. See
  /// [buildProofingNfcStepBody].
  Future<void> submitNfcStep(
    ProofingSessionRef ref, {
    required List<String> requestedAttributes,
    ProofingDocumentInfo? document,
    ProofingPhotoInfo? photo,
    required ProofingMrtdEvidence mrtdEvidence,
    ProofingDeviceInfo? device,
  }) async {
    final response = await http.post(
      Uri.parse('${ref.apiBase}/api/v1/app/${ref.token}/steps/nfc'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(
        buildProofingNfcStepBody(
          requestedAttributes: requestedAttributes,
          document: document,
          photo: photo,
          mrtdEvidence: mrtdEvidence,
          device: device,
        ),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Submitting the nfc step failed: ${response.statusCode} ${response.body}');
    }
  }
}
