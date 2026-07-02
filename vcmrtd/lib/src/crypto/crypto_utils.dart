//  Copyright © 2020 ZeroPass. All rights reserved.
import 'dart:math';
import 'dart:typed_data';

Uint8List randomBytes(int length) {
  final random = Random.secure();
  var intBytes = List<int>.generate(length, (i) => random.nextInt(256));
  return Uint8List.fromList(intBytes);
}

/// Compares two byte sequences [a] and [b] for equality in constant time.
///
/// Unlike early-exit comparisons (e.g. `ListEquality().equals`), this does not
/// short-circuit on the first differing byte, so its running time does not
/// depend on how many leading bytes match. Use it for secret-dependent values
/// such as MACs and authentication tokens to avoid leaking information through
/// timing side channels.
///
/// A length mismatch always compares as unequal and is folded into the
/// accumulator, so callers cannot distinguish "wrong length" from "wrong
/// content" by timing.
bool constantTimeEqual(Uint8List a, Uint8List b) {
  var diff = a.length ^ b.length;
  final n = a.length < b.length ? a.length : b.length;
  for (var i = 0; i < n; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}
