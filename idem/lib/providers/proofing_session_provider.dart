import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:idem/services/proofing_session_client.dart';
import 'package:idem/services/proofing_session_coordinator.dart';

/// A session handed off from a browser via QR/deep link, fetched and pinned
/// for the duration of one scan. Cleared once its result is submitted (or
/// the flow is abandoned) — see routing.dart's /qr_scanner route and
/// PassportDataScreen's proofing-session submit section.
class ActiveProofingSession {
  final ProofingSessionRef ref;
  final ProofingSessionInfo info;

  const ActiveProofingSession({required this.ref, required this.info});
}

final proofingSessionClientProvider = Provider((ref) => const ProofingSessionClient());

/// This device's access to the session it holds - claiming, listening,
/// lifecycle reporting. See [ProofingSessionCoordinator].
final proofingSessionCoordinatorProvider = Provider((ref) {
  final coordinator = ProofingSessionCoordinator(client: ref.read(proofingSessionClientProvider));
  ref.onDispose(coordinator.dispose);
  return coordinator;
});

/// Hands a refused session call to the coordinator when the refusal ends
/// the session (handed over, expired, complete, ...), so the app stops the
/// verification with the right message instead of offering a retry. Returns
/// whether it did.
bool reportIfProofingAccessLost(ProviderContainer container, ProofingSessionRef ref, Object error) {
  if (error is! ProofingSessionAccessException || !error.reason.endsSession) return false;
  container.read(proofingSessionCoordinatorProvider).reportAccessLost(ref, error.reason);
  return true;
}

class ActiveProofingSessionNotifier extends Notifier<ActiveProofingSession?> {
  @override
  ActiveProofingSession? build() => null;

  /// Steps already reported started, keyed by session token, reset count and
  /// step, so the user going back and forth doesn't resend the same start.
  /// Only kept for the pinned session: pinning another one (or none) starts
  /// over, and a relying-party reset bumps the reset count, so every step is
  /// reported again after one.
  final Set<String> _startedSteps = {};

  void set(ActiveProofingSession? session) {
    _startedSteps.clear();
    state = session;
  }

  /// Replaces the pinned session's state with the server's latest view of
  /// it, if [ref] is still the pinned session - the server, not the app,
  /// knows the current step.
  void updateInfo(ProofingSessionRef ref, ProofingSessionInfo info) {
    final current = state;
    if (current == null || !current.ref.sameAccess(ref)) return;
    state = ActiveProofingSession(ref: current.ref, info: info);
  }
}

final activeProofingSessionProvider = NotifierProvider<ActiveProofingSessionNotifier, ActiveProofingSession?>(
  ActiveProofingSessionNotifier.new,
);

/// Reports that the user just began [step] of the pinned proofing session
/// (see [ProofingSessionClient.markStepStarted]): fire-and-forget, and a
/// no-op without a pinned session (a standalone scan into the local wallet)
/// or when the session's flow doesn't contain [step]. Any face step maps to
/// the server's flow's own face step, so [stepFaceVerification] covers them.
void markActiveProofingStepStarted(ProviderContainer container, String step) {
  final session = container.read(activeProofingSessionProvider);
  if (session == null) return;
  final wanted = step == stepFaceVerification
      ? stepsRequestFace(session.info.steps)
      : stepsRequestAny(session.info.steps, [step]);
  if (!wanted) return;
  final started = container.read(activeProofingSessionProvider.notifier)._startedSteps;
  final key = '${session.ref.token}|${session.info.resetCount}|$step';
  if (!started.add(key)) return;
  container.read(proofingSessionClientProvider).markStepStarted(session.ref, step).catchError((Object e) {
    started.remove(key);
    // Refused because this device lost the session: stop the step.
    if (reportIfProofingAccessLost(container, session.ref, e)) return;
    // Otherwise only the audit trail is affected; the step itself carries on.
    debugPrint('[proofing] $e');
  });
}
