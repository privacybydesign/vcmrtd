import 'dart:convert';
import 'package:http/http.dart' as http;

/// Service to handle all passport-related API calls
class ApiService {
  static const String _baseUrl = 'https://passport-issuer.staging.yivi.app/api';

  /// Verify passport data via API
  Future<Map<String, dynamic>> verifyPassport(Map<String, dynamic> payload) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/verify-passport'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(payload),
    );

    if (response.statusCode != 200) {
      throw Exception('Verification failed: ${response.statusCode} ${response.body}');
    }

    return json.decode(response.body);
  }

  /// Get IRMA session JWT for issuing credentials
  Future<Map<String, dynamic>> getIrmaSessionJwt(Map<String, dynamic> payload) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/verify-and-issue'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(payload),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to get JWT: ${response.statusCode} ${response.body}');
    }

    return json.decode(response.body);
  }

  /// Start an IRMA session
  Future<Map<String, dynamic>> startIrmaSession(String jwt, String irmaServerUrl) async {
    final response = await http.post(
      Uri.parse('$irmaServerUrl/session'),
      body: jwt,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to start session: ${response.statusCode} ${response.body}');
    }

    return json.decode(response.body);
  }

  /// Generate universal link for IRMA session
  String generateUniversalLink(String urlEncodedSessionPtr) {
    return 'https://open.staging.yivi.app/-/session#$urlEncodedSessionPtr';
  }
}