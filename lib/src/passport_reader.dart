import 'package:flutter/foundation.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vcmrtd/extensions.dart';
import 'package:vcmrtd/src/types/data_group_config.dart';
import 'package:vcmrtd/vcmrtd.dart';

class Session {
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

  Session({
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
    // await nfc.reconnect();
    if (nfc.isConnected()) {
      await nfc.reconnect();
    } else {
      await nfc.connect();
    }
  }

  Future<void> readCardAccess() async {
    result.cardAccess = await passport.readEfCardAccess();
  }

  Future<void> readCom() async {
    result.com = await passport.readEfCOM();
  }

  Future<void> authenticate() async {
    final isPaceCandidate = countryCode == null || paceCountriesAlpha3.contains(countryCode!.toUpperCase());
    final accessKey = DBAKey(documentNumber, birthDate, expiryDate, paceMode: isPaceCandidate);

    if (isPaceCandidate) {
      await passport.startSessionPACE(accessKey, result.cardAccess!);
    } else {
      await passport.startSession(accessKey);
    }
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

class PassportReader extends StateNotifier<PassportReaderState> {
  final NfcProvider _nfc;
  MrtdData? _mrtdData;
  bool _isCancelled = false;
  List<String> _log = [];

  PassportReader(this._nfc) : super(PassportReaderPending()) {
    checkNfcAvailability();
  }

  Future<void> checkNfcAvailability() async {
    // _addLog('Checking NFC availability');
    try {
      NfcStatus status = await NfcProvider.nfcStatus;
      if (status != NfcStatus.enabled) {
        state = PassportReaderNfcUnavailable();
      }
      // _addLog('NFC status: $status');
    } catch (e) {
      // _addLog('Failed to get NFC status: $e');
    }
  }

  void reset() {
    _isCancelled = false;
    state = PassportReaderPending();
  }

  Future<void> cancel() async {
    _isCancelled = true;
    // _addLog('NFC scanning cancelled');
    state = PassportReaderCancelling();
    // await _disconnect('passport.nfc.cancelling');

    // check if the widget is still mounted,
    // because cancel can also be called from the dispose function
    if (mounted) {
      state = PassportReaderCancelled();
    }
  }

  // Future<void> _setIosAlertMessage(String message, String Function(double) progressFormatter) async {
  //   if (_nfc.isConnected()) {
  //     final progress = progressForState(state);
  //     final formattedProgress = progressFormatter(progress);
  //     _nfc.setIosAlertMessage('$formattedProgress\n$message');
  //   }
  // }
  //

  Future<void> _reconnectionLoop({
    required Session session,
    required bool authenticate,
    required Function toTry,
    int numAttempts = 5,
  }) async {
    for (int i = 0; i < numAttempts; ++i) {
      try {
        await toTry();
        return;
      } catch (e) {
        if (i >= numAttempts - 1) {
          debugPrint('''
        \n\n\n\n\n\n\n\n\nRETHROW $i\n\n\n\n\n\n
        ''');
          rethrow;
        }
        await Future.delayed(const Duration(milliseconds: 300));
        debugPrint('''
        \n\n\n\n\n\n\n\n\nRETRY $i\nReason: $e\n\n\n\n\n
        ''');

        try {
          await session.retryConnection();
        } catch (e) {
          debugPrint('Retry connection failed: $e');
        }
        if (authenticate) {
          try {
            await session.authenticate();
          } catch (e) {
            debugPrint('Retry authenticate failed: $e');
          }
        }
      }
    }
    debugPrint('''
        \n\n\n\n\n\n\n\n\nOUT SCOPE\n\n\n\n\n\n
        ''');
  }

  Future<PassportDataResult?> readWithMRZ({
    required IosNfcMessages iosNfcMessages,
    required String documentNumber,
    required DateTime birthDate,
    required DateTime expiryDate,
    required String? countryCode,
    NonceAndSessionId? activeAuthenticationParams,
  }) async {
    await checkNfcAvailability();

    // when nfc is unavailable we can't scan it...
    if (state is PassportReaderNfcUnavailable) {
      return null;
    }

    final session = Session(
      nfc: _nfc,
      passport: Passport(_nfc),
      documentNumber: documentNumber,
      birthDate: birthDate,
      expiryDate: expiryDate,
      countryCode: countryCode,
      activeAuthenticationParams: activeAuthenticationParams,
    );

    try {
      await session.init();
    } catch (e) {
      state = PassportReaderFailed(error: PassportReadingError.unknown, logs: e.toString());
      debugPrint('Failure: $e');
      await session.dispose();
      return null;
    }

    state = PassportReaderReadingCardAccess();
    try {
      await _reconnectionLoop(session: session, authenticate: false, toTry: session.readCardAccess);
    } catch (e) {
      state = PassportReaderFailed(error: PassportReadingError.unknown, logs: e.toString());
      await session.dispose();
      debugPrint('Failure card reading access: $e');
      return null;
    }

    state = PassportReaderAuthenticating();
    try {
      await _reconnectionLoop(session: session, authenticate: false, toTry: session.authenticate);
    } catch (e) {
      state = PassportReaderFailed(error: PassportReadingError.unknown, logs: e.toString());
      await session.dispose();
      debugPrint('Failure authenticating: $e');
      return null;
    }

    try {
      await _reconnectionLoop(session: session, authenticate: true, toTry: session.readCom);
    } catch (e) {
      state = PassportReaderFailed(error: PassportReadingError.unknown, logs: e.toString());
      await session.dispose();
      debugPrint('Failure read com: $e');
      return null;
    }

    for (final config in _createConfigs()) {
      state = PassportReaderReadingPassportData(dataGroup: config.name, progress: config.progressStage);
      try {
        await _reconnectionLoop(
          session: session,
          authenticate: true,
          toTry: () async => await session.readDataGroup(config),
        );
      } catch (e) {
        state = PassportReaderFailed(error: PassportReadingError.unknown, logs: e.toString());
        await session.dispose();
        debugPrint('Failure reading DG ${config.name}: $e');
        return null;
      }
    }

    await _reconnectionLoop(session: session, authenticate: true, toTry: session.readSod);

    state = PassportReaderSecurityVerification();
    try {
      await _reconnectionLoop(session: session, authenticate: true, toTry: session.performActiveAuthentication);
      await session.performActiveAuthentication();
    } catch (e) {
      state = PassportReaderFailed(error: PassportReadingError.unknown, logs: e.toString());
      await session.dispose();
      debugPrint('Failure active authentication: $e');
      return null;
    }

    final result = session.finish();
    state = PassportReaderSuccess(result: result, mrtdData: session.result);
    await session.dispose();
    return result;
  }

  /*
  Future<PassportDataResult?> _readWithMRZ({
    required IosNfcMessages iosNfcMessages,
    required String documentNumber,
    required DateTime birthDate,
    required DateTime expiryDate,
    required String? countryCode,
    NonceAndSessionId? activeAuthenticationParams,
  }) async {
    _log = ['Reading with MRZ'];

    await checkNfcAvailability();
    // when nfc is unavailable we can't scan it...
    if (state is PassportReaderNfcUnavailable) {
      return null;
    }

    final isPaceCandidate = countryCode == null || paceCountriesAlpha3.contains(countryCode.toUpperCase());

    final key = DBAKey(documentNumber, birthDate, expiryDate, paceMode: isPaceCandidate);

    try {
      return await _readAttempt(
        iosNfcMessages: iosNfcMessages,
        accessKey: key,
        isPace: isPaceCandidate,
        activeAuthenticationParams: activeAuthenticationParams,
      );
    } catch (e) {
      _handleError(iosNfcMessages, e);
    }
    return null;
  }

  Future<PassportDataResult?> _readAttempt({
    required IosNfcMessages iosNfcMessages,
    required AccessKey accessKey,
    required bool isPace,
    NonceAndSessionId? activeAuthenticationParams,
  }) async {
    _addLog('Connecting...');
    state = PassportReaderConnecting();

    await _nfc.connect(iosAlertMessage: iosNfcMessages.holdNearPhotoPage);

    final passport = Passport(_nfc);

    PassportDataResult? result;
    try {
      result = await _perform(
        iosNfcMessages,
        passport,
        accessKey,
        isPace,
        activeAuthenticationParams: activeAuthenticationParams,
      );
    } finally {
      await _disconnect(null);
    }
    return result;
  }

  static const Set<String> paceCountriesAlpha3 = {
    'AUT', 'BEL', 'BGR', 'HRV', 'CYP', 'CZE', 'DNK', 'EST', 'FIN', 'FRA', 'DEU', 'GRC', // EU 27
    'HUN', 'IRL', 'ITA', 'LVA', 'LTU', 'LUX', 'MLT', 'NLD', 'POL', 'PRT', 'ROU', 'SVK', // EU 27
    'SVN', 'ESP', 'SWE', // EU 27
    'ISL', 'LIE', 'NOR', // EEA
    'CHE', // Switzerland
    'GBR', // Great Britain
  };

  Future<void> _startSession(Passport passport, AccessKey accessKey) async {
    await _readCardAccess(passport);
    if (_mrtdData!.isPACE!) {
      await passport.startSessionPACE(accessKey, _mrtdData!.cardAccess!);
    } else {
      await passport.startSession(accessKey as DBAKey);
    }
  }

  Future<void> _readCardAccess(Passport passport) async {
    passport.reset();
    try {
      _mrtdData!.cardAccess = await passport.readEfCardAccess();
      _addLog('Reading card access successful');
    } on PassportError catch (e) {
      _addLog('Reading card access failed: $e');
    }
  }

  Future<PassportDataResult> _perform(
    IosNfcMessages iosNfcMessages,
    Passport passport,
    AccessKey accessKey,
    bool isPace, {
    NonceAndSessionId? activeAuthenticationParams,
  }) async {
    _mrtdData = MrtdData();
    _mrtdData!.isPACE = isPace;
    _mrtdData!.isDBA = accessKey is DBAKey && (accessKey.PACE_REF_KEY_TAG == 0x01);

    _addLog('Reading card access (isPace: $isPace, isDBA: ${_mrtdData!.isDBA})');
    state = PassportReaderReadingCardAccess();
    _setIosAlertMessage(iosNfcMessages.readingCardAccess, iosNfcMessages.progressFormatter);

    await _readCardAccess(passport);

    _addLog('Authenticating (pace: $isPace)');
    state = PassportReaderAuthenticating();
    _setIosAlertMessage(iosNfcMessages.authenticating, iosNfcMessages.progressFormatter);

    await _startSession(passport, accessKey);

    state = PassportReaderAuthenticating();
    _setIosAlertMessage(iosNfcMessages.authenticating, iosNfcMessages.progressFormatter);

    final result = await _readDataGroups(
      iosNfcMessages,
      accessKey,
      passport,
      _mrtdData!,
      activeAuthenticationParams: activeAuthenticationParams,
    );

    _addLog('Reading successful');
    state = PassportReaderSuccess(result: result, mrtdData: _mrtdData!);
    _setIosAlertMessage(iosNfcMessages.completedSuccessfully, iosNfcMessages.progressFormatter);
    return result;
  }

  Future<DataGroup> _repeatedlyReadDg(
    Passport passport,
    Future<DataGroup> Function(Passport) readFunction,
    AccessKey accessKey,
  ) async {
    for (int i = 0; i < 5; ++i) {
      try {
        return await readFunction(passport);
      } catch (e) {
        if (i < 4) {
          await Future.delayed(Duration(milliseconds: 300));
          _addLog('Reading DG failed: $e, retring... (${_nfc.isConnected()})');
          await _reconnect(passport, accessKey);
          continue;
        }
        rethrow;
      }
    }
    throw Exception('unreachable');
  }

  Future<void> _reconnect(Passport passport, accessKey) async {
    try {
      await _nfc.reconnect();
    } catch (e) {
      _addLog('Reconnect failed: $e');
      return;
    }
    try {
      // reset the secure communication
      passport.reset();
      await _startSession(passport, accessKey);
      _addLog('Successfully restarted session after losing NFC Tag');
    } catch (e) {
      _addLog('_startSession failed: $e');
    }
  }

  Future<PassportDataResult> _readDataGroups(
    IosNfcMessages iosNfcMessages,
    AccessKey accessKey,
    Passport passport,
    MrtdData mrtdData, {
    NonceAndSessionId? activeAuthenticationParams,
  }) async {
    try {
      _addLog('Reading EF COM');
      mrtdData.com = await passport.readEfCOM();

      final Map<String, String> dataGroups = {};

      final configs = _createConfigs(mrtdData);

      for (final cfg in configs) {
        if (_isCancelled) {
          throw Exception('Cancelled');
        }

        if (mrtdData.com!.dgTags.contains(cfg.tag)) {
          try {
            _addLog('Reading data group ${cfg.name}');

            final dgData = await _repeatedlyReadDg(passport, cfg.readFunction, accessKey);
            // Convert data group to hex string
            final hexData = dgData.toBytes().hex();
            if (hexData.isNotEmpty) {
              dataGroups[cfg.name] = hexData;
            }
            _addLog('Reading data group ${cfg.name} successful');
          } catch (e) {
            _addLog('Failed to read ${cfg.name}: $e');
            rethrow;
          }
        } else {
          _addLog('Skipped reading data group ${cfg.name}');
        }

        state = PassportReaderReadingPassportData(dataGroup: cfg.name, progress: cfg.progressStage);
        _setIosAlertMessage(iosNfcMessages.readingPassportData, iosNfcMessages.progressFormatter);
      }

      if (activeAuthenticationParams != null && mrtdData.com!.dgTags.contains(EfDG15.TAG)) {
        _addLog('Security verification');
        state = PassportReaderSecurityVerification();
        _setIosAlertMessage(iosNfcMessages.authenticating, iosNfcMessages.progressFormatter);

        try {
          _addLog('Reading EfDG15');
          mrtdData.dg15 = await passport.readEfDG15();
          _addLog('Successfully read EfDG15');
          if (mrtdData.dg15 != null) {
            final hex = mrtdData.dg15!.toBytes().hex();
            if (hex.isNotEmpty) {
              dataGroups['DG15'] = hex;
            }
          }

          _addLog('Performing active authentication');
          mrtdData.aaSig = await passport.activeAuthenticate(stringToUint8List(activeAuthenticationParams.nonce));
          _addLog('Active authentication successful');
        } catch (e) {
          _addLog('Failed to read DG15 or perform AA: $e');
        }
      } else {
        _addLog('Skipped security verification');
      }

      _addLog('Reading EfSOD');
      mrtdData.sod = await passport.readEfSOD();
      _addLog('Successfully read EfSOD');
      final efSodHex = mrtdData.sod?.toBytes().hex() ?? '';

      final result = PassportDataResult(
        dataGroups: dataGroups,
        efSod: efSodHex,
        nonce: activeAuthenticationParams != null ? stringToUint8List(activeAuthenticationParams.nonce) : null,
        sessionId: activeAuthenticationParams?.sessionId,
        aaSignature: mrtdData.aaSig,
      );
      return result;
    } catch (e) {
      _handleError(iosNfcMessages, e);
      rethrow;
    }
  }

  void _handleError(IosNfcMessages iosNfcMessages, Object e) {
    final se = e.toString().toLowerCase();
    PassportReadingError error = PassportReadingError.unknown;

    if (e is PassportError) {
      if (se.contains('security status not satisfied')) {
        error = PassportReadingError.failedToInitiateSession;
        _setIosAlertMessage(iosNfcMessages.failedToInitiateSession, iosNfcMessages.progressFormatter);
      }
      debugPrint('PassportError: ${e.message}');
    } else {
      debugPrint('Exception while reading Passport: $e');
    }

    if (se.contains('timeout')) {
      error = PassportReadingError.timeoutWaitingForTag;
      _setIosAlertMessage(iosNfcMessages.timeoutWaitingForTag, iosNfcMessages.progressFormatter);
    } else if (se.contains('tag was lost')) {
      error = PassportReadingError.tagLost;
      _setIosAlertMessage(iosNfcMessages.tagLostTryAgain, iosNfcMessages.progressFormatter);
    } else if (se.contains('invalidated by user')) {
      error = PassportReadingError.invalidatedByUser;
      _setIosAlertMessage(iosNfcMessages.cancelledByUser, iosNfcMessages.progressFormatter);
    }

    final logs = 'NFC reading failed:\n - ${_compileLogs()}\n\nException: $e';
    state = PassportReaderFailed(error: error, logs: logs);
  }

  String _compileLogs() {
    return _log.join('\n - ');
  }

  void _addLog(String message) {
    _log.add(message);
    debugPrint(message);
  }

  Future<void> _disconnect(String? msg) async {
    _addLog('Disconnectig, message: $msg');
    try {
      await _nfc.disconnect(iosErrorMessage: msg);
      _addLog('Disconnectig successful');
    } catch (e) {
      _addLog('Disconnectig failed: $e');
      debugPrint('Error during NFC disconnect: $e');
    }
  }
  */

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

class PassportReaderAuthenticating extends PassportReaderState {}

class PassportReaderReadingPassportData extends PassportReaderState {
  PassportReaderReadingPassportData({required this.dataGroup, required this.progress});
  final String dataGroup;
  final double progress;
}

class PassportReaderSecurityVerification extends PassportReaderState {}

class PassportReaderSuccess extends PassportReaderState {
  PassportReaderSuccess({required this.result, required this.mrtdData});
  final PassportDataResult result;
  final MrtdData mrtdData;
}

enum PassportReadingError { unknown, timeoutWaitingForTag, tagLost, failedToInitiateSession, invalidatedByUser }

// ===============================================================

class IosNfcMessages {
  final String holdNearPhotoPage;
  final String cancelling;
  final String cancelled;
  final String connecting;
  final String readingCardAccess;
  final String authenticating;
  final String readingPassportData;
  final String cancelledByUser;
  final String performingSecurityVerification;
  final String completedSuccessfully;
  final String timeoutWaitingForTag;
  final String failedToInitiateSession;
  final String tagLostTryAgain;
  final String Function(double) progressFormatter;

  const IosNfcMessages({
    required this.progressFormatter,
    required this.holdNearPhotoPage,
    required this.cancelling,
    required this.cancelled,
    required this.connecting,
    required this.readingCardAccess,
    required this.authenticating,
    required this.readingPassportData,
    required this.cancelledByUser,
    required this.performingSecurityVerification,
    required this.completedSuccessfully,
    required this.timeoutWaitingForTag,
    required this.failedToInitiateSession,
    required this.tagLostTryAgain,
  });
}

double progressForState(PassportReaderState state) {
  return switch (state) {
    PassportReaderPending() => 0.0,
    PassportReaderCancelled() => 0.0,
    PassportReaderCancelling() => 0.0,
    PassportReaderFailed() => 0.0,
    PassportReaderConnecting() => 0.0,
    PassportReaderReadingCardAccess() => 0.1,
    PassportReaderAuthenticating() => 0.4,
    PassportReaderReadingPassportData(:final progress) => 0.5 + progress / 2.0,
    PassportReaderSecurityVerification() => 0.9,
    PassportReaderSuccess() => 1.0,
    _ => throw Exception('unexpected state: $state'),
  };
}
