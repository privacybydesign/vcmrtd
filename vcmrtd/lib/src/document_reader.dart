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

class DocumentReader<DocType extends DocumentData> extends Notifier<DocumentReaderState> {
  final DocumentReaderConfig config;
  final DocumentParser<DocType> documentParser;
  final DataGroupReader dataGroupReader;
  final NfcProvider nfc;

  bool _isCancelled = false;
  List<String> _log = [];
  List<String> _sensitiveLog = [];
  IosNfcMessageMapper? _iosNfcMessageMapper;

  // Files already successfully read on a prior *failed* attempt at this
  // document (map key is the data group name, e.g. "DG2"). If readDocument()
  // previously exhausted its retries on, say, DG14 after DG1-DG13 had already
  // been read, retrying should not pay for re-reading DG1-DG13 again.
  // reset() intentionally leaves these caches alone - it is only ever called
  // to retry the same, still-incomplete document. They are cleared as soon
  // as a read completes successfully (see the end of readDocument()), since
  // at that point there is nothing left to resume and the next
  // readDocument() call - on the same reader instance, whether for the same
  // document scanned again or a different one - must start fresh.
  final Map<String, String> _dataGroups = {};
  bool _efComRead = false;
  bool _efSodRead = false;

  DocumentReader({
    required this.documentParser,
    required this.dataGroupReader,
    required this.nfc,
    required this.config,
  });

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

  String getSensitiveLogs() {
    return '- ${_sensitiveLog.join('\n-')}';
  }

  void reset() {
    _isCancelled = false;
    state = DocumentReaderPending();
  }

  Future<void> cancel() async {
    _isCancelled = true;
    // Aborts an in-flight poll/transceive immediately instead of leaving the
    // cancel flag to be noticed only at the next _reconnectionLoop iteration
    // boundary - without this, cancelling while nfc.connect() is blocked
    // waiting for a tag has no visible effect until that poll times out on
    // its own.
    await nfc.forceCleanup();
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
    try {
      await _reconnectionLoop(
        authMethod: _AuthMethod.none,
        whenConnected: () async {
          if (!nfc.isConnected()) {
            await nfc.connect(iosAlertMessage: iosNfcMessages(DocumentReaderConnecting()));
          }
        },
      );
      if (state is DocumentReaderCancelled) return null;
    } catch (e) {
      // Previously this initial connect() call was unwrapped, so a timeout
      // waiting for a tag (e.g. common with driving licences) threw straight
      // out of readDocument() uncaught, past every state transition below -
      // the caller's generic catch swallowed it with just a debugPrint,
      // leaving the UI frozen on "Connecting" forever with no retry option.
      await _failure('Failure connecting to document', e);
      return null;
    }

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
        await _failure('Failure reading Ef.CardAccess', e);
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
        await _failure('Failure authenticating with PACE', e);
        return null;
      }
    }

    if (!_efComRead) {
      _setState(DocumentReaderReadingCOM());
      try {
        await _reconnectionLoop(
          authMethod: method,
          whenConnected: () async => documentParser.parseEfCOM(await dataGroupReader.readEfCOM()),
        );
        if (state is DocumentReaderCancelled) return null;
        _efComRead = true;
      } catch (e) {
        await _failure('Failure reading Ef.COM', e);
        return null;
      }
    }

    // isMandatory: DG1, DG2 are mandatory; DG15 is mandatory if provided
    for (final (dataGroup, read, parse, progress, isMandatory) in [
      (DataGroups.dg1, dataGroupReader.readDG1, documentParser.parseDG1, 0.1, true),
      (DataGroups.dg2, dataGroupReader.readDG2, documentParser.parseDG2, 0.2, true),
      (DataGroups.dg3, dataGroupReader.readDG3, documentParser.parseDG3, 0.3, false),
      (DataGroups.dg4, dataGroupReader.readDG4, documentParser.parseDG4, 0.35, false),
      (DataGroups.dg5, dataGroupReader.readDG5, documentParser.parseDG5, 0.4, false),
      (DataGroups.dg6, dataGroupReader.readDG6, documentParser.parseDG6, 0.5, false),
      (DataGroups.dg7, dataGroupReader.readDG7, documentParser.parseDG7, 0.6, false),
      (DataGroups.dg8, dataGroupReader.readDG8, documentParser.parseDG8, 0.7, false),
      (DataGroups.dg9, dataGroupReader.readDG9, documentParser.parseDG9, 0.75, false),
      (DataGroups.dg10, dataGroupReader.readDG10, documentParser.parseDG10, 0.8, false),
      (DataGroups.dg11, dataGroupReader.readDG11, documentParser.parseDG11, 0.85, false),
      (DataGroups.dg12, dataGroupReader.readDG12, documentParser.parseDG12, 0.9, false),
      (DataGroups.dg13, dataGroupReader.readDG13, documentParser.parseDG13, 0.9, false),
      (DataGroups.dg14, dataGroupReader.readDG14, documentParser.parseDG14, 0.95, false),
      (DataGroups.dg15, dataGroupReader.readDG15, documentParser.parseDG15, 0.9, true),
      (DataGroups.dg16, dataGroupReader.readDG16, documentParser.parseDG16, 1.0, false),
    ]) {
      if (!(config.shouldRead(dataGroup) && documentParser.documentContainsDataGroup(dataGroup))) {
        continue;
      }

      final dgName = dataGroup.getName();
      if (_dataGroups.containsKey(dgName)) {
        // Already read (and parsed) successfully on a prior attempt; a
        // retry after a later DG failed should not pay to re-fetch this one.
        continue;
      }

      _setState(DocumentReaderReadingDataGroup(dataGroup: dgName, progress: progress));
      Uint8List? bytes;

      // First, read the bytes from the chip
      try {
        await _reconnectionLoop(
          authMethod: method,
          whenConnected: () async {
            bytes = await read();
            final hexData = bytes!.hex();
            if (hexData.isNotEmpty) {
              _dataGroups[dgName] = hexData;
            }
          },
        );
        if (state is DocumentReaderCancelled) {
          return null;
        }
      } catch (e) {
        // _reconnectionLoop only reaches here by rethrowing after exhausting
        // its retries (a cancellation returns via _setToCancelState() above
        // instead of throwing), so this is a genuine, persistent read
        // failure. Optional DGs are already allowed to fail to parse without
        // aborting the whole document (below) - a DG that can't be read at
        // all deserves the same treatment, not a harder failure mode.
        if (isMandatory) {
          await _failure('Failure reading data group $dataGroup', e);
          return null;
        }
        _addLog('Failed to read optional data group $dataGroup: $e');
        continue;
      }

      // Then, parse the bytes (can fail for optional DGs)
      if (bytes != null) {
        try {
          parse(bytes!);
        } catch (e) {
          if (isMandatory) {
            await _failure('Failure parsing mandatory data group $dataGroup', e);
            return null;
          } else {
            _addLog('Failed to parse optional data group $dataGroup: $e');
          }
        }
      }
    }

    if (!_efSodRead) {
      _setState(DocumentReaderReadingSOD());
      try {
        await _reconnectionLoop(
          authMethod: method,
          whenConnected: () async => documentParser.parseEfSOD(await dataGroupReader.readEfSOD()),
        );
        if (state is DocumentReaderCancelled) {
          return null;
        }
        _efSodRead = true;
      } catch (e) {
        await _failure('Failure reading SOD', e);
        return null;
      }
    }

    Uint8List? aaSig;
    // Active Authentication proves the chip holds the private key matching the
    // AA public key stored on the chip (DG15 for passports/ID cards, DG13 for
    // driving licences). If the chip carries no such key there is nothing to
    // challenge, so attempting it makes the chip reply 6A88 "referenced data
    // not found" (or 6D00/6A81). This is common for documents that rely on
    // Chip Authentication (EAC) instead of AA, e.g. many UK passports. Only
    // attempt AA when the AA key is actually present; the issuer accepts a
    // missing AA signature for such documents (passive authentication of the
    // SOD still applies).
    final chipSupportsAA = documentParser.documentSupportsActiveAuthentication();
    if (activeAuthenticationParams != null && !chipSupportsAA) {
      _addLog("Skipping Active Authentication: AA public key not present on chip");
    }
    if (activeAuthenticationParams != null && chipSupportsAA) {
      _setState(DocumentReaderActiveAuthentication());
      try {
        await _reconnectionLoop(
          authMethod: method,
          whenConnected: () async {
            try {
              aaSig = await dataGroupReader.activeAuthenticate(stringToUint8List(activeAuthenticationParams.nonce));
            } on DocumentError catch (e) {
              // Some chips advertise no usable AA key and reject the command
              // outright. Treat these "not supported" status words as AA being
              // unavailable and skip, rather than failing the whole read.
              if (e.code == StatusWord.invalidInstructionCode || // 6D00
                  e.code == StatusWord.referencedDataNotFound || // 6A88
                  e.code == StatusWord.notSupported) {
                // 6A81
                _addLog("Active Authentication not supported by chip (${e.code}), skipping");
                return;
              }
              rethrow;
            }
          },
        );
        if (state is DocumentReaderCancelled) {
          return null;
        }
      } catch (e) {
        await _failure('Failure active authentication', e);
        return null;
      }
    }

    _setState(DocumentReaderSuccess());

    await nfc.disconnect();

    final document = documentParser.createDocument();
    final result = RawDocumentData(
      dataGroups: Map<String, String>.from(_dataGroups),
      efSod: documentParser.sod.toBytes().hex(),
      sessionId: activeAuthenticationParams?.sessionId,
      nonce: activeAuthenticationParams != null ? stringToUint8List(activeAuthenticationParams.nonce) : null,
      aaSignature: aaSig,
    );

    // The read completed fully: there is nothing left to resume, so the
    // cross-attempt caches above must not leak into whatever readDocument()
    // call comes next - otherwise a second read (of the same or a different
    // document, on a reused reader instance) would see these DGs/EF.COM/
    // EF.SOD as "already read" and skip reading the chip almost entirely.
    _dataGroups.clear();
    _efComRead = false;
    _efSodRead = false;

    return (document, result);
  }

  Future<void> _setToCancelState() async {
    await _setState(DocumentReaderCancelling());
    await nfc.disconnect();
    if (!ref.mounted) {
      return;
    }
    await _setState(DocumentReaderCancelled());
  }

  bool _isCancelException(Exception e) {
    return e.toString().toLowerCase().contains('session invalidated');
  }

  Future<void> _retryConnection() async {
    dataGroupReader.reset();
    if (Platform.isIOS) {
      if (nfc.isConnected()) {
        await nfc.reconnect().timeout(Duration(seconds: 2));
      } else {
        await nfc.connect().timeout(Duration(seconds: 10));
      }
    } else {
      // On Android, always force-finish the plugin session before re-polling.
      // After a TagLostException the Dart timeout may cancel poll() while the
      // plugin still holds a stale IsoDep; calling forceCleanup() prevents
      // subsequent connect/transceive calls from failing with IOException.
      await nfc.forceCleanup();
      await nfc.connect().timeout(Duration(seconds: 10));
    }
  }

  Future<void> _reconnectionLoop({
    required _AuthMethod authMethod,
    required Function whenConnected,
    int numAttempts = 5,
  }) async {
    for (int i = 1; i <= numAttempts; ++i) {
      if (!ref.mounted) {
        return;
      }
      if (_isCancelled) {
        return await _setToCancelState();
      }
      try {
        await whenConnected();
        return;
      } on Exception catch (e) {
        // Check for cancellation before giving up on attempt count, so a
        // cancel on the very last attempt is still reported as Cancelled
        // rather than as a generic failure.
        if (_isCancelled || _isCancelException(e)) {
          return await _setToCancelState();
        }
        if (i >= numAttempts) {
          _addLog('Rethrow on attempt $i');
          rethrow;
        }
        // Surface the connection loss to the UI immediately, rather than only
        // after every retry has been exhausted - a silent retry loop looks
        // identical to a healthy read in progress, so the user has no signal
        // to reposition the document until it's too late to matter.
        await _setReconnecting();
        await Future.delayed(const Duration(milliseconds: 300));
        _addLog('Retry $i (Reason: $e)');
        try {
          await _retryConnection();
        } catch (e2) {
          // _retryConnection() re-polls for the tag, which on iOS/Android
          // shows the NFC prompt again. If the user (or the OS) cancels
          // *that* prompt, the resulting exception must not be silently
          // discarded here - it needs the same cancellation check as the
          // original error above.
          _addLog('Retry connection failed: $e2');
          if (_isCancelled || (e2 is Exception && _isCancelException(e2))) {
            return await _setToCancelState();
          }
          // Reconnect didn't succeed for a non-cancel reason; there is no
          // live connection to re-authenticate against yet, so move on to
          // the next attempt instead of calling startSession/startSessionPACE.
          continue;
        }

        if (authMethod != _AuthMethod.none) {
          try {
            authMethod == _AuthMethod.bac
                ? await dataGroupReader.startSession()
                : await dataGroupReader.startSessionPACE(documentParser.cardAccess);
          } catch (e3) {
            _addLog('Retry authenticate failed: $e3');
            if (_isCancelled || (e3 is Exception && _isCancelException(e3))) {
              return await _setToCancelState();
            }
          }
        }
      }
    }
  }

  /// Marks the read as transiently reconnecting after a retryable error
  /// (e.g. tag lost), without losing track of the step the read was actually
  /// on - unwraps an already-reconnecting state instead of nesting, so
  /// repeated retries within the same step don't pile up wrapper layers.
  Future<void> _setReconnecting() async {
    final current = state;
    final previousState = current is DocumentReaderReconnecting ? current.previousState : current;
    await _setState(DocumentReaderReconnecting(previousState));
  }

  Future<void> _setState(DocumentReaderState s) async {
    if (!ref.mounted) {
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
    _addNonSensitiveLog(log);
    _addSensitiveLog(log);
  }

  void _addNonSensitiveLog(String log) {
    _log.add(log);
    debugPrint(log);
  }

  void _addSensitiveLog(String log) {
    _sensitiveLog.add(log);
  }

  Future<void> _initRead(IosNfcMessageMapper mapper) async {
    _log = [];
    _sensitiveLog = [];
    _iosNfcMessageMapper = mapper;
    _isCancelled = false;
    await checkNfcAvailability();
    if (state is! DocumentReaderNfcUnavailable && nfc.isConnected()) {
      await nfc.disconnect();
    }
  }

  Future<void> _failure(String context, Object latestError) async {
    _addNonSensitiveLog("$context: $latestError");

    if (latestError is SensitiveException) {
      _addSensitiveLog("$context: ${latestError.logWithSensitiveData()}");
    } else {
      _addSensitiveLog("$context: $latestError");
    }

    final logs = getLogs();
    final sensitiveLogs = getSensitiveLogs();

    state = DocumentReaderFailed(error: DocumentReadingError.unknown, logs: logs, sensitiveLogs: sensitiveLogs);
    await nfc.disconnect();
  }

  @override
  DocumentReaderState build() {
    checkNfcAvailability();
    ref.onDispose(cancel);
    return DocumentReaderPending();
  }
}

class DocumentReaderState {}

class DocumentReaderNfcUnavailable extends DocumentReaderState {}

class DocumentReaderPending extends DocumentReaderState {}

class DocumentReaderCancelled extends DocumentReaderState {}

class DocumentReaderCancelling extends DocumentReaderState {}

class DocumentReaderFailed extends DocumentReaderState {
  DocumentReaderFailed({required this.error, required this.logs, required this.sensitiveLogs});

  final String logs;
  final String sensitiveLogs;
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

/// Set while a retryable error (e.g. tag lost, connection drop) is being
/// retried internally, before the retry budget is exhausted. [previousState]
/// is the step the read was on when the connection dropped, so UI progress
/// indicators can keep showing it - only the tip/message shown to the user
/// needs to change, e.g. to ask them to reposition the document.
class DocumentReaderReconnecting extends DocumentReaderState {
  DocumentReaderReconnecting(this.previousState);
  final DocumentReaderState previousState;
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
    DocumentReaderReconnecting(:final previousState) => progressForState(previousState),
    DocumentReaderActiveAuthentication() => 0.9,
    DocumentReaderSuccess() => 1.0,
    _ => throw Exception('unexpected state: $state'),
  };
}
