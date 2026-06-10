import 'dart:async';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:face_verification/src/face_verification/face_verification_worker.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Spawns a worker using the given test entry point (no plugin init),
/// subscribes to [events] to receive the worker's SendPort, and returns it.
Future<SendPort> _spawnWorker(
  void Function(SendPort) entryPoint,
  ReceivePort receivePort,
  Stream<dynamic> events,
) async {
  await Isolate.spawn(entryPoint, receivePort.sendPort);
  return await events.first as SendPort;
}

Map<String, dynamic> _cmd(int id, String cmd, [Map<String, dynamic>? payload]) => {
  'id': id,
  'cmd': cmd,
  'payload': payload ?? <String, dynamic>{},
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('Pipeline worker isolate', () {
    late ReceivePort receivePort;
    late Stream<dynamic> events;

    setUp(() {
      receivePort = ReceivePort();
      // Create the broadcast stream first — never call receivePort.first after this.
      events = receivePort.asBroadcastStream();
    });

    tearDown(() => receivePort.close());

    test('starts and responds to start_session', () async {
      final workerPort = await _spawnWorker(FaceVerificationWorker.debugPipelineWorkerEntry, receivePort, events);
      workerPort.send(_cmd(1, 'start_session'));
      final response = await events.first as Map;
      expect(response['id'], 1);
      expect((response['result'] as Map)['ok'], isTrue);
    });

    test('responds to stop', () async {
      final workerPort = await _spawnWorker(FaceVerificationWorker.debugPipelineWorkerEntry, receivePort, events);
      workerPort.send(_cmd(1, 'stop'));
      final response = await events.first as Map;
      expect((response['result'] as Map)['ok'], isTrue);
    });

    test('responds to dispose', () async {
      final workerPort = await _spawnWorker(FaceVerificationWorker.debugPipelineWorkerEntry, receivePort, events);
      workerPort.send(_cmd(1, 'dispose'));
      final response = await events.first as Map;
      expect((response['result'] as Map)['ok'], isTrue);
    });

    test('handles unknown command by returning an error', () async {
      final workerPort = await _spawnWorker(FaceVerificationWorker.debugPipelineWorkerEntry, receivePort, events);
      workerPort.send(_cmd(1, 'unknown_command'));
      final response = await events.first as Map;
      expect(response['id'], 1);
      expect(response['error'], isNotNull);
    });

    test('processes sequential commands in order', () async {
      final workerPort = await _spawnWorker(FaceVerificationWorker.debugPipelineWorkerEntry, receivePort, events);
      // Send first, await response, then send second.
      workerPort.send(_cmd(1, 'start_session'));
      final r1 = await events.first as Map;
      workerPort.send(_cmd(2, 'stop'));
      final r2 = await events.first as Map;
      expect(r1['id'], 1);
      expect(r2['id'], 2);
      expect((r1['result'] as Map)['ok'], isTrue);
      expect((r2['result'] as Map)['ok'], isTrue);
    });

    test('ignores non-Map messages', () async {
      final workerPort = await _spawnWorker(FaceVerificationWorker.debugPipelineWorkerEntry, receivePort, events);
      workerPort.send('not a map'); // silently ignored
      workerPort.send(_cmd(1, 'stop'));
      final response = await events.first as Map;
      expect((response['result'] as Map)['ok'], isTrue);
    });
  });

  group('Passive worker isolate', () {
    late ReceivePort receivePort;
    late Stream<dynamic> events;

    setUp(() {
      receivePort = ReceivePort();
      events = receivePort.asBroadcastStream();
    });

    tearDown(() => receivePort.close());

    test('starts and responds to start_session', () async {
      final workerPort = await _spawnWorker(FaceVerificationWorker.debugPassiveWorkerEntry, receivePort, events);
      workerPort.send(_cmd(1, 'start_session'));
      final response = await events.first as Map;
      expect((response['result'] as Map)['ok'], isTrue);
    });

    test('passive_result returns zero scores when uninitialised', () async {
      final workerPort = await _spawnWorker(FaceVerificationWorker.debugPassiveWorkerEntry, receivePort, events);
      workerPort.send(_cmd(1, 'passive_result'));
      final response = await events.first as Map;
      final result = response['result'] as Map;
      expect(result['antiSpoofPassed'], isFalse);
      expect(result['antiSpoofScore'], isNull);
    });

    test('responds to stop', () async {
      final workerPort = await _spawnWorker(FaceVerificationWorker.debugPassiveWorkerEntry, receivePort, events);
      workerPort.send(_cmd(1, 'stop'));
      final response = await events.first as Map;
      expect((response['result'] as Map)['ok'], isTrue);
    });
  });

  group('Match worker isolate', () {
    late ReceivePort receivePort;
    late Stream<dynamic> events;

    setUp(() {
      receivePort = ReceivePort();
      events = receivePort.asBroadcastStream();
    });

    tearDown(() => receivePort.close());

    test('starts and responds to start_session', () async {
      final workerPort = await _spawnWorker(FaceVerificationWorker.debugMatchWorkerEntry, receivePort, events);
      workerPort.send(_cmd(1, 'start_session'));
      final response = await events.first as Map;
      expect((response['result'] as Map)['ok'], isTrue);
    });

    test('check_consistency_selfie returns 1.0 when no reference stored', () async {
      final workerPort = await _spawnWorker(FaceVerificationWorker.debugMatchWorkerEntry, receivePort, events);
      final payload = <String, dynamic>{'width': 2, 'height': 2, 'rgb': List<int>.filled(2 * 2 * 3, 128)};
      workerPort.send(_cmd(1, 'check_consistency_selfie', payload));
      final response = await events.first as Map;
      expect((response['result'] as Map)['score'], closeTo(1.0, 1e-6));
    });

    test('match_selfie returns 0.0 when no NFC embedding stored', () async {
      final workerPort = await _spawnWorker(FaceVerificationWorker.debugMatchWorkerEntry, receivePort, events);
      final payload = <String, dynamic>{'width': 2, 'height': 2, 'rgb': List<int>.filled(2 * 2 * 3, 128)};
      workerPort.send(_cmd(1, 'match_selfie', payload));
      final response = await events.first as Map;
      expect((response['result'] as Map)['score'], closeTo(0.0, 1e-6));
    });

    test('responds to stop', () async {
      final workerPort = await _spawnWorker(FaceVerificationWorker.debugMatchWorkerEntry, receivePort, events);
      workerPort.send(_cmd(1, 'stop'));
      final response = await events.first as Map;
      expect((response['result'] as Map)['ok'], isTrue);
    });
  });
}
