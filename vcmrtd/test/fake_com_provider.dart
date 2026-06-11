// Shared test helpers: a scripted fake ComProvider that drives the ICC/MrtdApi
// chain with canned ResponseAPDUs. Used by mrtd_api / data_group_reader /
// pace flow tests. Not a test file itself (no top-level main with tests).
import 'dart:typed_data';

import 'package:logging/logging.dart';
import 'package:vcmrtd/src/com/com_provider.dart';

/// A single scripted exchange. If [match] is provided it is asserted against
/// the outgoing command bytes (hex, upper-case) before [response] is returned.
class Exchange {
  final String? matchHex;
  final Uint8List response;
  Exchange(this.response, {this.matchHex});
}

/// Fake ComProvider that returns queued responses in order.
///
/// Each call to [transceive] pops the next queued response. The raw command
/// bytes sent are recorded in [sent] for assertions. When the queue is empty
/// it either throws or returns a default success, controlled by
/// [throwWhenEmpty].
class FakeComProvider extends ComProvider {
  final List<Uint8List> _responses;
  final List<Uint8List> sent = [];
  bool connected = false;
  bool throwWhenEmpty;
  int connectCount = 0;
  int disconnectCount = 0;

  FakeComProvider(List<Uint8List> responses, {this.throwWhenEmpty = true})
    : _responses = List.of(responses),
      super(Logger('FakeComProvider'));

  /// Convenience constructor from a list of hex strings.
  factory FakeComProvider.fromHex(List<String> hexResponses, {bool throwWhenEmpty = true}) {
    return FakeComProvider(hexResponses.map((h) => _hexToBytes(h)).toList(), throwWhenEmpty: throwWhenEmpty);
  }

  int get remaining => _responses.length;

  @override
  Future<void> connect() async {
    connected = true;
    connectCount++;
  }

  @override
  Future<void> reconnect() async {
    connected = true;
  }

  @override
  Future<void> disconnect() async {
    connected = false;
    disconnectCount++;
  }

  @override
  bool isConnected() => connected;

  @override
  Future<Uint8List> transceive(final Uint8List data) async {
    sent.add(Uint8List.fromList(data));
    if (_responses.isEmpty) {
      if (throwWhenEmpty) {
        throw ComProviderError("FakeComProvider: no more queued responses for cmd=${_hex(data)}");
      }
      return _hexToBytes("9000");
    }
    return _responses.removeAt(0);
  }
}

String _hex(Uint8List b) => b.map((e) => e.toRadixString(16).padLeft(2, '0')).join();

Uint8List _hexToBytes(String hex) {
  final clean = hex.replaceAll(' ', '');
  final out = Uint8List(clean.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    out[i] = int.parse(clean.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}
