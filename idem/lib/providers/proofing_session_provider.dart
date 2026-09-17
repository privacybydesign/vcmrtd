import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:idem/services/proofing_session_client.dart';

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

class ActiveProofingSessionNotifier extends Notifier<ActiveProofingSession?> {
  @override
  ActiveProofingSession? build() => null;

  void set(ActiveProofingSession? session) => state = session;
}

final activeProofingSessionProvider = NotifierProvider<ActiveProofingSessionNotifier, ActiveProofingSession?>(
  ActiveProofingSessionNotifier.new,
);
