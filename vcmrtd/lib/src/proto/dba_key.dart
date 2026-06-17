//  Created by Crt Vavros, copyright © 2022 ZeroPass. All rights reserved.
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:vcmrtd/extensions.dart';
import 'package:logging/logging.dart';
import 'package:vcmrtd/internal.dart';

import '../lds/asn1ObjectIdentifiers.dart';
import '../lds/mrz.dart';
import 'access_key.dart';

const SEED_LEN_BAC = 16;
const SEED_LEN_PACE = 20; //uncut

// BapKey works similar to DBA as a BacKey, with a different document key input and seed
class BapKey extends AccessKey implements BacKey {
  late final Uint8List _seed;

  BapKey(String seedInput) {
    final hash = sha1.convert(latin1.encode(seedInput));
    _seed = Uint8List.fromList(hash.bytes.sublist(0, 16));
  }

  @override
  Uint8List get encKey => DeriveKey.desEDE(_seed);

  @override
  Uint8List get macKey => DeriveKey.iso9797MacAlg3(_seed);

  @override
  String toString() => "BapKey(seed=${_seed.hex()})";
}

/// Class defines Document Basic Access Keys as specified in section 9.7.2 of doc ICAO 9303 p11
/// which are used to establish secure messaging session via BAC protocol.
/// DBAKey through the PaceKey class and the Kpi function creates keys for PACE protocol as well
class DBAKey extends PaceKey implements BacKey {
  static final _log = Logger("AccessKey.DBAKeys");

  // described in ICAO 9303 p11 - 4.4.4.1 MSE:Set AT - Reference of a public key / secret key
  @override
  int PACE_REF_KEY_TAG = 0x01; //MRZ

  late String _mrtdNum;
  late String _dob;
  late String _doe;
  Uint8List? _cachedSeed;
  late int seedLen;

  /// Constructs [DBAKey] using passport number [mrtdNumber],
  /// passport owner's [dateOfBirth] and passport [dateOfExpiry].
  DBAKey(String mrtdNumber, DateTime dateOfBirth, DateTime dateOfExpiry, {bool paceMode = false}) {
    _mrtdNum = mrtdNumber;
    _dob = dateOfBirth.formatYYMMDD();
    _doe = dateOfExpiry.formatYYMMDD();
    seedLen = paceMode ? SEED_LEN_PACE : SEED_LEN_BAC;
  }

  /// Constructs [DBAKey] from [mrz].
  factory DBAKey.fromMRZ(PassportMRZ mrz) {
    return DBAKey(mrz.documentNumber, mrz.dateOfBirth, mrz.dateOfExpiry);
  }

  /// Returns encryption key [Kenc] to be used in BAC or PACE protocol.
  Uint8List get encKey {
    return DeriveKey.desEDE(keySeed);
  }

  /// Returns MAC key [Kmac] to be used in BAC or PACE protocol.
  Uint8List get macKey {
    return DeriveKey.iso9797MacAlg3(keySeed);
  }

  /// Returns K-pi [kpi] to be used in PACE protocol.
  @override
  Uint8List Kpi(CipherAlgorithm cipherAlgorithm, KEY_LENGTH keyLength) {
    _log.debug("Calculating K-pi key ...");
    _log.sdDebug(
      "Seed: ${keySeed.hex()}, "
      "Key length: $keyLength, "
      "Cipher algorithm: $cipherAlgorithm",
    );

    if (cipherAlgorithm == CipherAlgorithm.DESede) {
      return DeriveKey.desEDE(keySeed, paceMode: true);
    } else if (cipherAlgorithm == CipherAlgorithm.AES && keyLength == KEY_LENGTH.s128) {
      return DeriveKey.aes128(keySeed, paceMode: true);
    } else if (cipherAlgorithm == CipherAlgorithm.AES && keyLength == KEY_LENGTH.s192) {
      return DeriveKey.aes192(keySeed, paceMode: true);
    } else if (cipherAlgorithm == CipherAlgorithm.AES && keyLength == KEY_LENGTH.s256) {
      return DeriveKey.aes256(keySeed, paceMode: true);
    } else {
      throw ArgumentError.value(cipherAlgorithm, null, "CanKeys; Unsupported cipher algorithm");
    }
  }

  /// Returns Kseed as specified in Appendix D.2
  /// to the Part 11 of doc ICAO 9303 p11
  Uint8List get keySeed {
    if (_cachedSeed == null) {
      final paddedMrtdNum = _mrtdNum.padRight(9, '<');
      final cdn = PassportMRZ.calculateCheckDigit(paddedMrtdNum);
      final cdb = PassportMRZ.calculateCheckDigit(_dob);
      final cde = PassportMRZ.calculateCheckDigit(_doe);

      final kmrz = "$paddedMrtdNum$cdn$_dob$cdb$_doe$cde";
      final hash = sha1.convert(kmrz.codeUnits);
      //do not cut seed for PACE
      _cachedSeed = hash.bytes.sublist(0, seedLen) as Uint8List?;
    }
    return _cachedSeed!;
  }

  /// Returns passport number used for calculating key seed.
  String get mrtdNumber => _mrtdNum;

  /// Returns passport owner's date of birth used for calculating key seed.
  DateTime get dateOfBirth => _dob.parseDateYYMMDD(futureDate: false);

  /// Returns passport date of expiry used for calculating key seed.
  DateTime get dateOfExpiry => _doe.parseDateYYMMDD(futureDate: true);

  /// Very sensitive data. Do not use in production!
  @override
  String toString() {
    _log.warning("DBAKeys.toString() called. This is very sensitive data. Do not use in production!");
    return "DBAKeys{mrtdNumber: $_mrtdNum, dateOfBirth: $_dob, dateOfExpiry: $_doe}. "
        "Is paceMode: ${seedLen == SEED_LEN_PACE}, "
        "Key seed: ${keySeed.hex()}, "
        "Enc key: ${encKey.hex()}, "
        "Mac key: ${macKey.hex()}.";
  }
}
