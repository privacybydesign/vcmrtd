import 'dart:convert';

// foundation.dart re-exports meta's @visibleForTesting, so it replaces the
// former package:meta import outright.
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:vcmrtd/vcmrtd.dart';

/// A face verification method, as named on the wire between the wallet and the
/// passport issuer.
///
/// The wallet declares which of these it can run ([StartValidationRequest]);
/// the issuer assigns one per document session ([FaceVerificationConfig]).
/// [regula] and [iris] keep the verdict on the issuer side and differ only in
/// how the live face reaches it; [irisOndevice] does not, and trades that
/// guarantee for sending no frames at all.
enum FaceVerificationMethod {
  /// A Regula liveness capture (native SDK or the web capture page) whose
  /// transaction id the issuer matches against the chip portrait.
  regula('regula'),

  /// A Yivi capture screen streaming camera frames to the Yivi-run Iris
  /// verifier, which matches them against the portrait the issuer supplied.
  iris('iris'),

  /// The vendor's Iris SDK running on the device, matching the live face
  /// against the chip portrait the wallet just read. Only the verdict travels:
  /// no frames leave the phone, and the issuer has nothing to check it
  /// against — unlike the other two methods, which keep the verdict on the
  /// issuer side. See
  /// `irmamobile/docs/on-device-iris-face-verification-plan.md` §3.
  irisOndevice('iris_ondevice');

  const FaceVerificationMethod(this.wireName);

  /// The value used in JSON, e.g. `"regula"`.
  final String wireName;

  /// The method named by a wire value, or `null` for anything this build does
  /// not know. Unknown values are ignored rather than rejected so a newer
  /// issuer can name a method this wallet cannot run without breaking the
  /// parse; the flow then fails closed at issuance.
  static FaceVerificationMethod? tryParse(Object? wireName) {
    for (final method in values) {
      if (method.wireName == wireName) return method;
    }
    return null;
  }
}

/// Face verification configuration the issuer announces for one document
/// session.
///
/// The announcement's *presence* is the signal that face verification applies:
/// the issuer includes it in the start-validation response whenever its policy
/// enables face verification, and the app must skip the whole face
/// verification step when it is absent. There is deliberately no `enabled`
/// flag inside.
class FaceVerificationConfig {
  /// The method the issuer assigned to this session. Issuers that predate the
  /// method field announce only a `face_api_url`; the parser reads that as
  /// [FaceVerificationMethod.regula], which is the only method they know.
  final FaceVerificationMethod method;

  /// Browser/app-reachable origin of the Regula Face API the liveness session
  /// must run against — the same service the issuer matches against, so the
  /// liveness transaction id resolves at issuance. Always an absolute https
  /// URL when [method] is [FaceVerificationMethod.regula]; a Regula
  /// announcement carrying anything else is treated as absent. `null` for
  /// every other method.
  final String? faceApiUrl;

  const FaceVerificationConfig({this.method = FaceVerificationMethod.regula, this.faceApiUrl});
}

/// Coarse labels describing the wallet build, sent with the start-validation
/// request so the issuer can record face verification attempts per platform,
/// flavor and version. Never stored with document data.
class ClientInfo {
  /// `android` or `ios`.
  final String platform;

  /// The distribution flavor, e.g. `play`, `appstore` or `fdroid`.
  final String flavor;

  /// The app version as shown to the user, e.g. `8.3.0`.
  final String appVersion;

  const ClientInfo({required this.platform, required this.flavor, required this.appVersion});

  Map<String, dynamic> toJson() => {'platform': platform, 'flavor': flavor, 'app_version': appVersion};
}

/// What the wallet tells the issuer when it starts a document session.
///
/// The [capabilities] are a fact about the build, not a preference: the issuer
/// picks the method. [previousMethod] and [attempt] are set on a retry within
/// one document flow so the issuer keeps the same method while it is still a
/// candidate. [preferredMethod] is a tester override the issuer honours only
/// when configured to (staging).
class StartValidationRequest {
  final List<FaceVerificationMethod> capabilities;
  final FaceVerificationMethod? previousMethod;
  final int? attempt;
  final FaceVerificationMethod? preferredMethod;
  final ClientInfo? client;

  const StartValidationRequest({
    required this.capabilities,
    this.previousMethod,
    this.attempt,
    this.preferredMethod,
    this.client,
  });

  Map<String, dynamic> toJson() => {
    'face_verification': {
      'capabilities': [for (final m in capabilities) m.wireName],
      if (previousMethod != null) 'previous_method': previousMethod!.wireName,
      if (attempt != null) 'attempt': attempt,
      if (preferredMethod != null) 'preferred_method': preferredMethod!.wireName,
    },
    if (client != null) 'client': client!.toJson(),
  };
}

/// Result of starting a validation session at the passport issuer:
/// the anti-replay [nonceAndSessionId] for active authentication, plus the
/// issuer's [faceVerification] announcement when face verification applies to
/// this session.
class StartValidationResult {
  final NonceAndSessionId nonceAndSessionId;

  /// Present iff the issuer requires the face verification step for this
  /// session; `null` means the app skips it entirely.
  final FaceVerificationConfig? faceVerification;

  StartValidationResult({required this.nonceAndSessionId, this.faceVerification});
}

/// Interface for passport issuance http requests so they can be mocked/spied in the integration tests
abstract class PassportIssuer {
  /// Starts a session at the passport issuer server, which will return a nonce and
  /// session id to be used during passport reading to prove the readout is not a replay,
  /// along with the issuer's face verification announcement (when it applies).
  ///
  /// [request] declares what this wallet can run (see [StartValidationRequest]).
  /// Without one no body is sent, which is what wallets before the capability
  /// declaration did; the issuer then treats the wallet as Regula-only.
  Future<StartValidationResult> startSessionAtPassportIssuer({StartValidationRequest? request});

  /// Initiates the issuance session at the irma server and returns a session pointer,
  /// which the app will use to start the normal issuance session flow.
  Future<IrmaSessionPointer> startIrmaIssuanceSession(RawDocumentData documentDataResult, DocumentType docType);

  /// Only verifies the passport scanning result without starting an irma issuance session
  Future<VerificationResponse> verifyPassport(RawDocumentData passportDataResult);

  /// Only verifies the driving licence scanning result without starting an irma issuance session
  Future<VerificationResponse> verifyDrivingLicence(RawDocumentData drivingLicenceDataResult);
}

/// Default passport issuer implementation that is used in production and talks to actual
/// passport issuer & irma servers
class DefaultPassportIssuer implements PassportIssuer {
  final String hostName;

  /// Hosts the server-supplied `irma_server_url` is allowed to point at.
  ///
  /// The IRMA JWT posted to that URL contains the raw biometric passport scan
  /// data, so a compromised issuer (or an http/MiTM path) must not be able to
  /// redirect it to an arbitrary host. When not provided, the allowlist
  /// defaults to the host of [hostName], i.e. the biometric data may only be
  /// sent back to the configured issuer origin.
  final Set<String> allowedIrmaHosts;

  DefaultPassportIssuer({required this.hostName, Iterable<String>? allowedIrmaHosts})
    : allowedIrmaHosts = {
        ...?allowedIrmaHosts,
        if (allowedIrmaHosts == null) ...{if (Uri.tryParse(hostName)?.host case final String h when h.isNotEmpty) h},
      };

  /// Validates a server-supplied session URL before biometric data is posted
  /// to it. The URL must be absolute, use https and target a host on
  /// [allowedIrmaHosts]. Throws [Exception] otherwise.
  @visibleForTesting
  Uri validateSessionUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.isAbsolute || uri.host.isEmpty) {
      throw Exception('Invalid session URL supplied by the issuer');
    }
    if (uri.scheme != 'https') {
      throw Exception('Refusing to post biometric data over non-https session URL');
    }
    if (!allowedIrmaHosts.contains(uri.host)) {
      throw Exception('Session URL host "${uri.host}" is not in the allowed host list');
    }
    return uri;
  }

  // Start a passport issuer session (so not irma session yet)
  @override
  Future<StartValidationResult> startSessionAtPassportIssuer({StartValidationRequest? request}) async {
    final body = startValidationBody(request);
    final storeResp = await http.post(
      Uri.parse('$hostName/api/start-validation'),
      headers: {'Content-Type': 'application/json'},
      body: body == null ? null : json.encode(body),
    );
    if (storeResp.statusCode != 200) {
      throw Exception('Store failed: ${storeResp.statusCode} ${storeResp.body}');
    }

    return parseStartValidationResponse(json.decode(storeResp.body));
  }

  /// The JSON body sent to `/api/start-validation`, or `null` when there is
  /// nothing to declare. `null` keeps the request byte-identical to what
  /// wallets before the capability declaration send.
  @visibleForTesting
  static Map<String, dynamic>? startValidationBody(StartValidationRequest? request) => request?.toJson();

  /// Whether a server-supplied `face_api_url` may be used as the destination
  /// of the liveness session.
  ///
  /// The user's liveness selfie is uploaded to this URL, so it is held to the
  /// same absolute-https rule as [validateSessionUrl]. There is no host
  /// allowlist here: the Face API legitimately runs on a different host from
  /// the issuer, so allowlisting it needs its own configured list, the way
  /// [allowedIrmaHosts] is plumbed.
  @visibleForTesting
  static bool isValidFaceApiUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.isAbsolute || uri.scheme != 'https' || uri.host.isEmpty) return false;
    // A host containing whitespace (percent-encoded by Uri, so it survives the
    // checks above) is never a real Face API host.
    return !RegExp(r'\s').hasMatch(url);
  }

  /// Parses a start-validation response body.
  ///
  /// The `face_verification` announcement is optional: issuers with face
  /// verification disabled (and issuer versions that predate it) omit the
  /// field. Five shapes are recognised:
  ///
  /// - absent → no face verification;
  /// - `{"method": "regula", "face_api_url": "https://…"}` → Regula;
  /// - `{"face_api_url": "https://…"}` (issuers before the method field) →
  ///   Regula, the only method those issuers know;
  /// - `{"method": "iris"}` → Iris, no Face API URL;
  /// - `{"method": "iris_ondevice"}` → on-device Iris; nothing to address, so
  ///   no URL either.
  ///
  /// A malformed announcement — not an object, a Regula one without a
  /// `face_api_url` that passes [isValidFaceApiUrl], or a method this build
  /// does not know — is treated as absent rather than rejected: skipping the
  /// step can never produce an unverified issuance because the issuer rejects
  /// issuance without the evidence it assigned.
  @visibleForTesting
  static StartValidationResult parseStartValidationResponse(dynamic response) {
    FaceVerificationConfig? faceVerification;
    final announcement = response['face_verification'];
    if (announcement is Map) {
      final method = announcement.containsKey('method')
          ? FaceVerificationMethod.tryParse(announcement['method'])
          : FaceVerificationMethod.regula;
      final faceApiUrl = announcement['face_api_url'];
      switch (method) {
        case FaceVerificationMethod.regula:
          if (faceApiUrl is String && isValidFaceApiUrl(faceApiUrl)) {
            faceVerification = FaceVerificationConfig(method: FaceVerificationMethod.regula, faceApiUrl: faceApiUrl);
          }
        case FaceVerificationMethod.iris:
          faceVerification = const FaceVerificationConfig(method: FaceVerificationMethod.iris);
        case FaceVerificationMethod.irisOndevice:
          faceVerification = const FaceVerificationConfig(method: FaceVerificationMethod.irisOndevice);
        case null:
          break;
      }
    }
    if (faceVerification == null && announcement != null) {
      // Absence is routine, but a rejected announcement means the issuer sent a
      // shape this parser does not recognise — without a log the app just looks
      // like face verification never applied.
      debugPrint('vcmrtd: ignoring malformed face_verification announcement: $announcement');
    }
    return StartValidationResult(
      nonceAndSessionId: NonceAndSessionId(
        sessionId: response['session_id'].toString(),
        nonce: response['nonce'].toString(),
      ),
      faceVerification: faceVerification,
    );
  }

  // Starts the issuance session with the irma server with passport scan result
  @override
  Future<IrmaSessionPointer> startIrmaIssuanceSession(RawDocumentData documentDataResult, DocumentType docType) async {
    final endpoint = switch (docType) {
      DocumentType.drivingLicence => "issue-driving-licence",
      DocumentType.passport => "issue-passport",
      DocumentType.identityCard => "issue-id-card",
    };
    // Create secure data payload
    final payload = documentDataResult.toJson();
    // Get the signed IRMA JWT from the passport issuer
    final responseBody = await _getIrmaSessionJwt(hostName, endpoint, payload);
    final irmaServerUrlParam = responseBody['irma_server_url'];
    final jwtUrlParam = responseBody['jwt'];

    // Start the session
    final sessionResponseBody = await _startIrmaSession(jwtUrlParam, irmaServerUrlParam);
    final sessionPtr = sessionResponseBody['sessionPtr'];

    return IrmaSessionPointer.fromJson(sessionPtr);
  }

  @override
  Future<VerificationResponse> verifyPassport(RawDocumentData passportDataResult) async {
    final payload = passportDataResult.toJson();

    final String jsonPayload = json.encode(payload);

    final response = await http.post(
      Uri.parse('$hostName/api/verify-passport'),
      headers: {'Content-Type': 'application/json'},
      body: jsonPayload,
    );

    if (response.statusCode != 200) {
      throw Exception('Verification request failed: ${response.statusCode} ${response.body}');
    }

    final responseBody = jsonDecode(response.body);
    return VerificationResponse.fromJson(responseBody);
  }

  @override
  Future<VerificationResponse> verifyDrivingLicence(RawDocumentData passportDataResult) async {
    final payload = passportDataResult.toJson();

    final String jsonPayload = json.encode(payload);

    final response = await http.post(
      Uri.parse('$hostName/api/verify-driving-licence'),
      headers: {'Content-Type': 'application/json'},
      body: jsonPayload,
    );

    if (response.statusCode != 200) {
      throw Exception('Verification request failed: ${response.statusCode} ${response.body}');
    }

    final responseBody = jsonDecode(response.body);
    return VerificationResponse.fromJson(responseBody);
  }

  Future<dynamic> _getIrmaSessionJwt(String hostName, String endpoint, Map<String, dynamic> payload) async {
    final String jsonPayload = json.encode(payload);
    final storeResp = await http.post(
      Uri.parse('$hostName/api/$endpoint'),
      headers: {'Content-Type': 'application/json'},
      body: jsonPayload,
    );
    if (storeResp.statusCode != 200) {
      throw Exception('Store failed: ${storeResp.statusCode} ${storeResp.body}');
    }

    return json.decode(storeResp.body);
  }

  Future<dynamic> _startIrmaSession(String jwt, String irmaServerUrl) async {
    // Validate the server-supplied URL (https + allowed host) before posting
    // the IRMA JWT, which carries the raw biometric passport scan data.
    validateSessionUrl(irmaServerUrl);
    // Start the IRMA session
    final response = await http.post(Uri.parse('$irmaServerUrl/session'), body: jwt);
    if (response.statusCode != 200) {
      throw Exception('Store failed: ${response.statusCode} ${response.body}');
    }

    return json.decode(response.body);
  }
}
