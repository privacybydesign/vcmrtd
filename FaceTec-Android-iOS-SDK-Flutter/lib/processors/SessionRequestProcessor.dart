import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../utilities/SampleAppNetworkingRequest.dart';

// This is an example of a self-contained class to perform 3D Liveness Checks with the FaceTecSDK.
// You may choose to further componentize parts of this in your own apps based on your specific requirements.
class SessionRequestProcessor {
  bool success = false;
  bool isRequestInProgress = false;
  http.Request? latestNetworkRequest;

  static const MethodChannel _channel = MethodChannel('com.facetec.sdk/livenesscheck');

  SessionRequestProcessor() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    // Handle incoming calls from native code, either Android or iOS.
    switch (call.method) {
      case 'processSession': {

        await processSession(
          call.arguments['sessionRequestBlob'],
          call.arguments['externalDatabaseRefID'],
          call.arguments['userAgentString']
          );
        break;
      }
      default:
        break;
    }
  }

  //
  // Handle a session request
  //
  processSession(
    String sessionRequestBlob,
    String externalDatabaseRefID,
    String userAgentString
    ) async {
      //
      // Get the essential session data from the native arguments
      //
      final parameters = {
        "requestBlob" : sessionRequestBlob,
        "userAgentString" : userAgentString
      };

      // externalDatabaseRefID is included in FaceTec Device SDK Sample App Code for demonstration purposes.
      // In Your App, you will be setting and handling this in Your Webservice code.
      if (externalDatabaseRefID != "") {
        parameters["externalDatabaseRefID"] = externalDatabaseRefID;
      }

      SampleAppNetworkingRequest(userAgentString: userAgentString, methodChannel: _channel).send(parameters);
  }
}