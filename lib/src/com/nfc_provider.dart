// Created by Crt Vavros, copyright © 2022 ZeroPass. All rights reserved.
import 'dart:io';
import 'dart:typed_data';
import 'package:dmrtd/dmrtd.dart';
import 'package:dmrtd/extensions.dart';
import 'package:logging/logging.dart';
import 'package:flutter/services.dart';

import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';


enum NfcStatus { notSupported, disabled, enabled }

class NfcProviderError extends ComProviderError {
  NfcProviderError([String message = ""]) : super(message);
  NfcProviderError.fromException(Exception e) : super(e.toString());

  @override
  String toString() => 'NfcProviderError: $message';
}

class NfcProvider extends ComProvider {
  static final _log = Logger('nfc.provider');

  Duration timeout = const Duration(seconds: 10); /// [Android] Default timeout.
  NfcProvider() : super(_log);

  NFCTag? _tag;

  /// On iOS, sets NFC reader session alert message.
  Future<void> setIosAlertMessage(String message) async {
    if (Platform.isIOS) {
      _log.fine('iOS alert message: ' + message);
      return await FlutterNfcKit.setIosAlertMessage(message);
    }
  }

  static Future<NfcStatus> get nfcStatus async {
    NFCAvailability a = await FlutterNfcKit.nfcAvailability;
    _log.fine('NFC availability: ' + a.toString());
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
      final Duration effTimeout = timeout ?? this.timeout;
      _log.info('Starting NFC poll (timeout=${effTimeout.inSeconds}s, iOS msg="$iosAlertMessage")');
      _tag = await FlutterNfcKit.poll(
        timeout: effTimeout,
        iosAlertMessage: iosAlertMessage,
        readIso14443A: true,
        readIso14443B: true,
        readIso18092: false,
        readIso15693: false);
      if (_tag!.type != NFCTagType.iso7816) {
        _log.info("Ignoring non ISO-7816 tag: ${_tag!.type}");
        return await disconnect();
      }
      _log.info('NFC tag connected: type=${_tag!.type}');
    } on Exception catch (e) {
      if (e is PlatformException) {
        _log.severe('NFC connect PlatformException code=${e.code} message=${e.message} details=${e.details}');
        throw NfcProviderError('PlatformException(code=${e.code}, message=${e.message}, details=${e.details})');
      }
      _log.severe('NFC connect exception: ' + e.toString());
      throw NfcProviderError.fromException(e);
    }
  }

  @override
  Future<void> disconnect(
      {String? iosAlertMessage, String? iosErrorMessage}) async {
    if (isConnected()) {
      _log.debug("Disconnecting");
      try {
        _tag = null;
        _log.fine('Finishing NFC session (iosAlertMessage=$iosAlertMessage, iosErrorMessage=$iosErrorMessage)');
        return await FlutterNfcKit.finish(
          iosAlertMessage: iosAlertMessage, iosErrorMessage: iosErrorMessage);
      } on Exception catch(e) {
        if (e is PlatformException) {
          _log.warning('NFC finish PlatformException code=${e.code} message=${e.message} details=${e.details}');
          throw NfcProviderError('PlatformException(code=${e.code}, message=${e.message}, details=${e.details})');
        }
        _log.warning('NFC finish exception: ' + e.toString());
        throw NfcProviderError.fromException(e);
      }
    }
  }

  @override
  bool isConnected() {
    return _tag != null;
  }

  @override
  Future<Uint8List> transceive(final Uint8List data,
      {Duration? timeout}) async {
    try {
      final Duration effTimeout = timeout ?? this.timeout;
      final String apdu = data.hex();
      final String apduShort = apdu.length > 64 ? apdu.substring(0, 64) + '…' : apdu;
      _log.finer('APDU >> (${data.length} bytes, timeout=${effTimeout.inSeconds}s): $apduShort');
      final Uint8List rsp = await FlutterNfcKit.transceive(data, timeout: effTimeout);
      final String rspHex = rsp.hex();
      final String rspShort = rspHex.length > 64 ? rspHex.substring(0, 64) + '…' : rspHex;
      _log.finer('APDU << (${rsp.length} bytes): $rspShort');
      return rsp;
    } on Exception catch(e) {
      if (e is PlatformException) {
        _log.severe('APDU PlatformException code=${e.code} message=${e.message} details=${e.details}');
        throw NfcProviderError('PlatformException(code=${e.code}, message=${e.message}, details=${e.details})');
      }
      _log.severe('APDU exception: ' + e.toString());
      throw NfcProviderError.fromException(e);
    }
  }
}
