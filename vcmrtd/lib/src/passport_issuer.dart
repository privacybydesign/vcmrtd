import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';
import 'package:vcmrtd/vcmrtd.dart';

/// Interface for passport issuance http requests so they can be mocked/spied in the integration tests
abstract class PassportIssuer {
  /// Starts a session at the passport issuer server, which will return a nonce and
  /// session id to be used during passport reading to prove the readout is not a replay.
  Future<NonceAndSessionId> startSessionAtPassportIssuer();

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
  Future<NonceAndSessionId> startSessionAtPassportIssuer() async {
    final storeResp = await http.post(
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
