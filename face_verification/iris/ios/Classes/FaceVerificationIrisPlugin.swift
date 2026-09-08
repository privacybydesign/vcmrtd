import Flutter
import Iris
import UIKit

/// Flutter plugin bridging `IrisFaceVerifier` (Dart) to the Iris SDK.
public class FaceVerificationIrisPlugin: NSObject, FlutterPlugin {
    private let iris = Iris()

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "face_verification_iris", binaryMessenger: registrar.messenger())
        let instance = FaceVerificationIrisPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "version":
            result(iris.version())
        case "verify":
            verify(call, result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func verify(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        guard let portrait = (call.arguments as? FlutterStandardTypedData)?.data else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "Expected the portrait PNG bytes as the call argument", details: nil))
            return
        }
        guard let windowScene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
        else {
            result(FlutterError(code: "NO_WINDOW_SCENE", message: "No active UIWindowScene to present the Iris flow", details: nil))
            return
        }

        iris.startFaceVerification(
            in: windowScene,
            portrait: portrait,
            completion: { face in
                result(["outcome": "matched", "face": FlutterStandardTypedData(bytes: face)])
            },
            failure: {
                result(["outcome": "failed", "face": NSNull()])
            },
            cancellation: {
                result(["outcome": "cancelled", "face": NSNull()])
            }
        )
    }
}
