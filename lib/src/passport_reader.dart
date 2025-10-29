import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vcmrtd/extensions.dart';
import 'package:vcmrtd/src/types/data_group_config.dart';
import 'package:vcmrtd/vcmrtd.dart';

typedef IosNfcMessageMapper = String Function(PassportReaderState);

class PassportReader extends StateNotifier<PassportReaderState> {
  final NfcProvider _nfc;
  bool _isCancelled = false;
  List<String> _log = [];
  IosNfcMessageMapper? _iosNfcMessageMapper;

  PassportReader(this._nfc) : super(PassportReaderPending()) {
    checkNfcAvailability();
  }

  Future<void> checkNfcAvailability() async {
    _addLog('Checking NFC availability');
    try {
      NfcStatus status = await NfcProvider.nfcStatus;
      if (status != NfcStatus.enabled) {
        state = PassportReaderNfcUnavailable();
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
    state = PassportReaderPending();
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
    if (state is PassportReaderNfcUnavailable) {
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

    _setState(PassportReaderConnecting());
    try {
      await _reconnectionLoop(session: session, authenticate: false, whenConnected: session.init);
    } catch (e) {
      await _failure(session, 'Failure during init: $e');
      return null;
    }

    // if (session.isPace()) {
    //   _setState(PassportReaderReadingCardAccess());
    //   try {
    //     await _reconnectionLoop(session: session, authenticate: false, whenConnected: session.readCardAccess);
    //     if (state is PassportReaderCancelled) {
    //       return null;
    //     }
    //   } catch (e) {
    //     await _failure(session, 'Failure reading Ef.CardAccess: $e');
    //     return null;
    //   }
    // }

    _setState(PassportReaderAuthenticating());
    try {
      await _reconnectionLoop(session: session, authenticate: false, whenConnected: session.authenticate);
      if (state is PassportReaderCancelled) {
        return null;
      }
    } catch (e) {
      await _failure(session, 'Failure authenticating: $e');
      return null;
    }

    _setState(PassportReaderReadingCOM());
    try {
      await _reconnectionLoop(session: session, authenticate: true, whenConnected: session.readCom);
      if (state is PassportReaderCancelled) {
        return null;
      }
    } catch (e) {
      await _failure(session, 'Failure reading Ef.COM: $e');
      return null;
    }

    for (final c in _createConfigs()) {
      _setState(PassportReaderReadingDataGroup(dataGroup: c.name, progress: c.progressStage));
      try {
        await _reconnectionLoop(session: session, authenticate: true, whenConnected: () => session.readDataGroup(c));
        if (state is PassportReaderCancelled) {
          return null;
        }
      } catch (e) {
        await _failure(session, 'Failure reading DG ${c.name}: $e');
        return null;
      }
    }

    _setState(PassportReaderReadingSOD());
    try {
      await _reconnectionLoop(session: session, authenticate: true, whenConnected: session.readSod);
      if (state is PassportReaderCancelled) {
        return null;
      }
    } catch (e) {
      await _failure(session, 'Failure active authentication: $e');
      return null;
    }

    _setState(PassportReaderActiveAuthentication());
    try {
      await _reconnectionLoop(session: session, authenticate: true, whenConnected: session.performActiveAuthentication);
      if (state is PassportReaderCancelled) {
        return null;
      }
    } catch (e) {
      await _failure(session, 'Failure active authentication: $e');
      return null;
    }

    _setState(PassportReaderSuccess());

    await session.dispose();
    final result = session.finish();
    return (result, session.result);
  }

  Future<void> _setToCancelState(_Session session) async {
    await _setState(PassportReaderCancelling());
    await session.dispose();
    if (!mounted) {
      return;
    }
    await _setState(PassportReaderCancelled());
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

  Future<void> _setState(PassportReaderState s) async {
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
    if (state is! PassportReaderNfcUnavailable && _nfc.isConnected()) {
      await _nfc.disconnect();
    }
  }

  Future<void> _failure(_Session session, String message) async {
    _addLog(message);
    final logs = '$message:\n${getLogs()}';
    state = PassportReaderFailed(error: PassportReadingError.unknown, logs: logs);
    await session.dispose();
  }

  List<DataGroupConfig> _createConfigs() {
    return [
      DataGroupConfig(
        tag: EfDG1.TAG,
        name: 'DG1',
        progressStage: 0.1,
        readFunction: (p, mrtdData) async => mrtdData.dg1 = await p.readEfDG1(),
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
        tag: EfDG6.TAG,
        name: 'DG6',
        progressStage: 0.5,
        readFunction: (p, mrtdData) async => mrtdData.dg6 = await p.readEfDG6(),
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
    return countryCode == null || paceCountriesAlpha3.contains(countryCode!.toUpperCase());
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

class PassportReaderState {}

class PassportReaderNfcUnavailable extends PassportReaderState {}

class PassportReaderPending extends PassportReaderState {}

class PassportReaderCancelled extends PassportReaderState {}

class PassportReaderCancelling extends PassportReaderState {}

class PassportReaderFailed extends PassportReaderState {
  PassportReaderFailed({required this.error, required this.logs});
  final String logs;
  final PassportReadingError error;
}

class PassportReaderConnecting extends PassportReaderState {}

class PassportReaderReadingCardAccess extends PassportReaderState {}

class PassportReaderReadingSOD extends PassportReaderState {}

class PassportReaderReadingCOM extends PassportReaderState {}

class PassportReaderAuthenticating extends PassportReaderState {}

class PassportReaderReadingDataGroup extends PassportReaderState {
  PassportReaderReadingDataGroup({required this.dataGroup, required this.progress});
  final String dataGroup;
  final double progress;
}

class PassportReaderActiveAuthentication extends PassportReaderState {}

class PassportReaderSuccess extends PassportReaderState {
  PassportReaderSuccess();
}

enum PassportReadingError { unknown, timeoutWaitingForTag, tagLost, failedToInitiateSession, invalidatedByUser }

double progressForState(PassportReaderState state) {
  return switch (state) {
    PassportReaderPending() => 0.0,
    PassportReaderCancelled() => 0.0,
    PassportReaderCancelling() => 0.0,
    PassportReaderFailed() => 0.0,
    PassportReaderConnecting() => 0.1,
    PassportReaderReadingCardAccess() => 0.2,
    PassportReaderAuthenticating() => 0.3,
    PassportReaderReadingCOM() => 0.4,
    PassportReaderReadingDataGroup(:final progress) => 0.5 + progress / 4.0,
    PassportReaderReadingSOD() => 0.8,
    PassportReaderActiveAuthentication() => 0.9,
    PassportReaderSuccess() => 1.0,
    _ => throw Exception('unexpected state: $state'),
  };
}
