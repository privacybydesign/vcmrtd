import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:vcmrtdapp/facetec_config.dart';

/// Networking class for handling FaceTec SDK server communication
///
/// This class handles the networking calls required for FaceTec to function.
/// In production, use your own secure networking infrastructure.
class FaceTecNetworking {
  final String _endpoint = "/process-request";
  final String userAgentString;
  final MethodChannel methodChannel;

  FaceTecNetworking({
    required this.userAgentString,
    required this.methodChannel,
  });

  /// Send session request to FaceTec server
  ///
  /// [parameters] contains the session request blob and user agent string
  Future<void> send(Map<String, dynamic> parameters) async {
    final url = Uri.parse('${FaceTecConfig.baseURL}$_endpoint');

    // Set up the network request
    final request = http.Request('POST', url)
      ..headers['Content-Type'] = 'application/json'
      // NOTE: These headers are ONLY for FaceTec Testing API
      // Remove when using your own backend
      ..headers['X-Device-Key'] = FaceTecConfig.deviceKeyIdentifier
      ..headers['X-Testing-API-Header'] = userAgentString
      ..body = jsonEncode(parameters);

    try {
      // Make the API call
      final response = await http.Client().send(request);
      final fullResponse = await response.stream.transform(utf8.decoder).join();

      await processAPIResponse(fullResponse);
    } catch (error) {
      // Handle catastrophic network error
      await methodChannel.invokeMethod("onCatastrophicNetworkError", {});
    }
  }

  /// Process the API response from FaceTec server
  Future<void> processAPIResponse(String response) async {
    try {
      final responseJSON = jsonDecode(response);

      if (responseJSON['error'] == true) {
        // Catastrophic error occurred
        await methodChannel.invokeMethod("onCatastrophicNetworkError", {});
        return;
      }

      if (responseJSON['responseBlob'] != null) {
        final scanResultBlob = responseJSON['responseBlob'];
        await methodChannel.invokeMethod(
          "onResponseBlobReceived",
          {"responseBlob": scanResultBlob},
        );
        return;
      } else {
        await methodChannel.invokeMethod("onCatastrophicNetworkError", {});
      }
    } catch (e) {
      await methodChannel.invokeMethod("onCatastrophicNetworkError", {});
    }
  }
}
