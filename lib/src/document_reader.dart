import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vcmrtd/extensions.dart';
import 'package:vcmrtd/src/data_group_reader.dart';
import 'package:vcmrtd/src/models/document.dart';
import 'package:vcmrtd/src/parsers/document_parser.dart';
import 'package:vcmrtd/vcmrtd.dart';

import 'lds/df1/passportDGs.dart';

typedef IosNfcMessageMapper = String Function(DocumentReaderState);

class DocumentReader<DocType extends DocumentData> extends StateNotifier<DocumentReaderState> {
  final DocumentParser<DocType> parser;
  final DataGroupReader reader;
  final NfcProvider _nfc;

  bool _isCancelled = false;
  List<String> _log = [];
  IosNfcMessageMapper? _iosNfcMessageMapper;

  DocumentReader(this.parser, this.reader, this._nfc) : super(DocumentReaderPending()) {
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

  Future<(DocType, PassportDataResult)?> readWithMRZ({
    required String documentNumber,
    required DateTime birthDate,
    required DateTime expiryDate,
    required String? countryCode,
    required IosNfcMessageMapper iosNfcMessages,
    NonceAndSessionId? activeAuthenticationParams,
  }) async {
    await _initRead(iosNfcMessages);

    if (state is DocumentReaderNfcUnavailable) {
      return null;
    }

    final session = _Session(
      nfc: _nfc,
      reader: reader,
      documentNumber: documentNumber,
      birthDate: birthDate,
      expiryDate: expiryDate,
      countryCode: countryCode,
    );

    final Map<String, String> dataGroups = {};
    EfSOD? sod;
    Uint8List? aaSig;

    _setState(DocumentReaderConnecting());
    try {
      await _reconnectionLoop(session: session, authenticate: false, whenConnected: session.init);
    } catch (e) {
      await _failure(session, 'Failure during init: $e');
      return null;
    }

    if (session.isPace()) {
      _setState(DocumentReaderReadingCardAccess());
      try {
        await _reconnectionLoop(session: session, authenticate: false, whenConnected: session.readCardAccess);
        if (state is DocumentReaderCancelled) {
          return null;
        }
      } catch (e) {
        await _failure(session, 'Failure reading Ef.CardAccess: $e');
        return null;
      }
    }

    _setState(DocumentReaderAuthenticating());
    try {
      await _reconnectionLoop(session: session, authenticate: false, whenConnected: session.authenticate);
      if (state is DocumentReaderCancelled) {
        return null;
      }
    } catch (e) {
      await _failure(session, 'Failure authenticating: $e');
      return null;
    }

    _setState(DocumentReaderReadingCOM());
    try {
      await _reconnectionLoop(session: session, authenticate: true, whenConnected: session.readCom);
      if (state is DocumentReaderCancelled) {
        return null;
      }
    } catch (e) {
      await _failure(session, 'Failure reading Ef.COM: $e');
      return null;
    }

    for (final c in _createConfigs()) {
      final tagValues = session.com!.dgTags.map((t) => t.value).toSet();



      if (!tagValues.contains(c.tag.value)) {
        continue;
      }

      _setState(DocumentReaderReadingDataGroup(dataGroup: c.name, progress: c.progress));
      try {
        await _reconnectionLoop(
          session: session,
          authenticate: true,
          whenConnected: () async {
            final bytes = await c.readFn();
            c.parseFn(bytes);

            final hexData = bytes.hex();
            if (hexData.isNotEmpty) {
              dataGroups[c.name] = hexData;
            }
          },
        );
        if (state is DocumentReaderCancelled) {
          return null;
        }
      } catch (e) {
        await _failure(session, 'Failure reading DG ${c.name}: $e');
        return null;
      }
    }

    _setState(DocumentReaderReadingSOD());
    try {
      await _reconnectionLoop(
          session: session,
          authenticate: true,
          whenConnected: () async => sod = await reader.readEfSOD()
      );
      if (state is DocumentReaderCancelled) {
        return null;
      }
    } catch (e) {
      await _failure(session, 'Failure reading SOD: $e');
      return null;
    }

    if (activeAuthenticationParams != null && session.com!.dgTags.contains(PassportEfDG15.TAG.value)) {
      _setState(DocumentReaderActiveAuthentication());
      try {
        await _reconnectionLoop(
          session: session,
          authenticate: true,
          whenConnected: () async => aaSig = await reader.activeAuthenticate(
              stringToUint8List(activeAuthenticationParams.nonce)
          ),
        );
        if (state is DocumentReaderCancelled) {
          return null;
        }
      } catch (e) {
        await _failure(session, 'Failure active authentication: $e');
        return null;
      }
    }

    _setState(DocumentReaderSuccess());

    await session.dispose();

    final document = parser.createDocument();
    final result = PassportDataResult(
      dataGroups: dataGroups,
      efSod: sod?.toBytes().hex() ?? '',
      nonce: activeAuthenticationParams != null
          ? stringToUint8List(activeAuthenticationParams.nonce)
          : null,
      sessionId: activeAuthenticationParams?.sessionId,
      aaSignature: aaSig,
    );

    return (document, result);
  }

  Future<void> _setToCancelState(_Session session) async {
    await _setState(DocumentReaderCancelling());
    await session.dispose();
    if (!mounted) {
      return;
    }
    await _setState(DocumentReaderCancelled());
  }

  bool _isCancelException(Exception e) {
    return e.toString().toLowerCase().contains('session invalidated');
  }

  Future<void> _reconnectionLoop({
    required _Session session,
    required bool authenticate,
    required Function whenConnected,
    int numAttempts = 5,
  }) async {
    for (int i = 1; i <= numAttempts; ++i) {
      if (!mounted) {
        return;
      }
      if (_isCancelled) {
        return await _setToCancelState(session);
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
          return await _setToCancelState(session);
        }
        await Future.delayed(const Duration(milliseconds: 300));
        if (!mounted) {
          return;
        }
        if (_isCancelled) {
          return await _setToCancelState(session);
        }

        _addLog('Retry $i (Reason: $e)');
        try {
          await session.retryConnection();
        } catch (e) {
          _addLog('Retry connection failed: $e');
        }

        if (authenticate) {
          try {
            if (_isCancelled || _isCancelException(e)) {
              return await _setToCancelState(session);
            }
            await session.authenticate();
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
    if (message != null && _nfc.isConnected()) {
      await _nfc.setIosAlertMessage(message);
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
    if (state is! DocumentReaderNfcUnavailable && _nfc.isConnected()) {
      await _nfc.disconnect();
    }
  }

  Future<void> _failure(_Session session, String message) async {
    _addLog(message);
    final logs = '$message:\n${getLogs()}';
    state = DocumentReaderFailed(error: DocumentReadingError.unknown, logs: logs);
    await session.dispose();
  }

  List<_DGConfig> _createConfigs() {
    return [
      _DGConfig(PassportEfDG1.TAG, 'DG1', 0.1, reader.readDG1, parser.parseDG1),
      _DGConfig(PassportEfDG2.TAG, 'DG2', 0.2, reader.readDG2, parser.parseDG2),
      _DGConfig(PassportEfDG3.TAG, 'DG3', 0.3, reader.readDG3, parser.parseDG3),
      _DGConfig(PassportEfDG4.TAG, 'DG4', 0.35, reader.readDG4, parser.parseDG4),
      _DGConfig(PassportEfDG5.TAG, 'DG5', 0.4, reader.readDG5, parser.parseDG5),
      _DGConfig(PassportEfDG6.TAG, 'DG6', 0.5, reader.readDG6, parser.parseDG6),
      _DGConfig(PassportEfDG7.TAG, 'DG7', 0.6, reader.readDG7, parser.parseDG7),
      _DGConfig(PassportEfDG8.TAG, 'DG8', 0.7, reader.readDG8, parser.parseDG8),
      _DGConfig(PassportEfDG9.TAG, 'DG9', 0.75, reader.readDG9, parser.parseDG9),
      _DGConfig(PassportEfDG10.TAG, 'DG10', 0.8, reader.readDG10, parser.parseDG10),
      _DGConfig(PassportEfDG11.TAG, 'DG11', 0.85, reader.readDG11, parser.parseDG11),
      _DGConfig(PassportEfDG12.TAG, 'DG12', 0.9, reader.readDG12, parser.parseDG12),
      _DGConfig(PassportEfDG13.TAG, 'DG13', 0.9, reader.readDG13, parser.parseDG13),
      _DGConfig(PassportEfDG14.TAG, 'DG14', 0.95, reader.readDG14, parser.parseDG14),
      _DGConfig(PassportEfDG15.TAG, 'DG15', 0.9, reader.readDG15, parser.parseDG15),
      _DGConfig(PassportEfDG16.TAG, 'DG16', 1.0, reader.readDG16, parser.parseDG16),
    ];
  }
}

class _DGConfig {
  final DgTag tag;
  final String name;
  final double progress;
  final Future<Uint8List> Function() readFn;
  final void Function(Uint8List) parseFn;

  _DGConfig(this.tag, this.name, this.progress, this.readFn, this.parseFn);
}

class _Session {
  static const Set<String> paceCountriesAlpha3 = {
    'AUT', 'BEL', 'BGR', 'HRV', 'CYP', 'CZE', 'DNK', 'EST', 'FIN', 'FRA', 'DEU', 'GRC',
    'HUN', 'IRL', 'ITA', 'LVA', 'LTU', 'LUX', 'MLT', 'NLD', 'POL', 'PRT', 'ROU', 'SVK',
    'SVN', 'ESP', 'SWE',
    'ISL', 'LIE', 'NOR',
    'CHE',
    'GBR',
  };

  final NfcProvider nfc;
  final DataGroupReader reader;
  final String documentNumber;
  final DateTime birthDate;
  final DateTime expiryDate;
  final String? countryCode;

  EfCardAccess? cardAccess;
  EfCOM? com;

  _Session({
    required this.nfc,
    required this.reader,
    required this.documentNumber,
    required this.birthDate,
    required this.expiryDate,
    required this.countryCode,
  });

  Future<void> init() async {
    await nfc.connect();
  }

  Future<void> retryConnection() async {
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

  Future<void> readCardAccess() async {
    cardAccess = await reader.readEfCardAccess();
  }

  Future<void> readCom() async {
    com = await reader.readEfCOM();
  }

  Future<void> authenticate() async {
    final pace = isPace();
    final accessKey = DBAKey(documentNumber, birthDate, expiryDate, paceMode: pace);

    if (pace) {
      await reader.startSessionPACE(accessKey, cardAccess!);
    } else {
      await reader.startSession(accessKey);
    }
  }

  bool isPace() {
    return countryCode != null && paceCountriesAlpha3.contains(countryCode!.toUpperCase());
  }

  Future<void> dispose() async {
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

class DocumentReaderSuccess extends DocumentReaderState {
  DocumentReaderSuccess();
}

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