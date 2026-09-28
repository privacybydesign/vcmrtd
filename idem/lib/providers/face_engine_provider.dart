import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which face-verification engine to use: Regula (server-matched, the
/// default), on-device, or the vendor-hosted Iris SDK.
enum FaceEngineChoice { regula, onDevice, iris }

class FaceEngineNotifier extends Notifier<FaceEngineChoice> {
  @override
  FaceEngineChoice build() => FaceEngineChoice.regula;

  void set(FaceEngineChoice choice) => state = choice;
}

final faceEngineProvider = NotifierProvider<FaceEngineNotifier, FaceEngineChoice>(FaceEngineNotifier.new);
