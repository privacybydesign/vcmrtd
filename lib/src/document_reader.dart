import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vcmrtd/extensions.dart';
import 'package:vcmrtd/src/parsers/document_parser.dart';
import 'package:vcmrtd/vcmrtd.dart';

import '../internal.dart';

typedef IosNfcMessageMapper = String Function(DocumentReaderState);

class DocumentError implements Exception {
  final String message;
  final StatusWord? code;
  DocumentError(this.message, {this.code});
  @override
  String toString() => message;
}

enum _AuthMethod { none, bac, pace }

class DocumentReaderConfig {
  final Set<DataGroups> readIfAvailable;

  const DocumentReaderConfig({required this.readIfAvailable});

  bool shouldRead(DataGroups g) => readIfAvailable.contains(g);
}

class DocumentReader<DocType extends DocumentData> extends StateNotifier<DocumentReaderState> {
  final DocumentReaderConfig config;
  final DocumentParser<DocType> documentParser;
  final DataGroupReader dataGroupReader;
  final NfcProvider nfc;

  bool _isCancelled = false;
  List<String> _log = [];
  IosNfcMessageMapper? _iosNfcMessageMapper;

  DocumentReader({required this.documentParser, required this.dataGroupReader, required this.nfc, required this.config})
    : super(DocumentReaderPending()) {
    checkNfcAvailability();
  }

  Future<void> checkNfcAvailability() async {
    _addLog('Checking NFC availability');
    try {
      NfcStatus status = await NfcProvider.nfcStatus;
      if (status != NfcStatus.enabled) {
        state = DocumentReaderNfcUnavailable();
      }
      _addLog('NFC status: $status');
    } catch (e) {
      _addLog('Failed to get NFC status: $e');
    }
  }

  String getLogs() {
    return '- ${_log.join('\n-')}';
  }

  void reset() {
    _isCancelled = false;
    state = DocumentReaderPending();
  }

  Future<void> cancel() async {
    _isCancelled = true;
  }

  Future<bool> tryAuthenticateWithBAC() async {
    try {
      await dataGroupReader.startSession();
      return true;
    } catch (e) {
      return false;
    }
  }

  // First to Auth method is BAC if fail set to PACE
  Future<(DocType, RawDocumentData)?> readDocument({
    required IosNfcMessageMapper iosNfcMessages,
    NonceAndSessionId? activeAuthenticationParams,
  }) async {
    await _initRead(iosNfcMessages);

    if (state is DocumentReaderNfcUnavailable) {
      return null;
    }

    _setState(DocumentReaderConnecting());
    await nfc.connect(iosAlertMessage: iosNfcMessages(DocumentReaderConnecting()));

    _AuthMethod method = _AuthMethod.bac;
    _setState(DocumentReaderAuthenticating());
    final bacSuccess = await tryAuthenticateWithBAC();

    if (!bacSuccess) {
      method = _AuthMethod.pace;
      _setState(DocumentReaderReadingCardAccess());
      try {
        await _reconnectionLoop(
          authMethod: _AuthMethod.none,
          whenConnected: () async => documentParser.parseEfCardAccess(await dataGroupReader.readEfCardAccess()),
        );
        if (state is DocumentReaderCancelled) return null;
      } catch (e) {
        await _failure('Failure reading Ef.CardAccess: $e');
        return null;
      }

      _setState(DocumentReaderAuthenticating());
      try {
        await _reconnectionLoop(
          authMethod: _AuthMethod.none,
          whenConnected: () async => dataGroupReader.startSessionPACE(documentParser.cardAccess),
        );
        if (state is DocumentReaderCancelled) return null;
      } catch (e) {
        await _failure('Failure authenticating with PACE: $e');
        return null;
      }
    }

    _setState(DocumentReaderReadingCOM());
    try {
      await _reconnectionLoop(
        authMethod: method,
        whenConnected: () async => documentParser.parseEfCOM(await dataGroupReader.readEfCOM()),
      );
      if (state is DocumentReaderCancelled) return null;
    } catch (e) {
      await _failure('Failure reading Ef.COM: $e');
      return null;
    }

    final Map<String, String> dataGroups = {};

    for (final (dataGroup, read, parse, progress) in [
      (DataGroups.dg1, dataGroupReader.readDG1, documentParser.parseDG1, 0.1),
      (DataGroups.dg2, dataGroupReader.readDG2, documentParser.parseDG2, 0.2),
      (DataGroups.dg3, dataGroupReader.readDG3, documentParser.parseDG3, 0.3),
      (DataGroups.dg4, dataGroupReader.readDG4, documentParser.parseDG4, 0.35),
      (DataGroups.dg5, dataGroupReader.readDG5, documentParser.parseDG5, 0.4),
      (DataGroups.dg6, dataGroupReader.readDG6, documentParser.parseDG6, 0.5),
      (DataGroups.dg7, dataGroupReader.readDG7, documentParser.parseDG7, 0.6),
      (DataGroups.dg8, dataGroupReader.readDG8, documentParser.parseDG8, 0.7),
      (DataGroups.dg9, dataGroupReader.readDG9, documentParser.parseDG9, 0.75),
      (DataGroups.dg10, dataGroupReader.readDG10, documentParser.parseDG10, 0.8),
      (DataGroups.dg11, dataGroupReader.readDG11, documentParser.parseDG11, 0.85),
      (DataGroups.dg12, dataGroupReader.readDG12, documentParser.parseDG12, 0.9),
      (DataGroups.dg13, dataGroupReader.readDG13, documentParser.parseDG13, 0.9),
      (DataGroups.dg14, dataGroupReader.readDG14, documentParser.parseDG14, 0.95),
      (DataGroups.dg15, dataGroupReader.readDG15, documentParser.parseDG15, 0.9),
      (DataGroups.dg16, dataGroupReader.readDG16, documentParser.parseDG16, 1.0),
    ]) {
      if (!(config.shouldRead(dataGroup) && documentParser.documentContainsDataGroup(dataGroup))) {
        continue;
      }

      _setState(DocumentReaderReadingDataGroup(dataGroup: dataGroup.getName(), progress: progress));
      try {
        await _reconnectionLoop(
          authMethod: method,
          whenConnected: () async {
            final bytes = await read();
            parse(bytes);

            final hexData = bytes.hex();
            if (hexData.isNotEmpty) {
              dataGroups[dataGroup.getName()] = hexData;
            }
          },
        );
        if (state is DocumentReaderCancelled) {
          return null;
        }
      } catch (e) {
        await _failure('Failure reading data group $dataGroup: $e');
        return null;
      }
    }

    _setState(DocumentReaderReadingSOD());
    try {
      await _reconnectionLoop(
        authMethod: method,
        whenConnected: () async => documentParser.parseEfSOD(await dataGroupReader.readEfSOD()),
      );
      if (state is DocumentReaderCancelled) {
        return null;
      }
    } catch (e) {
      await _failure('Failure reading SOD: $e');
      return null;
    }

    Uint8List? aaSig;
    if (activeAuthenticationParams != null) {
      _setState(DocumentReaderActiveAuthentication());
      try {
        await _reconnectionLoop(
          authMethod: method,
          whenConnected: () async {
            aaSig = await dataGroupReader.activeAuthenticate(stringToUint8List(activeAuthenticationParams.nonce));
          },
        );
        if (state is DocumentReaderCancelled) {
          return null;
        }
      } catch (e) {
        await _failure('Failure active authentication: $e');
        return null;
      }
    }

    _setState(DocumentReaderSuccess());

    await nfc.disconnect();

    final document = documentParser.createDocument();
    final result = RawDocumentData(
      dataGroups: dataGroups,
      efSod: documentParser.sod.toBytes().hex(),
      sessionId: activeAuthenticationParams?.sessionId,
      nonce: activeAuthenticationParams != null ? stringToUint8List(activeAuthenticationParams.nonce) : null,
      aaSignature: aaSig,
    );

    return (document, result);
  }

  Future<void> _setToCancelState() async {
    await _setState(DocumentReaderCancelling());
    await nfc.disconnect();
    if (!mounted) {
      return;
    }
    await _setState(DocumentReaderCancelled());
  }

  bool _isCancelException(Exception e) {
    return e.toString().toLowerCase().contains('session invalidated');
  }

  Future<void> _retryConnection() async {
    dataGroupReader.reset();
    if (nfc.isConnected()) {
      if (Platform.isIOS) {
        await nfc.reconnect().timeout(Duration(seconds: 2));
      } else {
        await nfc.disconnect();
        await nfc.connect().timeout(Duration(seconds: 2));
      }
    } else {
      await nfc.connect().timeout(Duration(seconds: 2));
    }
  }

  Future<void> _reconnectionLoop({
    required _AuthMethod authMethod,
    required Function whenConnected,
    int numAttempts = 5,
  }) async {
    for (int i = 1; i <= numAttempts; ++i) {
      if (!mounted) {
        return;
      }
      if (_isCancelled) {
        return await _setToCancelState();
      }
      try {
        await whenConnected();
        return;
      } on Exception catch (e) {
        if (i >= numAttempts) {
          _addLog('Rethrow on attempt $i');
          rethrow;
        }
        if (_isCancelled || _isCancelException(e)) {
          return await _setToCancelState();
        }
        await Future.delayed(const Duration(milliseconds: 300));
        _addLog('Retry $i (Reason: $e)');
        try {
          await _retryConnection();
        } catch (e) {
          _addLog('Retry connection failed: $e');
        }

        if (authMethod != _AuthMethod.none) {
          try {
            if (_isCancelled || _isCancelException(e)) {
              return await _setToCancelState();
            }
            authMethod == _AuthMethod.bac
                ? await dataGroupReader.startSession()
                : await dataGroupReader.startSessionPACE(documentParser.cardAccess);
          } catch (e) {
            _addLog('Retry authenticate failed: $e');
          }
        }
      }
    }
  }

  Future<void> _setState(DocumentReaderState s) async {
    if (!mounted) {
      return;
    }
    _addLog('Setting state to $s');
    state = s;
    final message = _iosNfcMessageMapper?.call(state);
    if (message != null && nfc.isConnected()) {
      await nfc.setIosAlertMessage(message);
    }
  }

  void _addLog(String log) {
    _log.add(log);
    debugPrint(log);
  }

  Future<void> _initRead(IosNfcMessageMapper mapper) async {
    _log = [];
    _iosNfcMessageMapper = mapper;
    _isCancelled = false;
    await checkNfcAvailability();
    if (state is! DocumentReaderNfcUnavailable && nfc.isConnected()) {
      await nfc.disconnect();
    }
  }

  Future<void> _failure(String message) async {
    _addLog(message);
    final logs = '$message:\n${getLogs()}';
    state = DocumentReaderFailed(error: DocumentReadingError.unknown, logs: logs);
    await nfc.disconnect();
  }
}

class DocumentReaderState {}

class DocumentReaderNfcUnavailable extends DocumentReaderState {}

class DocumentReaderPending extends DocumentReaderState {}

class DocumentReaderCancelled extends DocumentReaderState {}

class DocumentReaderCancelling extends DocumentReaderState {}

class DocumentReaderFailed extends DocumentReaderState {
  DocumentReaderFailed({required this.error, required this.logs});
  final String logs;
  final DocumentReadingError error;
}

class DocumentReaderConnecting extends DocumentReaderState {}

class DocumentReaderReadingCardAccess extends DocumentReaderState {}

class DocumentReaderReadingSOD extends DocumentReaderState {}

class DocumentReaderReadingCOM extends DocumentReaderState {}

class DocumentReaderAuthenticating extends DocumentReaderState {}

class DocumentReaderReadingDataGroup extends DocumentReaderState {
  DocumentReaderReadingDataGroup({required this.dataGroup, required this.progress});
  final String dataGroup;
  final double progress;
}

class DocumentReaderActiveAuthentication extends DocumentReaderState {}

class DocumentReaderSuccess extends DocumentReaderState {}

enum DocumentReadingError { unknown, timeoutWaitingForTag, tagLost, failedToInitiateSession, invalidatedByUser }

double progressForState(DocumentReaderState state) {
  return switch (state) {
    DocumentReaderPending() => 0.0,
    DocumentReaderCancelled() => 0.0,
    DocumentReaderCancelling() => 0.0,
    DocumentReaderFailed() => 0.0,
    DocumentReaderConnecting() => 0.1,
    DocumentReaderReadingCardAccess() => 0.2,
    DocumentReaderAuthenticating() => 0.3,
    DocumentReaderReadingCOM() => 0.4,
    DocumentReaderReadingDataGroup(:final progress) => 0.5 + progress / 4.0,
    DocumentReaderReadingSOD() => 0.8,
    DocumentReaderActiveAuthentication() => 0.9,
    DocumentReaderSuccess() => 1.0,
    _ => throw Exception('unexpected state: $state'),
  };
}
