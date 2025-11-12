//  Created by Nejc Skerjanc, copyright © 2023 ZeroPass. All rights reserved.

import 'dart:typed_data';
import 'package:vcmrtd/src/lds/asn1ObjectIdentifiers.dart';
import 'package:logging/logging.dart';
import 'package:vcmrtd/extensions.dart';
import 'package:vcmrtd/src/types/document_type.dart';

import '../crypto/kdf.dart';
import 'access_key.dart';

class CanKeysError implements Exception {
  final String message;
  CanKeysError(this.message);
  @override
  String toString() => message;
}

/// Class defines Document Basic Access Keys as specified in section 9.7.2 of doc ICAO 9303 p11
/// which are used to establish secure messaging session via BAC protocol.
class CanKey extends PaceKey {
  static final _log = Logger("PaceKey.CanKeys");
  // described in ICAO 9303 p11 - 4.4.4.1 MSE:Set AT - Reference of a public key / secret key
  @override
  int PACE_REF_KEY_TAG = 0x02; //CAN

  late Uint8List _can;

  /// Constructs [CanKey] using document specific CAN key string [Uint8List].
  CanKey(String canNumber, DocumentType docType) {
    //docs https://www.icao.int/Meetings/TAG-MRTD/Documents/Tag-Mrtd-20/TagMrtd-20_WP020_en.pdf
    //3.1.6 CAN is 6 digits long for passports but 10 character document number for driving licences
    // Therefore we need the the document type to determine the regex
    final RegExp passportRegex = RegExp(r'^\d{6}$');
    final RegExp drivingRegex = RegExp(r'^[A-Z0-9]{10}$');
    late int canLength;

    if (docType == DocumentType.passport) {
      if (!passportRegex.hasMatch(canNumber)) {
        throw CanKeysError("PaceKey.CanKeys; Code must be exactly 6 digits and only contain numbers for passports.");
      }
      canLength = 6;
    }

    if (docType == DocumentType.driverLicense) {
      if (!drivingRegex.hasMatch(canNumber)) {
        throw CanKeysError(
          "PaceKey.CanKeys; Code must be exactly 10 character capital alphanumerics for driving licences.",
        );
      }
      canLength = 10;
    }

    Uint8List canNumberBytes = Uint8List(canLength);
    for (int i = 0; i < canLength; i++) {
      canNumberBytes[i] = canNumber.codeUnitAt(i);
    }

    _can = canNumberBytes;
  }

  /// Returns K-pi [kpi] to be used in PACE protocol.
  @override
  Uint8List Kpi(CipherAlgorithm cipherAlgorithm, KEY_LENGTH keyLength) {
    if (cipherAlgorithm == CipherAlgorithm.DESede) {
      //_cachedSeed = KDF(sha1, _can, Int32(3)).sublist(0, seedLen);
      return DeriveKey.desEDE(_can, paceMode: true);
    } else if (cipherAlgorithm == CipherAlgorithm.AES && keyLength == KEY_LENGTH.s128) {
      return DeriveKey.aes128(_can, paceMode: true);
    } else if (cipherAlgorithm == CipherAlgorithm.AES && keyLength == KEY_LENGTH.s192) {
      return DeriveKey.aes192(_can, paceMode: true);
    } else if (cipherAlgorithm == CipherAlgorithm.AES && keyLength == KEY_LENGTH.s256) {
      return DeriveKey.aes256(_can, paceMode: true);
    } else {
      throw ArgumentError.value(cipherAlgorithm, null, "CanKeys; Unsupported cipher algorithm");
    }
  }

  /// Returns passport number used for calculating key seed.
  Uint8List get can => _can;

  @override
  String toString() {
    _log.warning("CanKeys.toString() called. This is very sensitive data. Do not use in production!");
    return "CanKeys; CAN: ${_can.hex()}";
  }
}
