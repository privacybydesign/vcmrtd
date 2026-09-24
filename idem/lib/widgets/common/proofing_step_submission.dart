import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:idem/providers/proofing_session_provider.dart';
import 'package:idem/services/proofing_session_client.dart';

/// Sends one just-completed step's result to the pinned session right away
/// - not at the end of the whole verification - behind a blocking progress
/// dialog, offering a retry when it fails. Returns the server's response
/// (it decides what comes next), or null when the step wasn't stored: the
/// user gave up, or the server refused this device (handed over, expired,
/// already complete), in which case the coordinator ends the verification
/// with the matching message instead of a retry.
Future<ProofingStepResponse?> submitProofingStep(
  BuildContext context, {
  required ActiveProofingSession session,
  required String what,
  required Future<ProofingStepResponse> Function() submit,
}) async {
  final container = ProviderScope.containerOf(context);
  final navigator = Navigator.of(context, rootNavigator: true);
  while (true) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 20),
              Expanded(child: Text('Sending $what to ${session.info.relyingParty}...')),
            ],
          ),
        ),
      ),
    );
    try {
      final response = await submit();
      navigator.pop();
      return response;
    } catch (e) {
      navigator.pop();
      if (reportIfProofingAccessLost(container, session.ref, e)) return null;
      if (!context.mounted) return null;
      final retry = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Could not send'),
          content: Text('Sending $what to ${session.info.relyingParty} failed:\n\n$e'),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Retry')),
          ],
        ),
      );
      if (retry != true || !context.mounted) return null;
    }
  }
}
