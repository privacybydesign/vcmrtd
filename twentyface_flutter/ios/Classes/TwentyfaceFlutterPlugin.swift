import Flutter
import UIKit
import twentyface_objcxx_wrapper

public class TwentyfaceFlutterPlugin: NSObject, FlutterPlugin {
    private var bridge: TwentyfaceBridge?
    private let dispatchQueue = DispatchQueue(label: "nl.twentyface.flutter", qos: .userInitiated)

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "twentyface_flutter", binaryMessenger: registrar.messenger())
        let instance = TwentyfaceFlutterPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initialize":
            handleInitialize(call, result: result)
        case "getVersion":
            handleGetVersion(result: result)
        case "getModelVersion":
            handleGetModelVersion(result: result)
        case "getHardwareId":
            handleGetHardwareId(result: result)
        case "compareFaces":
            handleCompareFaces(call, result: result)
        case "detectFaces":
            handleDetectFaces(call, result: result)
        case "checkLiveness":
            handleCheckLiveness(call, result: result)
        case "dispose":
            handleDispose(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func handleInitialize(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        dispatchQueue.async { [weak self] in
            do {
                guard let args = call.arguments as? [String: Any],
                      let license = args["license"] as? String else {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "INVALID_ARGS", message: "License is required", details: nil))
                    }
                    return
                }

                let bridge = TwentyfaceBridge()

                // Copy models to internal storage
                bridge.modelAssetsToInternalWithOverwrite(false)

                // Set the license
                try bridge.setLicense(license)

                self?.bridge = bridge

                DispatchQueue.main.async {
                    result(nil)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "INIT_ERROR", message: error.localizedDescription, details: nil))
                }
            }
        }
    }

    private func handleGetVersion(result: @escaping FlutterResult) {
        guard let bridge = bridge else {
            result(FlutterError(code: "NOT_INITIALIZED", message: "SDK not initialized", details: nil))
            return
        }
        result(bridge.getVersion())
    }

    private func handleGetModelVersion(result: @escaping FlutterResult) {
        guard let bridge = bridge else {
            result(FlutterError(code: "NOT_INITIALIZED", message: "SDK not initialized", details: nil))
            return
        }
        result(bridge.getModelVersion())
    }

    private func handleGetHardwareId(result: @escaping FlutterResult) {
        dispatchQueue.async {
            do {
                // Create a temporary bridge just to get the hardware ID
                let tempBridge = TwentyfaceBridge()
                let hwid = try tempBridge.getHardwareID()
                DispatchQueue.main.async {
                    result(hwid)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "HWID_ERROR", message: error.localizedDescription, details: nil))
                }
            }
        }
    }

    private func handleCompareFaces(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        dispatchQueue.async { [weak self] in
            do {
                guard let self = self, let bridge = self.bridge else {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "NOT_INITIALIZED", message: "SDK not initialized", details: nil))
                    }
                    return
                }

                guard let args = call.arguments as? [String: Any],
                      let liveImageData = args["liveImage"] as? FlutterStandardTypedData,
                      let referenceImageData = args["referenceImage"] as? FlutterStandardTypedData else {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "INVALID_ARGS", message: "Images are required", details: nil))
                    }
                    return
                }

                let referenceImageType = args["referenceImageType"] as? String ?? "jpeg"
                let configMap = args["config"] as? [String: Any]

                // Decode live image (JPEG)
                guard let liveImage = UIImage(data: liveImageData.data) else {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "DECODE_ERROR", message: "Failed to decode live image", details: nil))
                    }
                    return
                }

                // Decode reference image (JPEG or JPEG2000)
                let referenceImage: UIImage
                if referenceImageType == "jpeg2000" {
                    guard let img = self.decodeJpeg2000(referenceImageData.data) else {
                        DispatchQueue.main.async {
                            result(FlutterError(code: "DECODE_ERROR", message: "Failed to decode JPEG2000 image", details: nil))
                        }
                        return
                    }
                    referenceImage = img
                } else {
                    guard let img = UIImage(data: referenceImageData.data) else {
                        DispatchQueue.main.async {
                            result(FlutterError(code: "DECODE_ERROR", message: "Failed to decode reference image", details: nil))
                        }
                        return
                    }
                    referenceImage = img
                }

                // Create configuration
                let config = self.createConfiguration(configMap)

                // Perform comparison
                let comparison = try bridge.compare(firstImage: liveImage, secondImage: referenceImage, configuration: config)

                // Convert to dictionary
                let resultDict = self.comparisonToDict(comparison)

                DispatchQueue.main.async {
                    result(resultDict)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "COMPARE_ERROR", message: error.localizedDescription, details: nil))
                }
            }
        }
    }

    private func handleDetectFaces(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        dispatchQueue.async { [weak self] in
            do {
                guard let self = self, let bridge = self.bridge else {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "NOT_INITIALIZED", message: "SDK not initialized", details: nil))
                    }
                    return
                }

                guard let args = call.arguments as? [String: Any],
                      let imageData = args["image"] as? FlutterStandardTypedData else {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "INVALID_ARGS", message: "Image is required", details: nil))
                    }
                    return
                }

                let configMap = args["config"] as? [String: Any]

                guard let image = UIImage(data: imageData.data) else {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "DECODE_ERROR", message: "Failed to decode image", details: nil))
                    }
                    return
                }

                let config = self.createConfiguration(configMap)
                let detections = try bridge.detectFaces(image: image, configuration: config)

                let resultList = detections.map { self.detectionToDict($0) }

                DispatchQueue.main.async {
                    result(resultList)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "DETECT_ERROR", message: error.localizedDescription, details: nil))
                }
            }
        }
    }

    private func handleCheckLiveness(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        dispatchQueue.async { [weak self] in
            do {
                guard let self = self, let bridge = self.bridge else {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "NOT_INITIALIZED", message: "SDK not initialized", details: nil))
                    }
                    return
                }

                guard let args = call.arguments as? [String: Any],
                      let imageData = args["image"] as? FlutterStandardTypedData else {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "INVALID_ARGS", message: "Image is required", details: nil))
                    }
                    return
                }

                let configMap = args["config"] as? [String: Any]

                guard let image = UIImage(data: imageData.data) else {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "DECODE_ERROR", message: "Failed to decode image", details: nil))
                    }
                    return
                }

                // Force passive liveness enabled
                var config = self.createConfiguration(configMap)
                config.passive_anti_spoofing = true

                let detections = try bridge.detectFaces(image: image, configuration: config)

                if detections.isEmpty {
                    DispatchQueue.main.async {
                        result([
                            "is_live": false,
                            "score": 0.0,
                            "status": self.statusToDict(wStatus())
                        ])
                    }
                    return
                }

                let detection = detections[0]
                let status = detection.status!
                let isLive = !status.passive_antispoofing_spoofed && !status.antispoofing_spoofed

                DispatchQueue.main.async {
                    result([
                        "is_live": isLive,
                        "score": detection.score?.doubleValue ?? 0.0,
                        "status": self.statusToDict(status)
                    ])
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "LIVENESS_ERROR", message: error.localizedDescription, details: nil))
                }
            }
        }
    }

    private func handleDispose(result: @escaping FlutterResult) {
        bridge = nil
        result(nil)
    }

    // MARK: - Helper Methods

    private func decodeJpeg2000(_ data: Data) -> UIImage? {
        // Use ImageIO to decode JPEG2000
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }

    private func createConfiguration(_ configMap: [String: Any]?) -> wConfiguration {
        let config = wConfiguration()

        if let map = configMap {
            if let enableLiveness = map["enable_passive_liveness"] as? Bool {
                config.passive_anti_spoofing = enableLiveness
            }
            if let threshold = map["liveness_threshold"] as? Double {
                config.passive_anti_spoofing_threshold = NSNumber(value: threshold)
            }
            if let maxHorizontal = map["max_horizontal_rotation"] as? Double {
                config.qc_max_horizontal_rotation = NSNumber(value: maxHorizontal)
            }
            if let maxVertical = map["max_vertical_rotation"] as? Double {
                config.qc_max_vertical_rotation = NSNumber(value: maxVertical)
            }
            if let minSharpness = map["min_sharpness"] as? Double {
                config.qc_min_sharpness = NSNumber(value: minSharpness)
            }
            if let maxExposure = map["max_exposure"] as? Double {
                config.qc_max_exposure = NSNumber(value: maxExposure)
            }
            if let detectClosestOnly = map["detect_closest_only"] as? Bool {
                config.detect_closest_only = detectClosestOnly
            }
        }

        return config
    }

    private func comparisonToDict(_ comparison: wComparison) -> [String: Any] {
        return [
            "match": comparison.match,
            "recognition_distance": comparison.recognition_distance?.doubleValue ?? -1.0,
            "status_image_1": statusToDict(comparison.status_image_1),
            "status_image_2": statusToDict(comparison.status_image_2)
        ]
    }

    private func detectionToDict(_ detection: wDetection) -> [String: Any] {
        let rectangle = detection.rectangle
        return [
            "id": detection.id?.intValue ?? 0,
            "score": detection.score?.doubleValue ?? 0.0,
            "rectangle": [
                "x": rectangle?.x()?.intValue ?? 0,
                "y": rectangle?.y()?.intValue ?? 0,
                "width": rectangle?.width()?.intValue ?? 0,
                "height": rectangle?.height()?.intValue ?? 0
            ],
            "status": statusToDict(detection.status),
            "pose": [
                "yaw": detection.pose?.yaw ?? 0.0,
                "pitch": detection.pose?.pitch ?? 0.0,
                "roll": detection.pose?.roll ?? 0.0
            ],
            "frame_width": detection.frame_width?.intValue ?? 0,
            "frame_height": detection.frame_height?.intValue ?? 0
        ]
    }

    private func statusToDict(_ status: wStatus?) -> [String: Bool] {
        guard let status = status else {
            return [
                "detection_too_small": false,
                "detection_score_too_low": false,
                "detection_outside_image": false,
                "detection_outside_depth_image": false,
                "detection_no_faces": true,
                "detection_too_many_faces": false,
                "qualitycheck_blurry": false,
                "qualitycheck_rotated": false,
                "qualitycheck_overexposed": false,
                "antispoofing_too_far": false,
                "antispoofing_spoofed": false,
                "passive_antispoofing_spoofed": false,
                "facevector_too_similar_in_db": false,
                "facevector_not_recognized": false,
                "facevector_failed_to_create": false,
                "is_overall_ok": false
            ]
        }

        return [
            "detection_too_small": status.detection_too_small,
            "detection_score_too_low": status.detection_score_too_low,
            "detection_outside_image": status.detection_outside_image,
            "detection_outside_depth_image": status.detection_outside_depth_image,
            "detection_no_faces": status.detection_no_faces,
            "detection_too_many_faces": status.detection_too_many_faces,
            "qualitycheck_blurry": status.qualitycheck_blurry,
            "qualitycheck_rotated": status.qualitycheck_rotated,
            "qualitycheck_overexposed": status.qualitycheck_overexposed,
            "antispoofing_too_far": status.antispoofing_too_far,
            "antispoofing_spoofed": status.antispoofing_spoofed,
            "passive_antispoofing_spoofed": status.passive_antispoofing_spoofed,
            "facevector_too_similar_in_db": status.facevector_too_similar_in_db,
            "facevector_not_recognized": status.facevector_not_recognized,
            "facevector_failed_to_create": status.facevector_failed_to_create,
            "is_overall_ok": status.is_overall_ok
        ]
    }
}
