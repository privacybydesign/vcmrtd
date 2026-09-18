import 'package:face_verification/face_verification.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Liveness mode for the on-device (open source) face verification engine.
/// Not applicable to the Iris SDK, which runs its own native flow.
class LivenessModeNotifier extends Notifier<LivenessMode> {
  @override
  LivenessMode build() => LivenessMode.passive;

  void set(LivenessMode mode) => state = mode;
}

final livenessModeProvider = NotifierProvider<LivenessModeNotifier, LivenessMode>(LivenessModeNotifier.new);
