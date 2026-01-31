import Foundation
import FaceTecSDK

// This class demonstrates the most important integration point in the FaceTec Device SDK  -- The Session Request Processor.
//
// The Session Request Processor:
// - Implements an onSessionRequest function.  This function is called by the FaceTec Device SDK.
// - The onSessionRequest function is always passed a sessionRequestBlob, and you always send this blob up to your webservice, and into FaceTec Server.
// - The Session Request Blob is an encrypted string that you get and send to FaceTec Server.
// - Upon receiving the Response Blob from FaceTec Server, you will always call the sessionRequestCallback.processResponse function.
// - The Session Response Blob is an encrypted string that you get from FaceTec Server and pass back into the Device SDK.
// - The Session Request Callback  This is called when you receive a response from the FaceTec Server, with the blob that you receive from FaceTec Server.
// - The Session Request Callback provides a updateProgress function, where you can pass in the upload progress, controlling the Upload Screen Progress Bar.
//
// Notes:
// - Adding additional logic to this code is not allowed.  Do not add any additional logic outside of what is demonstrated in this Sample.
// - Adding additional asynchronous calls to this code is not allowed.  Only make your own additional asynchronous calls once the FaceTec UI is closed.
// - Adding code that modifies any App UI (Yours or FaceTec's) is not allowed.  Only add code that modifies your own App UI once the FaceTec UI is closed.
class SessionRequestProcessor: NSObject, FaceTecSessionRequestProcessor, URLSessionTaskDelegate {
    // onSessionRequest is the core method called by the FaceTec SDK when a request needs to be processed by the FaceTec SDK.
    // Your code must retrieve the Session Request Blob and send to your FaceTec Server.
    // Your code must retrieve the Response Blob from FaceTec Server and call processResponse, passing in the Response Blob.
    func onSessionRequest(sessionRequestBlob: String, sessionRequestCallback: FaceTecSessionRequestProcessorCallback) {
        // When you receive a Session Request Blob, call your webservice API that handles this object and passes it to FaceTec Server.
        // SampleAppNetworkingRequest is a demonstration class for making a networking call that passes the Session Request Blob, and handles the response.
        let request = SampleAppNetworkingRequest(referencingProcessor: self, sessionRequestCallback: sessionRequestCallback)
        request.send(sessionRequestBlob: sessionRequestBlob)        
    }

    // When the Response Blob is received, call processResponse with it.
    // Please note that onResponseBlobReceived is a convenience function set up on this class,
    // so that this function can be called asynchronously once you receive the Response Blob.
    func onResponseBlobReceived(responseBlob: String, sessionRequestCallback: FaceTecSessionRequestProcessorCallback) {
        sessionRequestCallback.processResponse(responseBlob);
    }
    
    // When upload progress is received from your webservice, call updateProgress to update the Progress Bar state.
    // Please note that onUploadProgress is a convenience function set up on this class,
    // so that this function can be called asynchronously when your networking code receives an upload progress event.
    func onUploadProgress(progress: Float, sessionRequestCallback: FaceTecSessionRequestProcessorCallback) {
        sessionRequestCallback.updateProgress(progress);
    }
    
    // Calling abortOnCatastrophicError is not allowed except for catastrophic network failures.
    // Calling abortOnCatastrophicError to exit the FaceTec UI with custom logic is not allowed.
    func onCatastrophicNetworkError(sessionRequestCallback: FaceTecSessionRequestProcessorCallback) {
        sessionRequestCallback.abortOnCatastrophicError();
    }
    
    // The onFaceTecExit API is the method called when the FaceTec SDK completes or cancels.
    // For demonstration purposes, we are handling next steps in the SampleAppViewController.
    func onFaceTecExit(sessionResult: FaceTecSessionResult) {
        DispatchQueue.main.async {
            SampleAppViewController.demonstrateHandlingFaceTecExit(sessionResult.sessionStatus)
        }
    }
}
