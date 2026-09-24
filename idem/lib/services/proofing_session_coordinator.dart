import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:idem/services/proofing_session_client.dart';
import 'package:idem/services/proofing_session_watcher.dart';

/// Where the resume check stands - see [ProofingSessionCoordinator.check].
enum ProofingSessionCheck {
  /// Nothing to check, or the server confirmed this device may continue.
  idle,

  /// The app just came back to the foreground and is asking the server
  /// whether this device may still continue. The UI blocks until it knows.
  checking,

  /// Same, but the server can't be reached; retrying.
  unreachable,
}

/// Owns this device's access to the one identity-proofing session it holds.
/// The backend is the source of truth: the app never assumes its own
/// progress is current, and never continues without the server saying so.
///
///  * [connect] claims a session from a scanned QR / tapped deep link -
///    a grant token: the empty native slot's claim token, or a handover
///    taking the session over from another device. Neither creates a
///    session.
///  * [track] starts the [ProofingSessionWatcher] (the listener) for the
///    claimed session; everything it notices arrives on [events].
///  * [appLifecycleChanged] tells the server when the app goes to the
///    background (inactive) or comes back (active), and on coming back
///    blocks ([check]) until the server confirms this device may continue.
///  * [reportAccessLost] lets any other caller (a refused step submission)
///    end the session the same way, and [reportCompleted] ends it as done
///    once submitted. After that nothing is listened to or reported - the
///    server refuses device state for a submitted session anyway.
///
/// main.dart's VcMrtdApp is the only listener on [events]: it re-pins,
/// restarts the flow or ends the verification with a message. Nothing is
/// persisted on the device - if the OS kills the app, the server notices
/// from the device's last activity and the web app hands the session back
/// with a new handover QR.
class ProofingSessionCoordinator {
  final ProofingSessionClient client;
  final Duration retryDelay;

  ProofingSessionCoordinator({required this.client, this.retryDelay = const Duration(seconds: 3)});

  final _events = StreamController<ProofingSessionEvent>.broadcast();
  final ValueNotifier<ProofingSessionCheck> check = ValueNotifier(ProofingSessionCheck.idle);

  /// Device credentials this app obtained, by session, so a late loss
  /// report for a session already let go of can be told apart.
  final Map<String, ProofingSessionRef> _claimed = {};

  /// The same credentials by the grant token that obtained them, so scanning
  /// the same (now used) QR again reuses them rather than being refused.
  final Map<String, ProofingSessionRef> _claimedByGrant = {};

  ProofingSessionWatcher? _watcher;
  ProofingSessionRef? _held;
  bool _backgrounded = false;
  int _resumeCheck = 0;

  Stream<ProofingSessionEvent> get events => _events.stream;

  /// The session this device currently holds (claimed and not lost), if any.
  ProofingSessionRef? get held => _held;

  static String _key(String apiBase, String token) => '$apiBase|$token';

  /// Claims the session [link] points at and returns this device's
  /// credential plus the session's current state. Throws
  /// [ProofingSessionAccessException] when the server refuses (expired, a
  /// used or expired handover token, a session already held by another
  /// device).
  Future<ProofingSessionClaim> connect(ProofingSessionLink link) async {
    final claim = switch (link) {
      ProofingHandoverLink() => await _claimOrReuse(link),
      ProofingSessionTokenLink() => throw const ProofingSessionAccessException(
        ProofingAccessDenial.claimTokenRequired,
        0,
      ),
      ProofingBrowserHandoverLink() => throw const ProofingSessionAccessException(
        ProofingAccessDenial.browserHandover,
        0,
      ),
    };
    final held = _held;
    if (held != null && held.token == claim.ref.token && held.deviceToken != claim.ref.deviceToken) {
      // This app took its own session over (e.g. scanned the browser's
      // handover QR after coming back from the background): the old
      // credential was just revoked, which is not a loss worth reporting.
      _watcher?.stop();
      _watcher = null;
      _held = null;
    }
    _claimed[_key(claim.ref.apiBase, claim.ref.token)] = claim.ref;
    _claimedByGrant[_key(link.apiBase, link.handoverToken)] = claim.ref;
    final lost = claim.info.accessLost;
    if (lost != null) {
      _forget(claim.ref);
      throw ProofingSessionAccessException(lost, 200);
    }
    return claim;
  }

  Future<ProofingSessionClaim> _claimOrReuse(ProofingHandoverLink link) async {
    final known = _claimedByGrant[_key(link.apiBase, link.handoverToken)];
    if (known == null || !_claimed.containsKey(_key(known.apiBase, known.token))) return client.claimHandover(link);
    try {
      return ProofingSessionClaim(ref: known, info: await client.fetchSession(known));
    } on ProofingSessionAccessException catch (e) {
      if (e.reason.endsSession) _forget(known);
      rethrow;
    }
  }

  /// Starts listening to the session [ref] (which must carry its device
  /// credential); stops listening to any previous one. A no-op for the
  /// session already being listened to.
  void track(ProofingSessionRef ref, ProofingSessionInfo info) {
    if (_held != null && _held!.token == ref.token && _held!.deviceToken == ref.deviceToken) return;
    _watcher?.stop();
    _held = ref;
    final watcher = ProofingSessionWatcher(
      client: client,
      ref: ref,
      initial: info,
      onEvent: _emit,
      retryDelay: retryDelay,
    );
    _watcher = watcher;
    watcher.start();
  }

  /// This device lost access to the session [ref]: stop listening, drop the
  /// credential, and tell the app to end the verification. Safe to call
  /// more than once for the same loss; only the first one is passed on.
  void reportAccessLost(ProofingSessionRef ref, ProofingAccessDenial reason) =>
      _emit(ProofingSessionAccessLost(ref, reason));

  /// The session [ref] was submitted and has its outcome (this app's own
  /// submit, or the other device's): stop listening and reporting device
  /// state, drop the credential, and tell the app the verification is done.
  /// Safe to call more than once; only the first one is passed on.
  void reportCompleted(ProofingSessionRef ref) => _emit(ProofingSessionCompleted(ref));

  /// The user abandoned the session (e.g. from the resume check): stop
  /// listening and drop the credential, without a message.
  void release() {
    final held = _held;
    if (held != null) _forget(held);
    check.value = ProofingSessionCheck.idle;
  }

  void _emit(ProofingSessionEvent event) {
    // Refused as already complete (409 session_complete - e.g. a device
    // state report racing the other device's submit): the session finished,
    // it wasn't taken away.
    if (event is ProofingSessionAccessLost && event.reason == ProofingAccessDenial.complete) {
      event = ProofingSessionCompleted(event.ref);
    }
    final held = _held;
    final isHeld = held != null && held.token == event.ref.token && held.deviceToken == event.ref.deviceToken;
    if (event is ProofingSessionAccessLost || event is ProofingSessionCompleted) {
      // A second loss/completion for the same credential (the watcher and a
      // submission noticing the same thing), or one for a credential this
      // app already replaced with a newer one, has nothing left to end.
      final known = _claimed[_key(event.ref.apiBase, event.ref.token)];
      if (!isHeld && known?.deviceToken != event.ref.deviceToken) return;
      _forget(event.ref);
      check.value = ProofingSessionCheck.idle;
    } else if (!isHeld) {
      return;
    }
    _events.add(event);
  }

  /// Drops [ref]'s credential - only that one: a newer credential this app
  /// holds for the same session stays.
  void _forget(ProofingSessionRef ref) {
    bool same(ProofingSessionRef known) => known.token == ref.token && known.deviceToken == ref.deviceToken;
    final key = _key(ref.apiBase, ref.token);
    if (_claimed[key] case final known? when same(known)) _claimed.remove(key);
    _claimedByGrant.removeWhere((_, known) => same(known));
    if (_held case final held? when same(held)) {
      _watcher?.stop();
      _watcher = null;
      _held = null;
    }
  }

  /// Feeds Flutter's app lifecycle in. Only a real trip to the background
  /// (hidden/paused) counts - not `inactive`, which iOS also reports while
  /// its own NFC sheet or a permission dialog covers the app mid-step.
  void appLifecycleChanged(AppLifecycleState state) {
    switch (state) {
      // detached: iOS terminating the app (swiped away) - best effort, the
      // server also notices the dropped connection.
      case AppLifecycleState.hidden || AppLifecycleState.paused || AppLifecycleState.detached:
        if (_backgrounded) return;
        _backgrounded = true;
        _watcher?.pause();
        _reportBackgrounded();
      case AppLifecycleState.resumed:
        if (!_backgrounded) return;
        _backgrounded = false;
        _watcher?.resume();
        _confirmOnResume();
      case AppLifecycleState.inactive:
        break;
    }
  }

  /// Best effort: the app may be suspended before this lands, which is why
  /// the server also falls back on the device's last activity.
  void _reportBackgrounded() {
    final ref = _held;
    if (ref == null) return;
    client
        .reportDeviceState(ref, active: false)
        .then<void>(
          (info) {
            final lost = info.accessLost;
            if (lost != null) {
              reportAccessLost(ref, lost);
            } else if (info.lifecycle == proofingLifecycleComplete) {
              reportCompleted(ref);
            }
          },
          onError: (Object e) {
            if (e is ProofingSessionAccessException && e.reason.endsSession) reportAccessLost(ref, e.reason);
          },
        );
  }

  /// Back in the foreground: nothing continues until the server confirms
  /// this device still holds a valid session. Retries while the server
  /// can't be reached, since continuing unconfirmed is exactly what must
  /// not happen.
  Future<void> _confirmOnResume() async {
    final ref = _held;
    if (ref == null) return;
    final run = ++_resumeCheck;
    check.value = ProofingSessionCheck.checking;
    while (run == _resumeCheck && _held == ref && !_backgrounded) {
      try {
        final info = await client.reportDeviceState(ref, active: true);
        final lost = info.accessLost;
        if (lost != null) {
          reportAccessLost(ref, lost);
        } else if (info.lifecycle == proofingLifecycleComplete) {
          // Submitted on the other device while this one was away.
          reportCompleted(ref);
        } else {
          _emit(ProofingSessionUpdated(ref, info));
        }
        break;
      } on ProofingSessionAccessException catch (e) {
        if (e.reason.endsSession) {
          reportAccessLost(ref, e.reason);
          break;
        }
        check.value = ProofingSessionCheck.unreachable;
      } catch (_) {
        check.value = ProofingSessionCheck.unreachable;
      }
      await Future.delayed(retryDelay);
    }
    if (run == _resumeCheck) check.value = ProofingSessionCheck.idle;
  }

  void dispose() {
    _watcher?.stop();
    _events.close();
    check.dispose();
  }
}
