import Foundation
import UIKit
import Photos

class SampleAppOfficialIDPhotoView: UIView {
    let STANDARD_CONTENT_TRANSITION_TIME = 0.5;

    @IBOutlet var contentView: UIView!
    @IBOutlet weak var instructionView: UIView!
    @IBOutlet weak var instructionViewStackView: UIStackView!
    @IBOutlet weak var subinstructionViewStackView: UIStackView!
    @IBOutlet weak var resultView: UIView!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var cancelButtonTopLayout: NSLayoutConstraint!
    @IBOutlet weak var continueButton: UIButton!
    @IBOutlet weak var shareImageButton: UIButton!
    @IBOutlet weak var downloadImageButton: UIButton!
    @IBOutlet weak var resultImageView: UIImageView!
    
    weak var sampleAppVC: SampleAppViewController!
    static var latestOfficialIDPhoto: String = ""
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        loadFromNib()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        loadFromNib()
    }

    private func loadFromNib() {
        Bundle.main.loadNibNamed("OfficialIDPhoto", owner: self, options: nil)
        addSubview(contentView)
        contentView.frame = bounds
        contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        // Move the cancel button down and reduce spacing for smaller devices and devices without the top inset area
        if let window = UIApplication.shared.windows.first {
            let topInset = window.safeAreaInsets.top
            
            if (topInset < 20) {
                self.cancelButtonTopLayout.constant = -20
                self.instructionViewStackView.spacing = 20
                self.subinstructionViewStackView.spacing = 30
            }
        }
    }
    
    // Launch the Sample app's Official ID Photo view.
    static func launchSampleAppOfficialIDPhotoView(sampleAppViewController: SampleAppViewController, sampleAppView: UIView) {
        SampleAppViewController.sampleAppOfficialIDPhotoView = SampleAppOfficialIDPhotoView()
        SampleAppViewController.sampleAppOfficialIDPhotoView.sampleAppVC = sampleAppViewController
        SampleAppViewController.sampleAppOfficialIDPhotoView.translatesAutoresizingMaskIntoConstraints = false
        
        sampleAppView.addSubview(SampleAppViewController.sampleAppOfficialIDPhotoView)

        NSLayoutConstraint.activate([
            SampleAppViewController.sampleAppOfficialIDPhotoView.leadingAnchor.constraint(equalTo: sampleAppView.leadingAnchor),
            SampleAppViewController.sampleAppOfficialIDPhotoView.trailingAnchor.constraint(equalTo: sampleAppView.trailingAnchor),
            SampleAppViewController.sampleAppOfficialIDPhotoView.topAnchor.constraint(equalTo: sampleAppView.topAnchor),
            SampleAppViewController.sampleAppOfficialIDPhotoView.bottomAnchor.constraint(equalTo: sampleAppView.bottomAnchor)
        ])
        
        SampleAppViewController.sampleAppOfficialIDPhotoView.fadeInInstructionView()
    }
    
    // Close the Sample app's Official ID Photo view.
   static func dismissSampleAppOfficialIDPhotoView() {
        if SampleAppViewController.sampleAppOfficialIDPhotoView != nil {
            SampleAppViewController.sampleAppOfficialIDPhotoView.removeFromSuperview()
            SampleAppViewController.sampleAppOfficialIDPhotoView = nil
        }
    }
    
    static func handleSampleAppOfficialIDPhotoResult() {
        if !SampleAppOfficialIDPhotoView.latestOfficialIDPhoto.isEmpty {
            SampleAppViewController.sampleAppOfficialIDPhotoView.fadeInResultView()
        }
        else {
            dismissSampleAppOfficialIDPhotoView()
            SampleAppViewController.utils.displayStatus(statusString: "An issue occurred creating your Official ID Photo.")
            SampleAppViewController.utils.fadeInMainUI()
        }
    }
    
    // Exit the Official ID Photo view
    @IBAction func onCancelButtonPressed(_ sender: Any) {
        disableInterfaceButtons()
        fadeOutOfficialIDPhotoView(runnable: {
            SampleAppViewController.utils.fadeInMainUI()
        })
    }
    
    // Launch Official ID Photo session
    @IBAction func onContinueButtonPressed(_ sender: Any) {
        SampleAppOfficialIDPhotoView.latestOfficialIDPhoto = ""
        fadeOutOfficialIDPhotoView(runnable: {
            // Create and launch the View Controller for a Official ID Photo session
            let faceTecVC = self.sampleAppVC.sdkInstance!.startSecureOfficialIDPhotoCapture(with: SessionRequestProcessor())
            self.sampleAppVC.present(faceTecVC, animated: true, completion: nil)
        })
    }
    
    // Download the Official ID Photo to the device
    @IBAction func onDownloadImageButtonPressed(_ sender: Any) {
        if let image = resultImageView.image {
            downloadImageButton.isEnabled = false

            // Check for permission before downloading
            checkPhotoLibraryPermission { granted in
                if granted {
                    UIImageWriteToSavedPhotosAlbum(image, self, #selector(self.image(_:didFinishSavingWithError:contextInfo:)), nil)
                }
                else {
                    self.openDeviceSettingsForPermission()
                }
            }
        }
    }
    
    // Open the share menu to share the Official ID Photo to other apps
    @IBAction func onShareImageButtonPressed(_ sender: Any) {
        guard let image = self.resultImageView.image else { return }
        self.shareImageButton.isEnabled = false

        let filename = generateFileName()
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

        if let imageData = image.pngData() {
            do {
                try imageData.write(to: tempURL)

                let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
                
                if let popoverController = activityVC.popoverPresentationController {
                    popoverController.sourceView = shareImageButton
                    popoverController.sourceRect = shareImageButton.bounds
                }

                sampleAppVC.present(activityVC, animated: true) {
                    self.shareImageButton.isEnabled = true
                }
            }
            catch {
                print("Error writing image: \(error)")
                self.shareImageButton.isEnabled = true
            }
        }
        else {
            print("Could not convert image to PNG")
            self.shareImageButton.isEnabled = true
        }
    }
    
    // Signal that the image has been downloaded the device
    @objc func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        downloadImageButton.isEnabled = true
        
        let alert = UIAlertController(
            title: error == nil ? "" : "Error",
            message: error == nil ? "Official ID Photo Downloaded Successfully" : error?.localizedDescription,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        sampleAppVC.present(alert, animated: true)
    }
    
    // Fade out the Official ID Photo View before exiting
    func fadeOutOfficialIDPhotoView(runnable: (() -> ())? = nil) {
        DispatchQueue.main.async {
            self.disableInterfaceButtons()
            
            UIView.animate(withDuration: self.STANDARD_CONTENT_TRANSITION_TIME) {
                self.contentView.alpha = 0
                self.instructionView.alpha = 0
                self.resultView.alpha = 0
            } completion: { _ in
                if runnable != nil {
                    runnable!()
                }
            }
        }
    }
    
    
    // Show a screen with instructions to perform the session in the best lighting conditions
    func fadeInInstructionView() {
        DispatchQueue.main.async {
            self.disableInterfaceButtons()
            
            UIView.animate(withDuration: self.STANDARD_CONTENT_TRANSITION_TIME) {
                self.contentView.alpha = 1
                self.instructionView.alpha = 1
            } completion: { _ in
                self.continueButton.isEnabled = true
                self.cancelButton.isEnabled = true
            }
        }
    }

    // Show a screen with the Official ID Photo image and options to download or share the image
    func fadeInResultView() {
        DispatchQueue.main.async {
            self.disableInterfaceButtons()
            
            if !SampleAppOfficialIDPhotoView.latestOfficialIDPhoto.isEmpty {
                let imageData: Data = Data(base64Encoded: SampleAppOfficialIDPhotoView.latestOfficialIDPhoto)!
                self.resultImageView.image = UIImage.init(data: imageData)
            }
            
            UIView.animate(withDuration: self.STANDARD_CONTENT_TRANSITION_TIME) {
                self.contentView.alpha = 1
                self.resultView.alpha = 1
            } completion: { _ in
                self.cancelButton.isEnabled = true
                self.shareImageButton.isEnabled = true
                self.downloadImageButton.isEnabled = true
            }
        }
      
    }
    
    // Disable all buttons in the Official ID Photo view
    func disableInterfaceButtons() {
        DispatchQueue.main.async {
            self.cancelButton.isEnabled = false
            self.continueButton.isEnabled = false
            self.shareImageButton.isEnabled = false
            self.downloadImageButton.isEnabled = false
        }
    }
    
    func checkPhotoLibraryPermission(completion: @escaping (Bool) -> Void) {
        // In iOS 14 and up, we can just request the add only permission
        if #available(iOS 14, *) {
            let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
            handlePhotoPermissionStatus(status, request: {
                PHPhotoLibrary.requestAuthorization(for: .addOnly) { newStatus in
                    completion(newStatus == .authorized || newStatus == .limited)
                }
            }, completion: completion)
        }
        else {
            let status = PHPhotoLibrary.authorizationStatus()
            handlePhotoPermissionStatus(status, request: {
                PHPhotoLibrary.requestAuthorization { newStatus in
                    completion(newStatus == .authorized)
                }
            }, completion: completion)
        }
    }
    
    private func handlePhotoPermissionStatus(_ status: PHAuthorizationStatus, request: @escaping () -> Void, completion: @escaping (Bool) -> Void) {
        switch status {
        case .authorized, .limited:
            completion(true)
        case .notDetermined:
            request()
        case .denied, .restricted:
            completion(false)
        }
    }
    
    // Open the device settings to grant permission to download the Official ID Photo
    func openDeviceSettingsForPermission() {
        DispatchQueue.main.async {
            let alert = UIAlertController(
                title: "Photos Access Needed",
                message: "This app needs permission to save images to your photo library.",
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            alert.addAction(UIAlertAction(title: "Launch Settings", style: .default) { _ in
                if let url = URL(string: UIApplication.openSettingsURLString),
                   UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url)
                }
            })

            self.sampleAppVC.present(alert, animated: true, completion: nil)
            self.downloadImageButton.isEnabled = true
        }
    }
    
    func generateFileName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let date = formatter.string(from: Date())
        let uuid = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        let shortUUID = String(uuid.prefix(8))
        return "FaceTec_Generated_Official_ID_Photo_\(date)_\(shortUUID).png"
    }
}
