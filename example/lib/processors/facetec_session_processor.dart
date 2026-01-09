import 'package:flutter/services.dart';
import 'package:vcmrtdapp/utilities/facetec_networking.dart';

/// Session Request Processor for FaceTec 3D Liveness Checks
///
/// This class handles the session processing for FaceTec SDK.
/// It receives callbacks from the native code and handles server communication.
class FaceTecSessionProcessor {
  bool success = false;
  bool isRequestInProgress = false;

  static const MethodChannel _channel =
      MethodChannel('com.facetec.sdk/livenesscheck');

  FaceTecSessionProcessor() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  /// Handle incoming calls from native code (Android or iOS)
  Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'processSession':
        await _processSession(
          call.arguments['sessionRequestBlob'],
          call.arguments['externalDatabaseRefID'],
          call.arguments['userAgentString'],
        );
        break;
      default:
        break;
    }
  }

  /// Process a session request
  ///
  /// [sessionRequestBlob] - The session data from FaceTec SDK
  /// [externalDatabaseRefID] - Optional external reference ID
  /// [userAgentString] - User agent for API requests
  Future<void> _processSession(
    String sessionRequestBlob,
    String externalDatabaseRefID,
    String userAgentString,
  ) async {
    // Prepare parameters for the API request
    final parameters = {
      "requestBlob": sessionRequestBlob,
      "userAgentString": userAgentString,
    };

    // Include external database reference ID if provided
    // This is for demonstration purposes
    // In your app, handle this in your backend
    if (externalDatabaseRefID.isNotEmpty) {
      parameters["externalDatabaseRefID"] = externalDatabaseRefID;
    }

    // Send the request to the FaceTec server
    FaceTecNetworking(
      userAgentString: userAgentString,
      methodChannel: _channel,
    ).send(parameters);
  }
}
