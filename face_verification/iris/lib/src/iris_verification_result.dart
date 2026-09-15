import 'dart:typed_data';

/// Outcome of a single Iris SDK face-verification session.
enum IrisVerificationOutcome { matched, failed, cancelled }

/// Result of [IrisFaceVerifier.verify].
class IrisVerificationResult {
  const IrisVerificationResult({required this.outcome, this.face});

  final IrisVerificationOutcome outcome;

  /// The captured live face crop, present only when [outcome] is
  /// [IrisVerificationOutcome.matched].
  final Uint8List? face;
}
