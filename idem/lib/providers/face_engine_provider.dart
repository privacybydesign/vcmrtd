import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which face-verification engine to use: on-device or the vendor-hosted Iris SDK.
enum FaceEngineChoice { onDevice, iris }

class FaceEngineNotifier extends Notifier<FaceEngineChoice> {
  @override
  FaceEngineChoice build() => FaceEngineChoice.onDevice;

  void set(FaceEngineChoice choice) => state = choice;
}

final faceEngineProvider = NotifierProvider<FaceEngineNotifier, FaceEngineChoice>(FaceEngineNotifier.new);
