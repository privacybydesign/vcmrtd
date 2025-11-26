import 'dart:convert';

import 'package:http/http.dart' as http;
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

  DefaultPassportIssuer({required this.hostName});

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
      DocumentType.driverLicense => "issue-driving-licence",
      DocumentType.passport => "issue-passport",
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
    // Start the IRMA session
    final response = await http.post(Uri.parse('$irmaServerUrl/session'), body: jwt);
    if (response.statusCode != 200) {
      throw Exception('Store failed: ${response.statusCode} ${response.body}');
    }

    return json.decode(response.body);
  }
}
