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

  /// When the app connected to this session (QR scanned, session fetched) —
  /// reported back as part of the submission's session metadata.
  final DateTime openedAt;

  const ActiveProofingSession({required this.ref, required this.info, required this.openedAt});
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

  void set(ActiveProofingSession? session) => state = session;

  /// Replaces the pinned session's state with the server's latest view of
  /// it, if [ref] is still the pinned session - the server, not the app,
  /// knows the current step.
  void updateInfo(ProofingSessionRef ref, ProofingSessionInfo info) {
    final current = state;
    if (current == null || current.ref.token != ref.token || current.ref.deviceToken != ref.deviceToken) return;
    state = ActiveProofingSession(ref: current.ref, info: info, openedAt: current.openedAt);
  }
}

final activeProofingSessionProvider = NotifierProvider<ActiveProofingSessionNotifier, ActiveProofingSession?>(
  ActiveProofingSessionNotifier.new,
);

/// Steps already reported started, keyed by session token, reset count and
/// step, so a route rebuilding (or the user going back and forth) doesn't
/// resend the same start. A relying-party reset bumps the reset count, so
/// every step is reported again after one.
final Set<String> _startedProofingSteps = {};

/// Reports that the user just began [step] of the pinned proofing session
/// (see [ProofingSessionClient.markStepStarted]): fire-and-forget, and a
/// no-op without a pinned session (a standalone scan into the local wallet)
/// or when the session's flow doesn't contain [step]. Any face step maps to
/// the server's flow's own face step, so [stepFaceVerification] covers them.
void markActiveProofingStepStarted(ProviderContainer container, String step) {
  final session = container.read(activeProofingSessionProvider);
  if (session == null) return;
  final wanted = step == stepFaceVerification
      ? stepsRequestAny(session.info.steps, [stepFaceVerification, stepSelfie, stepLiveness, stepFaceMatch])
      : stepsRequestAny(session.info.steps, [step]);
  if (!wanted) return;
  final key = '${session.ref.token}|${session.info.resetCount}|$step';
  if (!_startedProofingSteps.add(key)) return;
  container.read(proofingSessionClientProvider).markStepStarted(session.ref, step).catchError((Object e) {
    _startedProofingSteps.remove(key);
    // Refused because this device lost the session: stop the step.
    if (reportIfProofingAccessLost(container, session.ref, e)) return;
    // Otherwise only the audit trail is affected; the step itself carries on.
    debugPrint('[proofing] $e');
  });
}
