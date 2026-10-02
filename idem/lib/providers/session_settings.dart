import 'package:face_verification/face_verification.dart' show LivenessMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:idem/providers/active_authenticiation_provider.dart';
import 'package:idem/providers/face_engine_provider.dart';
import 'package:idem/providers/liveness_mode_provider.dart';
import 'package:idem/services/proofing_session_client.dart';
import 'package:idem/widgets/pages/face_verification_entry_screen.dart';

/// The user's own settings from before a proofing session overwrote them
/// (see [applyProofingSessionSettings]), put back once it ends, so a
/// session's checks don't carry over into later scans.
class UserSettingsSnapshot {
  UserSettingsSnapshot.capture(ProviderContainer container)
    : _activeAuthentication = container.read(activeAuthenticationProvider),
      _faceEngine = container.read(faceEngineProvider),
      _livenessMode = container.read(livenessModeProvider);

  final bool _activeAuthentication;
  final FaceEngineChoice _faceEngine;
  final LivenessMode _livenessMode;

  void restore(ProviderContainer container) {
    container.read(activeAuthenticationProvider.notifier).set(_activeAuthentication);
    container.read(faceEngineProvider.notifier).set(_faceEngine);
    container.read(livenessModeProvider.notifier).set(_livenessMode);
  }
}

/// Writes a pinned proofing session's flow into the settings, so Settings
/// shows what the session actually runs: Active Authentication on when the
/// flow requires nfc.chip_auth, the face engine the flow scores with, and
/// active liveness when it requires face.liveness. A server that doesn't list
/// its checks or face provider leaves those settings as they are.
void applyProofingSessionSettings(ProviderContainer container, ProofingSessionInfo info) {
  if (info.requiredChecks != null) {
    container.read(activeAuthenticationProvider.notifier).set(info.requiresActiveAuthentication);
  }
  container
      .read(faceEngineProvider.notifier)
      .set(FaceVerificationEntryScreen.sessionEngine(container.read(faceEngineProvider), info));
  container
      .read(livenessModeProvider.notifier)
      .set(FaceVerificationEntryScreen.sessionLivenessMode(container.read(livenessModeProvider), info));
}
