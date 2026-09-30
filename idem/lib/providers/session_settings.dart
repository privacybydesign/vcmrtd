import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:idem/providers/active_authenticiation_provider.dart';
import 'package:idem/providers/face_engine_provider.dart';
import 'package:idem/providers/liveness_mode_provider.dart';
import 'package:idem/services/proofing_session_client.dart';
import 'package:idem/widgets/pages/face_verification_entry_screen.dart';

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
