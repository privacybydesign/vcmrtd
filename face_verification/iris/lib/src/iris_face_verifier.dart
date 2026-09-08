import 'package:flutter/services.dart';

import 'iris_verification_result.dart';

/// Thin wrapper around the vendor Iris SDK's face-verification flow.
///
/// Unlike [face_verification]'s [FaceVerificationEngine] (headless — you feed
/// it camera frames and read an event stream), the Iris SDK owns its own
/// camera UI end to end: [verify] hands it a reference portrait and the SDK
/// presents a full-screen native flow, returning only the final outcome.
class IrisFaceVerifier {
  static const MethodChannel _channel = MethodChannel('face_verification_iris');

  /// The bundled Iris SDK's version string.
  Future<String> get sdkVersion async {
    final version = await _channel.invokeMethod<String>('version');
    return version ?? 'unknown';
  }

  /// Runs the Iris SDK's native face-verification flow against [portraitPng]
  /// (a PNG-encoded reference portrait, e.g. from the NFC chip's DG2 photo).
  ///
  /// Presents a full-screen native UI until the user completes, fails, or
  /// cancels the flow.
  Future<IrisVerificationResult> verify(Uint8List portraitPng) async {
    final raw = await _channel.invokeMethod<Map<Object?, Object?>>('verify', portraitPng);
    final outcomeName = raw?['outcome'] as String? ?? 'failed';
    final face = raw?['face'] as Uint8List?;
    final outcome = IrisVerificationOutcome.values.firstWhere(
      (o) => o.name == outcomeName,
      orElse: () => IrisVerificationOutcome.failed,
    );
    return IrisVerificationResult(outcome: outcome, face: face);
  }
}
