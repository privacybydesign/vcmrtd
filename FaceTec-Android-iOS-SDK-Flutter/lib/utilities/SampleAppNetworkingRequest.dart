import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../facetec_config.dart';

// Sample class for handling networking calls needed in order for FaceTec to function correctly.
// In Your App, please use the networking constructs and protocols that meet your security requirements.
//
// Notes:
// - Adding additional logic to this code is not allowed.  Do not add any additional logic outside of what is demonstrated in this Sample.
// - Adding additional asynchronous calls to this code is not allowed.  Only make your own additional asynchronous calls once the FaceTec UI is closed.
// - Adding code that modifies any App UI (Yours or FaceTec's) is not allowed.  Only add code that modifies your own App UI once the FaceTec UI is closed.
class SampleAppNetworkingRequest {
  final String _endpoint = "/process-request";
  final String userAgentString;
  final MethodChannel methodChannel;

  SampleAppNetworkingRequest({
    required this.userAgentString,
    required this.methodChannel,
  });
  
  //
  // Step 1: Construct the payload.
  //
  // - The payload contains the Session Request Blob
  // - Please see the notes below about correctly handling externalDatabaseRefID for certain call types.
  //
  void send(
    Map<String, dynamic> parameters,
  ) async {
    final url = Uri.parse('${FaceTecConfig.baseURL}$_endpoint');

    //
    // Step 2: Set up the networking request.
    //
    // - This Sample App demonstrates making calls to the FaceTec Testing API by default.
    // - In Your App, please use the webservice endpoint you have set up that accepts networking requests from Your App.
    // - In Your Webservice, build an endpoint that takes incoming requests, and forwards them to FaceTec Server.
    // - This code should never call your server directly. It should contact middleware you have created that forwards requests to your server.
    //
    final request = http.Request('POST', url)
      ..headers['Content-Type'] = 'application/json'

      // Developer Note: This is ONLY needed for calls to the FaceTec Testing API.
      // You should remove this when using Your App connected to Your Webservice + FaceTec Server
      ..headers['X-Device-Key'] = FaceTecConfig.deviceKeyIdentifier

      // Developer Note: This is ONLY needed for calls to the FaceTec Testing API.
      // You should remove this when using Your App connected to Your Webservice + FaceTec Server
      ..headers['X-Testing-API-Header'] = userAgentString
      ..body = jsonEncode(parameters);

    //
    // Step 3: Make the API Call, and handle the response.
    //
    // - Unless there is a networking error, or an error in your webservice or infrastructure, the Response Blob is retrieved and passed back into processResponse.
    // - For error cases, abortOnCatastrophicError is called as this would indicate a networking issue on the User device or network, or an error in Your Webservice.
    //
    final response = await http.Client().send(request);
    final fullResponse = await response.stream.transform(utf8.decoder).join();

    try {
      processAPIResponse(fullResponse);
    }
    catch (error) {
      await methodChannel.invokeMethod("onCatastrophicNetworkError", {});
    }
  }

  Future<void> processAPIResponse(response) async {
    //
    // Step 4:  Get the Response Blob and call process the response.
    //
    final responseJSON = jsonDecode(response);
    
    if (responseJSON['error'] == true) {
      // On catastrophic error call the onCatastrophicNetworkError handler
      // This should never be called except when a hard server error occurs. For example the user loses network connectivity.
      // You may want to implement some sort of retry logic here
      await methodChannel.invokeMethod("onCatastrophicNetworkError", {});
      return;
    }

    if (responseJSON['responseBlob'] != null) {
      final scanResultBlob = responseJSON['responseBlob'];
      await methodChannel.invokeMethod("onResponseBlobReceived", {"responseBlob": scanResultBlob});
      return;
    }
    else { 
      await methodChannel.invokeMethod("onCatastrophicNetworkError", {});
    }
  }
}