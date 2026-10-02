import 'package:face_verification/face_verification.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idem/providers/active_authenticiation_provider.dart';
import 'package:idem/providers/face_engine_provider.dart';
import 'package:idem/providers/liveness_mode_provider.dart';
import 'package:idem/providers/session_settings.dart';
import 'package:idem/services/proofing_session_client.dart';

ProofingSessionInfo _info({List<String>? requiredChecks, String? faceProvider}) => ProofingSessionInfo(
  id: 'sess-1',
  relyingParty: 'Acme Corp',
  requestedAttributes: const [],
  expiresAt: DateTime.now().add(const Duration(minutes: 5)),
  requiredChecks: requiredChecks,
  faceProvider: faceProvider,
);

void main() {
  group('applyProofingSessionSettings', () {
    test('turns on the checks a substantial flow requires', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(faceEngineProvider.notifier).set(FaceEngineChoice.onDevice);

      applyProofingSessionSettings(
        container,
        _info(
          requiredChecks: const ['nfc.passive_auth', checkNfcChipAuth, 'face.match', checkFaceLiveness],
          faceProvider: faceProviderRegula,
        ),
      );

      expect(container.read(activeAuthenticationProvider), isTrue);
      expect(container.read(faceEngineProvider), FaceEngineChoice.regula);
      expect(container.read(livenessModeProvider), LivenessMode.active);
    });

    test('mirrors a flow without chip auth or liveness', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(activeAuthenticationProvider.notifier).set(true);
      container.read(livenessModeProvider.notifier).set(LivenessMode.active);

      applyProofingSessionSettings(
        container,
        _info(requiredChecks: const ['nfc.passive_auth', 'face.match'], faceProvider: faceProviderEngine),
      );

      expect(container.read(activeAuthenticationProvider), isFalse);
      expect(container.read(faceEngineProvider), FaceEngineChoice.onDevice);
      expect(container.read(livenessModeProvider), LivenessMode.passive);
    });

    test('leaves the settings alone for a server that does not say', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(faceEngineProvider.notifier).set(FaceEngineChoice.iris);

      applyProofingSessionSettings(container, _info());

      expect(container.read(activeAuthenticationProvider), isFalse);
      expect(container.read(faceEngineProvider), FaceEngineChoice.iris);
      expect(container.read(livenessModeProvider), LivenessMode.passive);
    });
  });

  group('UserSettingsSnapshot', () {
    test("restores the user's settings a session overwrote", () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(activeAuthenticationProvider.notifier).set(true);
      container.read(faceEngineProvider.notifier).set(FaceEngineChoice.iris);
      container.read(livenessModeProvider.notifier).set(LivenessMode.active);

      final snapshot = UserSettingsSnapshot.capture(container);
      applyProofingSessionSettings(
        container,
        _info(requiredChecks: const ['nfc.passive_auth', 'face.match'], faceProvider: faceProviderRegula),
      );
      expect(container.read(activeAuthenticationProvider), isFalse);
      expect(container.read(faceEngineProvider), FaceEngineChoice.regula);
      expect(container.read(livenessModeProvider), LivenessMode.passive);

      snapshot.restore(container);

      expect(container.read(activeAuthenticationProvider), isTrue);
      expect(container.read(faceEngineProvider), FaceEngineChoice.iris);
      expect(container.read(livenessModeProvider), LivenessMode.active);
    });
  });
}
