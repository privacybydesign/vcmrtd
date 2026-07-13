// Unit tests for DocumentReader (lib/src/document_reader.dart).
//
// DocumentReader is a Riverpod Notifier whose collaborators (DocumentParser,
// DataGroupReader, NfcProvider, config) are all injected via the constructor.
// Every method in Dart is virtual, so we drive the reader deterministically by
// subclassing each collaborator and overriding its methods with configurable
// fakes/queues. No real NFC hardware or plugin is required.
//
// NfcProvider.nfcStatus throws a MissingPluginException under `flutter test`;
// checkNfcAvailability() swallows it, so state stays DocumentReaderPending.
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vcmrtd/extensions.dart';
import 'package:vcmrtd/vcmrtd.dart';
import 'package:vcmrtd/internal.dart';
import 'package:vcmrtd/src/parsers/document_parser.dart';

import 'fake_com_provider.dart';

// --------------------------------------------------------------------------
// Fakes
// --------------------------------------------------------------------------

/// NfcProvider with all hardware-touching methods overridden to no-ops that
/// track call counts and connection state.
class FakeNfcProvider extends NfcProvider {
  bool _connected;
  int connectCount = 0;
  int disconnectCount = 0;
  int reconnectCount = 0;
  int forceCleanupCount = 0;
  final List<String> iosMessages = [];

  /// Ordered log of lifecycle calls ('forceCleanup' / 'connect' / 'disconnect').
  /// Lets tests assert the plugin session is cleaned up *before* polling.
  final List<String> events = [];

  FakeNfcProvider({bool connected = false}) : _connected = connected;

  @override
  Future<void> connect({Duration? timeout, String iosAlertMessage = ""}) async {
    connectCount++;
    events.add('connect');
    _connected = true;
  }

  @override
  Future<void> disconnect({String? iosAlertMessage, String? iosErrorMessage}) async {
    disconnectCount++;
    events.add('disconnect');
    _connected = false;
  }

  @override
  Future<void> reconnect() async {
    reconnectCount++;
  }

  @override
  Future<void> forceCleanup() async {
    forceCleanupCount++;
    events.add('forceCleanup');
  }

  @override
  bool isConnected() => _connected;

  @override
  Future<void> setIosAlertMessage(String message) async {
    iosMessages.add(message);
  }
}

/// A queued action: either return canned bytes or throw a supplied error.
class _Step {
  final Uint8List? bytes;
  final Object? error;
  _Step.fail(this.error) : bytes = null;
}

/// DataGroupReader whose every chip-touching method is driven by per-method
/// queues. If a queue is empty for a method, it returns 8 canned bytes.
class FakeDataGroupReader extends DataGroupReader {
  final Map<String, List<_Step>> steps;
  final List<String> calls = [];
  int resetCount = 0;

  /// Optional per-method hook invoked at the start of a read. Lets a test flip
  /// cancellation deterministically mid-flow.
  final Map<String, void Function()> onRead = {};

  // startSession / startSessionPACE behaviour
  Object? startSessionError;
  Object? startSessionPaceError;
  int startSessionCount = 0;
  int startSessionPaceCount = 0;

  FakeDataGroupReader(ComProvider com, {Map<String, List<_Step>>? steps})
    : steps = steps ?? {},
      super(com, "A0000002471001".parseHex());

  Uint8List _next(String name) {
    calls.add(name);
    onRead[name]?.call();
    final q = steps[name];
    if (q != null && q.isNotEmpty) {
      final s = q.removeAt(0);
      if (s.error != null) throw s.error!;
      return s.bytes ?? Uint8List.fromList(const [1, 2, 3, 4, 5, 6, 7, 8]);
    }
    return Uint8List.fromList(const [1, 2, 3, 4, 5, 6, 7, 8]);
  }

  @override
  void reset() {
    resetCount++;
  }

  @override
  Future<void> startSession() async {
    startSessionCount++;
    calls.add('startSession');
    if (startSessionError != null) throw startSessionError!;
  }

  @override
  Future<void> startSessionPACE(EfCardAccess efCardAccess) async {
    startSessionPaceCount++;
    calls.add('startSessionPACE');
    if (startSessionPaceError != null) throw startSessionPaceError!;
  }

  @override
  Future<Uint8List> readEfCardAccess() async => _next('CardAccess');
  @override
  Future<Uint8List> readEfCOM() async => _next('COM');
  @override
  Future<Uint8List> readEfSOD() async => _next('SOD');
  @override
  Future<Uint8List> activeAuthenticate(Uint8List challenge) async => _next('AA');

  @override
  Future<Uint8List> readDG1() async => _next('DG1');
  @override
  Future<Uint8List> readDG2() async => _next('DG2');
  @override
  Future<Uint8List> readDG3() async => _next('DG3');
  @override
  Future<Uint8List> readDG4() async => _next('DG4');
  @override
  Future<Uint8List> readDG5() async => _next('DG5');
  @override
  Future<Uint8List> readDG6() async => _next('DG6');
  @override
  Future<Uint8List> readDG7() async => _next('DG7');
  @override
  Future<Uint8List> readDG8() async => _next('DG8');
  @override
  Future<Uint8List> readDG9() async => _next('DG9');
  @override
  Future<Uint8List> readDG10() async => _next('DG10');
  @override
  Future<Uint8List> readDG11() async => _next('DG11');
  @override
  Future<Uint8List> readDG12() async => _next('DG12');
  @override
  Future<Uint8List> readDG13() async => _next('DG13');
  @override
  Future<Uint8List> readDG14() async => _next('DG14');
  @override
  Future<Uint8List> readDG15() async => _next('DG15');
  @override
  Future<Uint8List> readDG16() async => _next('DG16');
}

/// DocumentParser stub. Records parse calls, lets tests control which data
/// groups are "present", and can be told to throw on specific parse* calls.
class FakeDocumentParser extends DocumentParser<DocumentData> {
  final Set<DataGroups> present;
  final Set<DataGroups> throwOnParse;
  final List<String> parsed = [];
  bool throwOnEfCom = false;

  FakeDocumentParser({Set<DataGroups>? present, Set<DataGroups>? throwOnParse})
    : present = present ?? const {},
      throwOnParse = throwOnParse ?? const {};

  @override
  bool documentContainsDataGroup(DataGroups dg) => present.contains(dg);

  @override
  void parseEfCardAccess(Uint8List bytes) {
    parsed.add('CardAccess');
    // store a real (trivially-valid) EfCardAccess so the cardAccess getter works
    super.parseEfCardAccess("31143012060A04007F0007020204020202010202010D".parseHex());
  }

  @override
  void parseEfCOM(Uint8List bytes) {
    parsed.add('COM');
    if (throwOnEfCom) throw Exception('COM parse boom');
  }

  @override
  void parseEfSOD(Uint8List bytes) {
    parsed.add('SOD');
    super.parseEfSOD("7700".parseHex());
  }

  void _dg(DataGroups dg) {
    parsed.add(dg.getName());
    if (throwOnParse.contains(dg)) throw Exception('parse ${dg.getName()} boom');
  }

  @override
  void parseDG1(Uint8List b) => _dg(DataGroups.dg1);
  @override
  void parseDG2(Uint8List b) => _dg(DataGroups.dg2);
  @override
  void parseDG3(Uint8List b) => _dg(DataGroups.dg3);
  @override
  void parseDG4(Uint8List b) => _dg(DataGroups.dg4);
  @override
  void parseDG5(Uint8List b) => _dg(DataGroups.dg5);
  @override
  void parseDG6(Uint8List b) => _dg(DataGroups.dg6);
  @override
  void parseDG7(Uint8List b) => _dg(DataGroups.dg7);
  @override
  void parseDG8(Uint8List b) => _dg(DataGroups.dg8);
  @override
  void parseDG9(Uint8List b) => _dg(DataGroups.dg9);
  @override
  void parseDG10(Uint8List b) => _dg(DataGroups.dg10);
  @override
  void parseDG11(Uint8List b) => _dg(DataGroups.dg11);
  @override
  void parseDG12(Uint8List b) => _dg(DataGroups.dg12);
  @override
  void parseDG13(Uint8List b) => _dg(DataGroups.dg13);
  @override
  void parseDG14(Uint8List b) => _dg(DataGroups.dg14);
  @override
  void parseDG15(Uint8List b) => _dg(DataGroups.dg15);
  @override
  void parseDG16(Uint8List b) => _dg(DataGroups.dg16);

  @override
  DocumentData createDocument() => _StubDocument();
}

class _StubDocument implements DocumentData {}

// --------------------------------------------------------------------------
// Harness
// --------------------------------------------------------------------------

String _msg(DocumentReaderState s) => 'state:${s.runtimeType}';

/// Bundles a configured DocumentReader + its container.
class Harness {
  final ProviderContainer container;
  final NotifierProvider<DocumentReader<DocumentData>, DocumentReaderState> provider;
  final FakeNfcProvider nfc;
  final FakeDataGroupReader dgr;
  final FakeDocumentParser parser;

  Harness(this.container, this.provider, this.nfc, this.dgr, this.parser);

  DocumentReader<DocumentData> get reader => container.read(provider.notifier);
  DocumentReaderState get state => container.read(provider);
}

Harness makeHarness({
  Set<DataGroups> present = const {},
  Set<DataGroups> throwOnParse = const {},
  Map<String, List<_Step>>? steps,
  Object? startSessionError,
  Object? startSessionPaceError,
  bool throwOnEfCom = false,
  bool nfcConnected = false,
  DocumentReaderConfig? config,
}) {
  final nfc = FakeNfcProvider(connected: nfcConnected);
  final dgr = FakeDataGroupReader(FakeComProvider([], throwWhenEmpty: false), steps: steps);
  dgr.startSessionError = startSessionError;
  dgr.startSessionPaceError = startSessionPaceError;
  final parser = FakeDocumentParser(present: present, throwOnParse: throwOnParse);
  parser.throwOnEfCom = throwOnEfCom;

  final cfg = config ?? DocumentReaderConfig(readIfAvailable: DataGroups.values.toSet());

  final provider = NotifierProvider<DocumentReader<DocumentData>, DocumentReaderState>(
    () => DocumentReader<DocumentData>(documentParser: parser, dataGroupReader: dgr, nfc: nfc, config: cfg),
  );
  final container = ProviderContainer();
  addTearDown(container.dispose);
  return Harness(container, provider, nfc, dgr, parser);
}

void main() {
  // --- Pure / simple methods ------------------------------------------------

  group('DocumentError', () {
    test('toString returns the message', () {
      expect(DocumentError('boom').toString(), 'boom');
      expect(DocumentError('x', code: StatusWord.invalidInstructionCode).code, StatusWord.invalidInstructionCode);
    });
  });

  group('DocumentReaderConfig.shouldRead', () {
    test('honours the configured set', () {
      final c = DocumentReaderConfig(readIfAvailable: {DataGroups.dg1, DataGroups.dg2});
      expect(c.shouldRead(DataGroups.dg1), true);
      expect(c.shouldRead(DataGroups.dg3), false);
    });
  });

  group('progressForState', () {
    test('covers every state arm', () {
      expect(progressForState(DocumentReaderPending()), 0.0);
      expect(progressForState(DocumentReaderCancelled()), 0.0);
      expect(progressForState(DocumentReaderCancelling()), 0.0);
      expect(
        progressForState(DocumentReaderFailed(error: DocumentReadingError.unknown, logs: '', sensitiveLogs: '')),
        0.0,
      );
      expect(progressForState(DocumentReaderConnecting()), 0.1);
      expect(progressForState(DocumentReaderReadingCardAccess()), 0.2);
      expect(progressForState(DocumentReaderAuthenticating()), 0.3);
      expect(progressForState(DocumentReaderReadingCOM()), 0.4);
      expect(progressForState(DocumentReaderReadingDataGroup(dataGroup: 'DG1', progress: 0.2)), 0.5 + 0.2 / 4.0);
      expect(progressForState(DocumentReaderReadingSOD()), 0.8);
      expect(progressForState(DocumentReaderActiveAuthentication()), 0.9);
      expect(progressForState(DocumentReaderSuccess()), 1.0);
    });

    test('throws on an unknown state', () {
      expect(() => progressForState(DocumentReaderNfcUnavailable()), throwsA(isA<Exception>()));
    });
  });

  group('build / reset / cancel / logs / checkNfcAvailability', () {
    test('build returns Pending and checkNfcAvailability swallows plugin error', () async {
      final h = makeHarness();
      expect(h.state, isA<DocumentReaderPending>());
      // checkNfcAvailability ran during build; its log line is present.
      expect(h.reader.getLogs(), contains('Checking NFC availability'));
    });

    test('reset sets state back to Pending', () async {
      final h = makeHarness();
      // mutate state then reset
      await h.reader.checkNfcAvailability();
      h.reader.reset();
      expect(h.state, isA<DocumentReaderPending>());
    });

    test('cancel sets the cancelled flag (observable via read flow)', () async {
      final h = makeHarness();
      await h.reader.cancel();
      // cancel only flips a private flag; exercised end-to-end in cancellation test.
      expect(h.state, isA<DocumentReaderPending>());
    });

    test('getLogs and getSensitiveLogs format with leading dash', () async {
      final h = makeHarness();
      await h.reader.checkNfcAvailability();
      expect(h.reader.getLogs().startsWith('- '), true);
      expect(h.reader.getSensitiveLogs().startsWith('- '), true);
    });
  });

  group('tryAuthenticateWithBAC', () {
    test('returns true when startSession succeeds', () async {
      final h = makeHarness();
      expect(await h.reader.tryAuthenticateWithBAC(), true);
      expect(h.dgr.startSessionCount, 1);
    });

    test('returns false when startSession throws', () async {
      final h = makeHarness(startSessionError: Exception('no bac'));
      expect(await h.reader.tryAuthenticateWithBAC(), false);
    });
  });

  // --- readDocument: happy paths -------------------------------------------

  group('readDocument BAC happy path', () {
    test('reads COM, mandatory + present optional DGs, SOD; returns document (no AA)', () async {
      final h = makeHarness(present: {DataGroups.dg1, DataGroups.dg2, DataGroups.dg11, DataGroups.dg15});
      final result = await h.reader.readDocument(iosNfcMessages: _msg);

      expect(result, isNotNull);
      expect(result!.$1, isA<DocumentData>());
      final raw = result.$2;
      // DG1, DG2, DG11, DG15 should all be present in the collected map.
      expect(raw.dataGroups.keys, containsAll(['DG1', 'DG2', 'DG11', 'DG15']));
      expect(raw.efSod, isNotEmpty);
      expect(raw.nonce, isNull);
      expect(raw.aaSignature, isNull);

      expect(h.state, isA<DocumentReaderSuccess>());
      expect(h.parser.parsed, containsAll(['COM', 'DG1', 'DG2', 'DG11', 'DG15', 'SOD']));
      // A DG that is not "present" must be skipped.
      expect(h.parser.parsed.contains('DG3'), false);
      // BAC used: startSession called once, no PACE.
      expect(h.dgr.startSessionCount, 1);
      expect(h.dgr.startSessionPaceCount, 0);
      expect(h.nfc.disconnectCount, greaterThanOrEqualTo(1));
    });

    test('with activeAuthenticationParams produces an AA signature', () async {
      final h = makeHarness(present: {DataGroups.dg1, DataGroups.dg2});
      final params = NonceAndSessionId(nonce: '0102030405060708', sessionId: 'sess-1');
      final result = await h.reader.readDocument(iosNfcMessages: _msg, activeAuthenticationParams: params);

      expect(result, isNotNull);
      final raw = result!.$2;
      expect(raw.sessionId, 'sess-1');
      expect(raw.nonce, isNotNull);
      expect(raw.aaSignature, isNotNull);
      expect(h.dgr.calls.contains('AA'), true);
    });

    test('AA invalidInstructionCode (6D00) is skipped, read still succeeds', () async {
      final h = makeHarness(
        present: {DataGroups.dg1, DataGroups.dg2},
        steps: {
          'AA': [_Step.fail(DocumentError('unsupported', code: StatusWord.invalidInstructionCode))],
        },
      );
      final params = NonceAndSessionId(nonce: '0102030405060708', sessionId: 'sess-2');
      final result = await h.reader.readDocument(iosNfcMessages: _msg, activeAuthenticationParams: params);

      expect(result, isNotNull);
      expect(h.state, isA<DocumentReaderSuccess>());
      // signature stays null because AA was skipped
      expect(result!.$2.aaSignature, isNull);
    });
  });

  group('readDocument PACE fallback path', () {
    test('falls back to PACE when BAC fails (reads CardAccess + startSessionPACE)', () async {
      final h = makeHarness(present: {DataGroups.dg1, DataGroups.dg2}, startSessionError: Exception('bac disabled'));
      final result = await h.reader.readDocument(iosNfcMessages: _msg);

      expect(result, isNotNull);
      expect(h.state, isA<DocumentReaderSuccess>());
      expect(h.parser.parsed.contains('CardAccess'), true);
      expect(h.dgr.startSessionPaceCount, greaterThanOrEqualTo(1));
      expect(h.dgr.calls.contains('CardAccess'), true);
    });
  });

  // --- readDocument: failure branches --------------------------------------

  group('readDocument failure branches', () {
    test('mandatory DG parse failure aborts with Failed state', () async {
      final h = makeHarness(present: {DataGroups.dg1, DataGroups.dg2}, throwOnParse: {DataGroups.dg1});
      final result = await h.reader.readDocument(iosNfcMessages: _msg);
      expect(result, isNull);
      expect(h.state, isA<DocumentReaderFailed>());
    });

    test('optional DG parse failure is logged and read continues to success', () async {
      final h = makeHarness(
        present: {DataGroups.dg1, DataGroups.dg2, DataGroups.dg3},
        throwOnParse: {DataGroups.dg3}, // dg3 is optional
      );
      final result = await h.reader.readDocument(iosNfcMessages: _msg);
      expect(result, isNotNull);
      expect(h.state, isA<DocumentReaderSuccess>());
      expect(h.reader.getLogs(), contains('Failed to parse optional data group'));
    });

    test('COM read failure -> Failed (rethrow after retries)', () async {
      final h = makeHarness(
        present: {DataGroups.dg1, DataGroups.dg2},
        steps: {'COM': List.generate(5, (_) => _Step.fail(Exception('com lost')))},
      );
      final result = await h.reader.readDocument(iosNfcMessages: _msg);
      expect(result, isNull);
      expect(h.state, isA<DocumentReaderFailed>());
    });

    test('DG read failure -> Failed', () async {
      final h = makeHarness(
        present: {DataGroups.dg1, DataGroups.dg2},
        steps: {'DG1': List.generate(5, (_) => _Step.fail(Exception('dg lost')))},
      );
      final result = await h.reader.readDocument(iosNfcMessages: _msg);
      expect(result, isNull);
      expect(h.state, isA<DocumentReaderFailed>());
    });

    test('SOD read failure -> Failed', () async {
      final h = makeHarness(
        present: {DataGroups.dg1, DataGroups.dg2},
        steps: {'SOD': List.generate(5, (_) => _Step.fail(Exception('sod lost')))},
      );
      final result = await h.reader.readDocument(iosNfcMessages: _msg);
      expect(result, isNull);
      expect(h.state, isA<DocumentReaderFailed>());
    });

    test('AA failure (non-6D00) -> Failed', () async {
      final h = makeHarness(
        present: {DataGroups.dg1, DataGroups.dg2},
        steps: {'AA': List.generate(5, (_) => _Step.fail(DocumentError('aa hard fail')))},
      );
      final params = NonceAndSessionId(nonce: '0102030405060708', sessionId: 's');
      final result = await h.reader.readDocument(iosNfcMessages: _msg, activeAuthenticationParams: params);
      expect(result, isNull);
      expect(h.state, isA<DocumentReaderFailed>());
    });

    test('CardAccess read failure during PACE -> Failed', () async {
      final h = makeHarness(
        present: {DataGroups.dg1, DataGroups.dg2},
        startSessionError: Exception('bac disabled'),
        steps: {'CardAccess': List.generate(5, (_) => _Step.fail(Exception('ca lost')))},
      );
      final result = await h.reader.readDocument(iosNfcMessages: _msg);
      expect(result, isNull);
      expect(h.state, isA<DocumentReaderFailed>());
    });

    test('PACE authentication failure -> Failed', () async {
      final h = makeHarness(
        present: {DataGroups.dg1, DataGroups.dg2},
        startSessionError: Exception('bac disabled'),
        startSessionPaceError: Exception('pace fail'),
      );
      final result = await h.reader.readDocument(iosNfcMessages: _msg);
      expect(result, isNull);
      expect(h.state, isA<DocumentReaderFailed>());
    });
  });

  // --- cancellation ---------------------------------------------------------

  group('cancellation', () {
    test('cancel during a read drives to Cancelled state and returns null', () async {
      final h = makeHarness(
        present: {DataGroups.dg1, DataGroups.dg2},
        steps: {
          // COM read throws once; combined with the cancel hook below the
          // _reconnectionLoop takes the _isCancelled -> _setToCancelState path.
          'COM': [_Step.fail(Exception('transient'))],
        },
      );
      // When COM is read, flip cancellation BEFORE the step throws.
      h.dgr.onRead['COM'] = () => h.reader.cancel();

      final result = await h.reader.readDocument(iosNfcMessages: _msg);
      expect(result, isNull);
      expect(h.state, isA<DocumentReaderCancelled>());
      // disconnect happened inside _setToCancelState
      expect(h.nfc.disconnectCount, greaterThanOrEqualTo(1));
    });
  });

  // --- fresh-poll cleanup (regression) --------------------------------------
  //
  // After a successful readout disconnect() finishes the plugin session
  // (disableReaderMode) but the chip usually stays in the field. On Android a
  // fresh readout that polls without first cycling the session never
  // re-dispatches the still-present tag, so the poll times out and only a
  // manual retry succeeds. _initRead now forceCleanup()s before the first
  // connect on Android to give every fresh readout a clean reader-mode state.
  //
  // These tests run the Android branch: under `flutter test` the host is never
  // iOS, so Platform.isIOS is false.
  group('readDocument fresh-poll cleanup', () {
    test('a fresh readout force-cleans the plugin session before polling', () async {
      final h = makeHarness(present: {DataGroups.dg1, DataGroups.dg2});

      final result = await h.reader.readDocument(iosNfcMessages: _msg);

      expect(result, isNotNull);
      expect(h.nfc.forceCleanupCount, 1);
      // The cleanup must happen before the first poll, otherwise the still
      // present chip is not re-dispatched and connect times out.
      expect(h.nfc.events.first, 'forceCleanup');
      expect(h.nfc.events.indexOf('forceCleanup'), lessThan(h.nfc.events.indexOf('connect')));
    });

    test('a second consecutive readout also force-cleans before polling', () async {
      final h = makeHarness(present: {DataGroups.dg1, DataGroups.dg2});

      // First readout: succeeds and disconnects (leaves the chip in the field).
      final first = await h.reader.readDocument(iosNfcMessages: _msg);
      expect(first, isNotNull);
      expect(h.nfc.isConnected(), false);
      final cleanupsAfterFirst = h.nfc.forceCleanupCount;

      // Second readout (the one that used to time out) must clean up again.
      h.reader.reset();
      final second = await h.reader.readDocument(iosNfcMessages: _msg);

      expect(second, isNotNull);
      expect(h.nfc.forceCleanupCount, cleanupsAfterFirst + 1);
      expect(h.state, isA<DocumentReaderSuccess>());
    });

    test('when already connected at start, it disconnects instead of forceCleanup', () async {
      final h = makeHarness(present: {DataGroups.dg1, DataGroups.dg2}, nfcConnected: true);

      final result = await h.reader.readDocument(iosNfcMessages: _msg);

      expect(result, isNotNull);
      // A stale connection is torn down, not force-cleaned.
      expect(h.nfc.forceCleanupCount, 0);
      expect(h.nfc.events.first, 'disconnect');
      expect(h.nfc.events.indexOf('disconnect'), lessThan(h.nfc.events.indexOf('connect')));
    });
  });
}
