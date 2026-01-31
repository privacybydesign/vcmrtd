import Foundation
import FaceTecSDK

// Sample class for handling networking calls needed in order for FaceTec to function correctly.
// In Your App, please use the networking constructs and protocols that meet your security requirements.
//
// Notes:
// - Adding additional logic to this code is not allowed.  Do not add any additional logic outside of what is demonstrated in this Sample.
// - Adding additional asynchronous calls to this code is not allowed.  Only make your own additional asynchronous calls once the FaceTec UI is closed.
// - Adding code that modifies any App UI (Yours or FaceTec's) is not allowed.  Only add code that modifies your own App UI once the FaceTec UI is closed.
class SampleAppNetworkingRequest: NSObject, URLSessionTaskDelegate {
    var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid

    let referencingProcessor: SessionRequestProcessor
    let sessionRequestCallback: FaceTecSessionRequestProcessorCallback
    var errorCount: Int = 0
    
    static let MAX_ERROR_RETRIES = 2
    
    init(referencingProcessor: SessionRequestProcessor, sessionRequestCallback: FaceTecSessionRequestProcessorCallback) {
        self.referencingProcessor = referencingProcessor
        self.sessionRequestCallback = sessionRequestCallback
        super.init()
    }
    
    func send(sessionRequestBlob: String) {
        //
        // Step 1: Construct the payload.
        //
        // - The payload contains the Session Request Blob
        // - Please see the notes below about correctly handling externalDatabaseRefID for certain call types.
        //
        var sessionRequestCallPayload: [String : Any] = [:]
        sessionRequestCallPayload["requestBlob"] = sessionRequestBlob
        
        
        // Please see extensive notes in SampleAppViewController for more details.
        // externalDatabaseRefID is included in FaceTec Device SDK Sample App Code for demonstration purposes.
        // In Your App, you will be setting and handling this in Your Webservice code.
        if  !SampleAppViewController.demonstrationExternalDatabaseRefID.isEmpty {
            sessionRequestCallPayload["externalDatabaseRefID"] = SampleAppViewController.demonstrationExternalDatabaseRefID
        }
        
        //
        // Step 2: Set up the networking request.
        //
        // - This Sample App demonstrates making calls to the FaceTec Testing API by default.
        // - In Your App, please use the webservice endpoint you have set up that accepts networking requests from Your App.
        // - In Your Webservice, build an endpoint that takes incoming requests, and forwards them to FaceTec Server.
        // - This code should never call your server directly. It should contact middleware you have created that forwards requests to your server.
        //
        var request = URLRequest(url: NSURL(string: Config.YOUR_API_OR_FACETEC_TESTING_API_ENDPOINT)! as URL)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Developer Note: This is ONLY needed for calls to the FaceTec Testing API.
        // You should remove this when using Your App connected to Your Webservice + FaceTec Server
        request.addValue(Config.DeviceKeyIdentifier, forHTTPHeaderField: "X-Device-Key")

        // Developer Note: This is ONLY needed for calls to the FaceTec Testing API.
        // You should remove this when using Your App connected to Your Webservice + FaceTec Server
        request.addValue(FaceTec.sdk.getTestingAPIHeader(), forHTTPHeaderField: "X-Testing-API-Header")

        request.httpBody = try! JSONSerialization.data(withJSONObject: sessionRequestCallPayload, options: JSONSerialization.WritingOptions(rawValue: 0))
        
        // Set the total time that a request can take (in seconds)
        let sessionConfiguration = URLSessionConfiguration.default
        sessionConfiguration.timeoutIntervalForResource = 120

        let session = URLSession(configuration: sessionConfiguration, delegate: self, delegateQueue: OperationQueue.main)
        
        // Begin a background task so iOS gives the app extra time to finish this network call if the app is
        // put to background
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "SampleAppNetworkingRequest") {
            UIApplication.shared.endBackgroundTask(self.backgroundTaskID)
            self.backgroundTaskID = .invalid
        }
        
        //
        // Step 3: Make the API Call, and handle the response.
        //
        // - Unless there is a networking error, or an error in your webservice or infrastructure, the Response Blob is retrieved and passed back into processResponse.
        // - For error cases, abortOnCatastrophicError is called as this would indicate a networking issue on the User device or network, or an error in Your Webservice.
        //
        doSessionRequestWithRetry(session: session, request: request, completionHandler: { data, response, error in
            // Ensure that the background task is ended when the session finishes
            defer {
                UIApplication.shared.endBackgroundTask(self.backgroundTaskID)
                self.backgroundTaskID = .invalid
            }
            
            //
            // Step 4:  Get the Response Blob and call processResponse on the Session Request Callback.
            //
            // - Call a convenience function that either gets a valid Response Blob, or handles the error and returns null.
            // - Checks for null, indicating an error was detected and handled.
            //
            let responseBlob: String = self.getResponseBlobOrHandleError(data: data)
            
            // If the responseBlob is empty, getResponseBlobOrHandleError will invoke onCatastrophicNetworkError()
            if !responseBlob.isEmpty {
                self.referencingProcessor.onResponseBlobReceived(responseBlob: responseBlob, sessionRequestCallback: self.sessionRequestCallback)
            }
        })
    }
    
    private func doSessionRequestWithRetry(session: URLSession, request: URLRequest, completionHandler: @escaping (Data?, URLResponse?, (any Error)?) -> Void) {
        let networkRequest = session.dataTask(with: request as URLRequest, completionHandler: { data, response, error in
            if (error != nil && self.errorCount < SampleAppNetworkingRequest.MAX_ERROR_RETRIES) {
                self.errorCount += 1;
                // After a delay, try again
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.doSessionRequestWithRetry(session: session, request: request, completionHandler: completionHandler)
                }
            }
            else {
                completionHandler(data, response, error)
            }
        })
        
        networkRequest.resume()
    }
    
    func getResponseBlobOrHandleError(data: Data?) -> String {
        guard let data = data else {
            // On catastrophic error, call the onCatastrophicNetworkError handler
            // This should never be called except when a hard server error occurs. For example the user loses network connectivity.
            // You may want to implement some sort of retry logic here
            logErrorAndCallAbortAndClose(errorDetail: "Exception raised while attempting HTTPS call.")
            return ""
        }
        
        guard let responseJSON = try? JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.allowFragments) as! [String: AnyObject] else {
            // Parsing the response into JSON failed --> You define your own API contracts
            // with yourself and may choose to do something different here based on the
            // error. Solid server-side code should ensure you don't get to this case.
            logErrorAndCallAbortAndClose(errorDetail: "JSON Parsing Failed.  This indicates an issue in your own webservice or API contracts.");
            return ""
        }
        
        // Developer Note:  This is a special case for Official ID Photo Mode.
        // To demonstrate behavior in the Sample App where the Official ID Photo is shown to the UI,
        // here we store that off if it exists for future code to handle.
        storeOfficialIDPhotoIfApplicable(responseJSON: responseJSON)
        
        guard let responseBlob = responseJSON["responseBlob"] as? String else {
            logErrorAndCallAbortAndClose(errorDetail: "API Response not successful.  Inspect network request and response for more details.");
            return ""
        }
        
        return responseBlob
    }
    
    func logErrorAndCallAbortAndClose(errorDetail: String) {
        print("Networking Exception raised while attempting HTTPS call. Details: " + errorDetail);
        self.referencingProcessor.onCatastrophicNetworkError(sessionRequestCallback: self.sessionRequestCallback)
    }
    
    func storeOfficialIDPhotoIfApplicable(responseJSON:  [String : AnyObject]) {
        // Retrieve the Official ID Photo if it exists in the response
        if let result = responseJSON["result"] as? [String: AnyObject] {
            if let officialIDPhoto = result["officialIDPhotoImage"] as? String {
                if !officialIDPhoto.isEmpty {
                    SampleAppOfficialIDPhotoView.latestOfficialIDPhoto = officialIDPhoto
                }
            }
        }
    }
    
    // Developer Note: With the Sample Networking library in this Sample App,
    // this code demonstrates getting the networking request progress and making
    // the appropriate call in the FaceTec Device SDK to update the upload progress.
    // This is how the FaceTec Upload Progress Bar gets changed.
    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        let uploadProgress: Float = Float(totalBytesSent) / Float(totalBytesExpectedToSend)
        self.referencingProcessor.onUploadProgress(progress: uploadProgress, sessionRequestCallback: self.sessionRequestCallback)
    }
}
