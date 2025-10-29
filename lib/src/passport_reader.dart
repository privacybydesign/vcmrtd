import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vcmrtd/extensions.dart';
import 'package:vcmrtd/src/types/data_group_config.dart';
import 'package:vcmrtd/vcmrtd.dart';

typedef IosNfcMessageMapper = String Function(DocumentReaderState);

class PassportReader extends StateNotifier<DocumentReaderState> {
  final NfcProvider _nfc;
  bool _isCancelled = false;
  List<String> _log = [];
  IosNfcMessageMapper? _iosNfcMessageMapper;

  PassportReader(this._nfc) : super(DocumentReaderPending()) {
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

  Future<(PassportDataResult, MrtdData)?> readWithMRZ({
    required String documentNumber,
    required DateTime birthDate,
    required DateTime expiryDate,
    required String? countryCode,
    required IosNfcMessageMapper iosNfcMessages,
    NonceAndSessionId? activeAuthenticationParams,
  }) async {
    await _initRead(iosNfcMessages);

    // when nfc is unavailable we can't scan it...
    if (state is DocumentReaderNfcUnavailable) {
      return null;
    }

    final session = _Session(
      nfc: _nfc,
      passport: Passport(_nfc),
      documentNumber: documentNumber,
      birthDate: birthDate,
      expiryDate: expiryDate,
      countryCode: countryCode,
      activeAuthenticationParams: activeAuthenticationParams,
    );

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
      _setState(DocumentReaderReadingDataGroup(dataGroup: c.name, progress: c.progressStage));
      try {
        await _reconnectionLoop(session: session, authenticate: true, whenConnected: () => session.readDataGroup(c));
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
      await _reconnectionLoop(session: session, authenticate: true, whenConnected: session.readSod);
      if (state is DocumentReaderCancelled) {
        return null;
      }
    } catch (e) {
      await _failure(session, 'Failure active authentication: $e');
      return null;
    }

    _setState(DocumentReaderActiveAuthentication());
    try {
      await _reconnectionLoop(session: session, authenticate: true, whenConnected: session.performActiveAuthentication);
      if (state is DocumentReaderCancelled) {
        return null;
      }
    } catch (e) {
      await _failure(session, 'Failure active authentication: $e');
      return null;
    }

    _setState(DocumentReaderSuccess());

    await session.dispose();
    final result = session.finish();
    return (result, session.result);
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

  List<DataGroupConfig> _createConfigs() {
    return [
      DataGroupConfig(
        tag: EfDG1.TAG,
        name: 'DG1',
        progressStage: 0.1,
        readFunction: (p, mrtdData) async => mrtdData.dg1 = await p.readEfDG1(DocumentType.passport),
      ),
      DataGroupConfig(
        tag: EfDG2.TAG,
        name: 'DG2',
        progressStage: 0.2,
        readFunction: (p, mrtdData) async => mrtdData.dg2 = await p.readEfDG2(),
      ),
      DataGroupConfig(
        tag: EfDG5.TAG,
        name: 'DG5',
        progressStage: 0.4,
        readFunction: (p, mrtdData) async => mrtdData.dg5 = await p.readEfDG5(),
      ),
      DataGroupConfig(
        tag: EfDG6.getTag(DocumentType.passport),
        name: 'DG6',
        progressStage: 0.5,
        readFunction: (p, mrtdData) async => mrtdData.dg6 = await p.readEfDG6(DocumentType.passport),
      ),
      DataGroupConfig(
        tag: EfDG7.TAG,
        name: 'DG7',
        progressStage: 0.6,
        readFunction: (p, mrtdData) async => mrtdData.dg7 = await p.readEfDG7(),
      ),
      DataGroupConfig(
        tag: EfDG8.TAG,
        name: 'DG8',
        progressStage: 0.7,
        readFunction: (p, mrtdData) async => mrtdData.dg8 = await p.readEfDG8(),
      ),
      DataGroupConfig(
        tag: EfDG9.TAG,
        name: 'DG9',
        progressStage: 0.75,
        readFunction: (p, mrtdData) async => mrtdData.dg9 = await p.readEfDG9(),
      ),
      DataGroupConfig(
        tag: EfDG10.TAG,
        name: 'DG10',
        progressStage: 0.8,
        readFunction: (p, mrtdData) async => mrtdData.dg10 = await p.readEfDG10(),
      ),
      DataGroupConfig(
        tag: EfDG11.TAG,
        name: 'DG11',
        progressStage: 0.85,
        readFunction: (p, mrtdData) async => mrtdData.dg11 = await p.readEfDG11(),
      ),
      DataGroupConfig(
        tag: EfDG12.TAG,
        name: 'DG12',
        progressStage: 0.9,
        readFunction: (p, mrtdData) async => mrtdData.dg12 = await p.readEfDG12(),
      ),
      DataGroupConfig(
        tag: EfDG13.TAG,
        name: 'DG13',
        progressStage: 0.9,
        readFunction: (p, mrtdData) async => mrtdData.dg13 = await p.readEfDG13(),
      ),
      DataGroupConfig(
        tag: EfDG14.TAG,
        name: 'DG14',
        progressStage: 0.95,
        readFunction: (p, mrtdData) async => mrtdData.dg14 = await p.readEfDG14(),
      ),
      DataGroupConfig(
        tag: EfDG15.TAG,
        name: 'DG15',
        progressStage: 0.9,
        readFunction: (passport, data) async => data.dg15 = await passport.readEfDG15(),
      ),
      DataGroupConfig(
        tag: EfDG16.TAG,
        name: 'DG16',
        progressStage: 1.0,
        readFunction: (p, mrtdData) async => mrtdData.dg16 = await p.readEfDG16(),
      ),
    ];
  }
}

// =====================================================================================

class _Session {
  static const Set<String> paceCountriesAlpha3 = {
    'AUT', 'BEL', 'BGR', 'HRV', 'CYP', 'CZE', 'DNK', 'EST', 'FIN', 'FRA', 'DEU', 'GRC', // EU 27
    'HUN', 'IRL', 'ITA', 'LVA', 'LTU', 'LUX', 'MLT', 'NLD', 'POL', 'PRT', 'ROU', 'SVK', // EU 27
    'SVN', 'ESP', 'SWE', // EU 27
    'ISL', 'LIE', 'NOR', // EEA
    'CHE', // Switzerland
    'GBR', // Great Britain
  };

  final NfcProvider nfc;
  final String documentNumber;
  final DateTime birthDate;
  final DateTime expiryDate;
  final String? countryCode;
  final NonceAndSessionId? activeAuthenticationParams;
  Passport passport;

  final MrtdData result = MrtdData();
  final Map<String, String> dataGroups = {};

  _Session({
    required this.nfc,
    required this.passport,
    required this.documentNumber,
    required this.birthDate,
    required this.expiryDate,
    required this.countryCode,
    required this.activeAuthenticationParams,
  });

  Future<void> init() async {
    await nfc.connect();
  }

  Future<void> retryConnection() async {
    passport = Passport(nfc);

    if (nfc.isConnected()) {
      // want to use a timeout here because on ios when the session was cancelled by
      // the user while the tag was already outside of reach, the retry mechanism will
      // still kick in, causing it to hang at reconnecting.
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
    result.cardAccess = await passport.readEfCardAccess();
  }

  Future<void> readCom() async {
    result.com = await passport.readEfCOM();
  }

  Future<void> authenticate() async {
    final pace = isPace();
    final accessKey = DBAKey(documentNumber, birthDate, expiryDate, paceMode: pace);

    if (pace) {
      await passport.startSessionPACE(accessKey, result.cardAccess!);
    } else {
      await passport.startSession(accessKey);
    }
  }

  bool isPace() {
    return countryCode != null && paceCountriesAlpha3.contains(countryCode!.toUpperCase());
  }

  Future<void> readDataGroup(DataGroupConfig config) async {
    if (!result.com!.dgTags.contains(config.tag)) {
      return;
    }
    final dg = await config.readFunction(passport, result);
    final hexData = dg.toBytes().hex();
    if (hexData.isNotEmpty) {
      dataGroups[config.name] = hexData;
    }
  }

  Future<void> readSod() async {
    result.sod = await passport.readEfSOD();
  }

  Future<void> performActiveAuthentication() async {
    if (activeAuthenticationParams == null || !result.com!.dgTags.contains(EfDG15.TAG)) {
      return;
    }
    result.aaSig = await passport.activeAuthenticate(stringToUint8List(activeAuthenticationParams!.nonce));
  }

  PassportDataResult finish() {
    final efSodHex = result.sod?.toBytes().hex() ?? '';

    return PassportDataResult(
      dataGroups: dataGroups,
      efSod: efSodHex,
      nonce: activeAuthenticationParams != null ? stringToUint8List(activeAuthenticationParams!.nonce) : null,
      sessionId: activeAuthenticationParams?.sessionId,
      aaSignature: result.aaSig,
    );
  }

  Future<void> dispose() async {
    await nfc.disconnect();
  }
}

// ===============================================================
// all the different states the passport reader can be in

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
