import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
    // Under the UIScene lifecycle the implicit engine is created by the scene, after
    // didFinishLaunchingWithOptions has already returned, so plugins are registered here
    // against that engine's registry instead of against the app delegate.
    func didInitializeImplicitFlutterEngine(_ engineBridge: any FlutterImplicitEngineBridge) {
        let registry = engineBridge.pluginRegistry
        GeneratedPluginRegistrant.register(with: registry)

        DeepLinkPlugin.register(with: registry.registrar(forPlugin: "DeepLinkPlugin")!)
        ProofingDeepLinkPlugin.register(with: registry.registrar(forPlugin: "ProofingDeepLinkPlugin")!)

        // Register image_channel for JP2 passport photo decoding (UIImage handles JPEG 2000 natively)
        ImageDecodeChannel.register(with: registry.registrar(forPlugin: "ImageDecodeChannel")!)
    }
}
