import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:idem/providers/proofing_session_provider.dart';
import 'package:idem/services/proofing_session_coordinator.dart';

/// Covers the whole app while it asks the server whether this device may
/// still continue the pinned verification after coming back to the
/// foreground (see [ProofingSessionCoordinator.appLifecycleChanged]), so
/// nothing - an MRZ scan, an NFC read - carries on before the server
/// confirms. Invisible without a pinned session: a session this app already
/// finished its part of doesn't block anything.
class ProofingSessionCheckOverlay extends ConsumerWidget {
  final ValueListenable<ProofingSessionCheck> check;

  /// Stops the verification when the user doesn't want to keep waiting for
  /// an unreachable server.
  final VoidCallback onAbandon;

  const ProofingSessionCheckOverlay({super.key, required this.check, required this.onAbandon});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pinned = ref.watch(activeProofingSessionProvider) != null;
    return ValueListenableBuilder<ProofingSessionCheck>(
      valueListenable: check,
      builder: (context, value, _) {
        if (!pinned || value == ProofingSessionCheck.idle) return const SizedBox.shrink();
        final unreachable = value == ProofingSessionCheck.unreachable;
        return Positioned.fill(
          child: Material(
            color: Colors.black54,
            child: Center(
              child: Card(
                margin: const EdgeInsets.all(32),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        unreachable
                            ? 'Can\'t reach the verification service. Retrying...'
                            : 'Checking your verification session...',
                        textAlign: TextAlign.center,
                      ),
                      if (unreachable) ...[
                        const SizedBox(height: 16),
                        TextButton(onPressed: onAbandon, child: const Text('Stop verification')),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
