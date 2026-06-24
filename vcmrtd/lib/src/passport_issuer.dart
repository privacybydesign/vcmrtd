import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:vcmrtd/src/extension/logging_apis.dart';
import 'package:vcmrtd/vcmrtd.dart';

/// Interface for passport issuance http requests so they can be mocked/spied in the integration tests
abstract class PassportIssuer {
  /// Starts a session at the passport issuer server, which will return a nonce and
  /// session id to be used during passport reading to prove the readout is not a replay.
  Future<NonceAndSessionId> startSessionAtPassportIssuer();

  /// Initiates the issuance session at the irma server and returns a session pointer,
  /// which the app will use to start the normal issuance session flow.
  ///
  /// When the issuer has face verification enabled, issuance is gated on a
  /// successful face verification. Pass the [faceSessionId] obtained from the
  /// preceding [verifyPassport] response so the issuer can look up the
  /// authoritative face verification result.
  Future<IrmaSessionPointer> startIrmaIssuanceSession(
    RawDocumentData documentDataResult,
    DocumentType docType, {
    String? faceSessionId,
  });

  /// Only verifies the passport scanning result without starting an irma issuance session
  Future<VerificationResponse> verifyPassport(RawDocumentData passportDataResult);

  /// Only verifies the driving licence scanning result without starting an irma issuance session
  Future<VerificationResponse> verifyDrivingLicence(RawDocumentData drivingLicenceDataResult);
}

/// Default passport issuer implementation that is used in production and talks to actual
/// passport issuer & irma servers
class DefaultPassportIssuer implements PassportIssuer {
  static final _log = Logger("PassportIssuer");

  final String hostName;

  DefaultPassportIssuer({required this.hostName});

  /// Performs an HTTP POST while logging the request and response. The URL and
  /// status code are logged at INFO/DEBUG, while the request and response bodies
  /// are logged as sensitive data (only emitted when sensitive-data logging is
  /// enabled) since they can contain document data.
  Future<http.Response> _loggedPost(Uri url, {Map<String, String>? headers, Object? body}) async {
    _log.info("POST $url");
    if (body != null) {
      _log.sdVerbose("POST $url request body: $body");
    }

    try {
      final response = await http.post(url, headers: headers, body: body);
      _log.debug("POST $url -> ${response.statusCode}");
      _log.sdVerbose("POST $url response body: ${response.body}");
      return response;
    } catch (e, st) {
      _log.error("POST $url failed", e, st);
      rethrow;
    }
  }

  // Start a passport issuer session (so not irma session yet)
  @override
  Future<NonceAndSessionId> startSessionAtPassportIssuer() async {
    final storeResp = await _loggedPost(
      Uri.parse('$hostName/api/start-validation'),
      headers: {'Content-Type': 'application/json'},
    );
    if (storeResp.statusCode != 200) {
      throw Exception('Store failed: ${storeResp.statusCode} ${storeResp.body}');
    }

    final response = json.decode(storeResp.body);
    return NonceAndSessionId(sessionId: response['session_id'].toString(), nonce: response['nonce'].toString());
  }

  // Starts the issuance session with the irma server with passport scan result
  @override
  Future<IrmaSessionPointer> startIrmaIssuanceSession(
    RawDocumentData documentDataResult,
    DocumentType docType, {
    String? faceSessionId,
  }) async {
    final endpoint = switch (docType) {
      DocumentType.drivingLicence => "issue-driving-licence",
      DocumentType.passport => "issue-passport",
      DocumentType.identityCard => "issue-id-card",
    };
    // Create secure data payload
    final payload = documentDataResult.toJson();
    // When present, lets the issuer correlate the gated face verification result.
    if (faceSessionId != null) {
      payload['face_session_id'] = faceSessionId;
    }
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

    final response = await _loggedPost(
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

    final response = await _loggedPost(
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
    final storeResp = await _loggedPost(
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
    // Start the IRMA session
    final response = await _loggedPost(Uri.parse('$irmaServerUrl/session'), body: jwt);
    if (response.statusCode != 200) {
      throw Exception('Store failed: ${response.statusCode} ${response.body}');
    }

    return json.decode(response.body);
  }
}
