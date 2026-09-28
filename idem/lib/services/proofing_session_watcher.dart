import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:idem/services/proofing_session_client.dart';

/// Something about the session this device holds that the app has to act
/// on - see ProofingSessionCoordinator, which funnels every source of these
/// (this watcher, the resume check, a refused step submission) into one
/// stream for main.dart's VcMrtdApp.
sealed class ProofingSessionEvent {
  /// The session and device credential the event is about, so a late event
  /// for a session the app already let go of can be told apart.
  final ProofingSessionRef ref;
  const ProofingSessionEvent(this.ref);
}

/// The server's view of the session changed (a step landed, the other
/// device did something, the device state was stamped).
class ProofingSessionUpdated extends ProofingSessionEvent {
  final ProofingSessionInfo info;
  const ProofingSessionUpdated(super.ref, this.info);
}

/// The relying party reset the session: every step collected so far is
/// gone server-side, so the app has to start over too.
class ProofingSessionWasReset extends ProofingSessionEvent {
  final ProofingSessionInfo info;
  const ProofingSessionWasReset(super.ref, this.info);
}

/// This device may no longer act on the session: handed over to another
/// device, expired, cancelled. Ends the local verification.
class ProofingSessionAccessLost extends ProofingSessionEvent {
  final ProofingAccessDenial reason;
  const ProofingSessionAccessLost(super.ref, this.reason);
}

/// The session was submitted and has its outcome - by this app, or by the
/// other device holding a slot. Ends the local verification as done, not
/// as a failure.
class ProofingSessionCompleted extends ProofingSessionEvent {
  const ProofingSessionCompleted(super.ref);
}

/// Listens to one identity-proofing session through the backend (see
/// [ProofingSessionClient.waitForChange]) and passes on only what the app
/// must act on: a reset by the relying party, this device losing access
/// (another device took the session over, or it expired), and fresh server
/// state. The app never talks to the web app directly - both only see the
/// session, and this is how the app notices what the other side did to it.
///
/// Watches from the moment the session is claimed until the server reports
/// it finished (submitted, or [proofingSessionFinished]) or this device
/// loses access -
/// deliberately *not* just while it's pinned in activeProofingSessionProvider:
/// after handing face verification off to the browser the app unpins the
/// session, but a reset during that browser step still has to bring the
/// user back here to redo the document/NFC steps.
class ProofingSessionWatcher {
  final ProofingSessionClient client;
  final ProofingSessionRef ref;
  final ProofingSessionInfo initial;
  final void Function(ProofingSessionEvent event) onEvent;

  /// How long to wait before re-polling after a failed request (network
  /// hiccup, server restart), so a flaky connection doesn't spin.
  final Duration retryDelay;

  bool _stopped = false;
  bool _paused = false;
  Completer<void>? _resumed;
  http.Client? _inflight;

  ProofingSessionWatcher({
    required this.client,
    required this.ref,
    required this.initial,
    required this.onEvent,
    this.retryDelay = const Duration(seconds: 3),
  });

  /// Starts watching in the background; the returned future completes when
  /// watching ends (finished, access lost, or [stop]). A server without
  /// change tracking (no [ProofingSessionInfo.changeKey]) has nothing to
  /// watch for, and polling it with an empty key would return immediately
  /// every time.
  Future<void> start() async {
    if (initial.changeKey == null) return;
    var current = initial;
    while (!_stopped && current.lifecycle != proofingLifecycleComplete && !proofingSessionFinished(current.status)) {
      if (_paused) {
        await (_resumed ??= Completer<void>()).future;
        continue;
      }
      final httpClient = http.Client();
      _inflight = httpClient;
      try {
        final next = await client.waitForChange(ref, current.changeKey!, httpClient: httpClient);
        if (_stopped) return;
        final lost = next.accessLost;
        if (lost != null) {
          onEvent(ProofingSessionAccessLost(ref, lost));
          return;
        }
        // Submitted (on either device): nothing left to watch for.
        if (next.lifecycle == proofingLifecycleComplete) {
          onEvent(ProofingSessionCompleted(ref));
          return;
        }
        if (next.resetCount > current.resetCount) {
          onEvent(ProofingSessionWasReset(ref, next));
        } else if (next.changeKey != current.changeKey) {
          onEvent(ProofingSessionUpdated(ref, next));
        }
        current = next;
        if (current.changeKey == null) return;
      } on ProofingSessionAccessException catch (e) {
        if (!_stopped && e.reason.endsSession) onEvent(ProofingSessionAccessLost(ref, e.reason));
        return;
      } catch (_) {
        if (_paused) continue; // pause() aborted the wait on purpose
        await Future.delayed(retryDelay);
      } finally {
        httpClient.close();
        if (identical(_inflight, httpClient)) _inflight = null;
      }
    }
  }

  /// The app went to the background: hang up the open long-poll right away.
  /// Closing it is local, so it happens even when iOS suspends the app a
  /// moment later - and the server takes the dropped connection as the sign
  /// this device is gone, which an "inactive" report sent from a suspending
  /// app often never delivers. No polling until [resume].
  void pause() {
    _paused = true;
    _inflight?.close();
  }

  /// Back in the foreground: listen again.
  void resume() {
    _paused = false;
    _resumed?.complete();
    _resumed = null;
  }

  void stop() {
    _stopped = true;
    resume();
  }
}
