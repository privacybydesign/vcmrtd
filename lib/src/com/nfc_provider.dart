// Created by Crt Vavros, copyright © 2022 ZeroPass. All rights reserved.
import 'dart:io';
import 'dart:typed_data';
import 'package:vcmrtd/vcmrtd.dart';
import 'package:vcmrtd/extensions.dart';
import 'package:logging/logging.dart';

import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';


enum NfcStatus { notSupported, disabled, enabled }

class NfcProviderError extends ComProviderError {
  NfcProviderError([String message = ""]) : super(message);
  NfcProviderError.fromException(Exception e) : super(e.toString());

  @override
  String toString() => 'NfcProviderError: $message';

  /// Returns true if this error type is potentially recoverable with a retry.
  bool isRetryable() {
    return this is NfcConnectionLost ||
           this is NfcTimeout ||
           this is NfcTransientError;
  }
}

/// Error indicating NFC connection was lost during communication.
/// This is typically recoverable by reconnecting.
class NfcConnectionLost extends NfcProviderError {
  NfcConnectionLost([String message = "NFC connection lost"]) : super(message);

  @override
  String toString() => 'NfcConnectionLost: $message';
}

/// Error indicating an NFC operation timed out.
/// This is typically recoverable by retrying with a longer timeout.
class NfcTimeout extends NfcProviderError {
  NfcTimeout([String message = "NFC operation timed out"]) : super(message);

  @override
  String toString() => 'NfcTimeout: $message';
}

/// Error indicating the NFC tag/card type is invalid or incompatible.
/// This is NOT recoverable as the card is not an ISO-7816 passport.
class NfcInvalidCard extends NfcProviderError {
  NfcInvalidCard([String message = "Invalid or incompatible NFC card"]) : super(message);

  @override
  String toString() => 'NfcInvalidCard: $message';

  @override
  bool isRetryable() => false;
}

/// Error indicating a transient NFC error (interference, temporary signal loss).
/// This is recoverable by retrying.
class NfcTransientError extends NfcProviderError {
  NfcTransientError([String message = "Transient NFC error"]) : super(message);

  @override
  String toString() => 'NfcTransientError: $message';
}

class NfcProvider extends ComProvider {
  static final _log = Logger('nfc.provider');

  /// Platform-specific timeout. iOS needs longer timeout due to session behavior.
  Duration timeout = Platform.isIOS
      ? const Duration(seconds: 20)
      : const Duration(seconds: 10);

  /// Maximum number of automatic retry attempts for transient errors.
  int maxRetries = 2;

  NfcProvider() : super(_log);

  NFCTag? _tag;
  DateTime? _lastConnectionTime;

  /// On iOS, sets NFC reader session alert message.
  Future<void> setIosAlertMessage(String message) async {
    if (Platform.isIOS) {
      return await FlutterNfcKit.setIosAlertMessage(message);
    }
  }

  static Future<NfcStatus> get nfcStatus async {
    NFCAvailability a = await FlutterNfcKit.nfcAvailability;
    switch (a) {
      case NFCAvailability.disabled:
        return NfcStatus.disabled;
      case NFCAvailability.available:
        return NfcStatus.enabled;
      default:
        return NfcStatus.notSupported;
    }
  }

  @override
  Future<void> connect({Duration? timeout, String iosAlertMessage = "Hold your iPhone near the biometric Passport"}) async {
    if (isConnected()) {
      return;
    }

    try {
      _tag = await FlutterNfcKit.poll(
        timeout: timeout ?? this.timeout,
        iosAlertMessage: iosAlertMessage,
        readIso14443A: true,
        readIso14443B: true,
        readIso18092: false,
        readIso15693: false);
      if (_tag!.type != NFCTagType.iso7816) {
        _log.info("Ignoring non ISO-7816 tag: ${_tag!.type}");
        await disconnect();
        throw NfcInvalidCard("Detected ${_tag!.type} tag, but ISO-7816 required");
      }
      _lastConnectionTime = DateTime.now();
      notifyConnected();
    } on Exception catch (e) {
      _tag = null;
      throw _classifyError(e);
    }
  }

  @override
  Future<void> disconnect(
      {String? iosAlertMessage, String? iosErrorMessage}) async {
    if (isConnected()) {
      _log.debug("Disconnecting");
      try {
        _tag = null;
        _lastConnectionTime = null;
        notifyDisconnected();
        return await FlutterNfcKit.finish(
          iosAlertMessage: iosAlertMessage, iosErrorMessage: iosErrorMessage);
      } on Exception catch(e) {
        throw _classifyError(e);
      }
    }
  }

  @override
  bool isConnected() {
    return _tag != null;
  }

  /// Validates connection health by checking if tag is present and connection is recent.
  /// Returns true if connection appears healthy, false otherwise.
  bool validateConnection() {
    if (!isConnected()) {
      return false;
    }

    // Check if connection is stale (older than 2 minutes)
    if (_lastConnectionTime != null) {
      final connectionAge = DateTime.now().difference(_lastConnectionTime!);
      if (connectionAge > const Duration(minutes: 2)) {
        _log.warning("Connection appears stale (age: ${connectionAge.inSeconds}s)");
        return false;
      }
    }

    return true;
  }

  @override
  Future<Uint8List> transceive(final Uint8List data,
      {Duration? timeout}) async {
    if (!isConnected()) {
      throw NfcConnectionLost("Not connected to NFC tag");
    }

    return await _transceiveWithRetry(data, timeout: timeout, retryCount: 0);
  }

  /// Internal method that performs transceive with automatic retry logic.
  Future<Uint8List> _transceiveWithRetry(final Uint8List data,
      {Duration? timeout, required int retryCount}) async {
    try {
      final result = await FlutterNfcKit.transceive(data, timeout: timeout ?? this.timeout);
      return result;
    } on Exception catch (e) {
      final classifiedError = _classifyError(e);

      // Mark connection as lost on certain errors
      if (classifiedError is NfcConnectionLost) {
        _tag = null;
        _lastConnectionTime = null;
        notifyDisconnected();
      }

      // Retry logic for retryable errors
      if (classifiedError.isRetryable() && retryCount < maxRetries) {
        _log.warning("Transceive failed (attempt ${retryCount + 1}/$maxRetries): $classifiedError");

        // Exponential backoff: 100ms, 200ms, 400ms...
        final delayMs = 100 * (1 << retryCount);
        await Future.delayed(Duration(milliseconds: delayMs));

        // For timeout errors, increase timeout on retry
        Duration? retryTimeout = timeout ?? this.timeout;
        if (classifiedError is NfcTimeout) {
          retryTimeout = Duration(milliseconds: (retryTimeout.inMilliseconds * 1.5).round());
          _log.info("Increasing timeout to ${retryTimeout.inMilliseconds}ms for retry");
        }

        return await _transceiveWithRetry(data,
            timeout: retryTimeout, retryCount: retryCount + 1);
      }

      // If not retryable or max retries exceeded, throw the error
      throw classifiedError;
    }
  }

  /// Classifies exceptions into specific NfcProviderError types for better error handling.
  NfcProviderError _classifyError(Exception e) {
    final errorMsg = e.toString().toLowerCase();

    // Check for connection lost errors
    if (errorMsg.contains('tag was lost') ||
        errorMsg.contains('tag connection lost') ||
        errorMsg.contains('nfc tag has been lost') ||
        errorMsg.contains('connection lost')) {
      return NfcConnectionLost(e.toString());
    }

    // Check for timeout errors
    if (errorMsg.contains('timeout') ||
        errorMsg.contains('timed out')) {
      return NfcTimeout(e.toString());
    }

    // Check for user cancellation (not retryable, but not really an error either)
    if (errorMsg.contains('invalidated by user') ||
        errorMsg.contains('user canceled') ||
        errorMsg.contains('session invalidated')) {
      return NfcProviderError(e.toString());
    }

    // Check for transient/interference errors
    if (errorMsg.contains('transceive failed') ||
        errorMsg.contains('communication error') ||
        errorMsg.contains('rf communication error')) {
      return NfcTransientError(e.toString());
    }

    // Default to generic error
    return NfcProviderError.fromException(e);
  }
}
