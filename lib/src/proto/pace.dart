//  Created by Nejc Skerjanc, copyright © 2023 ZeroPass. All rights reserved.
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:vcmrtd/extensions.dart';
import 'package:pointycastle/asn1/primitives/asn1_sequence.dart';
import 'package:vcmrtd/src/lds/asn1ObjectIdentifiers.dart';
import 'package:vcmrtd/src/proto/public_key_pace.dart';
import 'package:vcmrtd/src/crypto/kdf.dart';
import 'package:vcmrtd/src/crypto/aes.dart';
import 'package:vcmrtd/src/crypto/iso9797.dart';
import 'package:vcmrtd/src/proto/ssc.dart';
import "package:vcmrtd/src/proto/des_smcipher.dart";
import 'package:vcmrtd/src/proto/mrtd_sm.dart';
import 'package:vcmrtd/src/crypto/des.dart';

import 'package:logging/logging.dart';
import 'package:pointycastle/ecc/api.dart';

import "package:vcmrtd/src/lds/tlv.dart";
import "package:vcmrtd/src/proto/iso7816/icc.dart";
import 'iso7816/response_apdu.dart';
import 'package:vcmrtd/src/lds/efcard_access.dart';

import '../lds/tlvSet.dart';
import '../utils.dart';
import 'access_key.dart';
import 'ecdh_pace.dart';
import 'dh_pace.dart';
import 'aes_smcipher.dart';
import 'pace_cam.dart';
import '../lds/efcard_security.dart';
import '../lds/substruct/security_infos.dart' show ChipAuthenticationPublicKeyInfo;

// Specified in section 9.2.1 of ICAO 9303 p11 doc only this algorithms are
// supported
/*
id-PACE-DH-GM-3DES-CBC-CBC |
id-PACE-DH-GM-AES-CBC-CMAC-128 |
id-PACE-DH-GM-AES-CBC-CMAC-192 |
id-PACE-DH-GM-AES-CBC-CMAC-256 |
id-PACE-ECDH-GM-3DES-CBC-CBC |
id-PACE-ECDH-GM-AES-CBC-CMAC-128 |
id-PACE-ECDH-GM-AES-CBC-CMAC-192 |
id-PACE-ECDH-GM-AES-CBC-CMAC-256 |
id-PACE-DH-IM-3DES-CBC-CBC |
id-PACE-DH-IM-AES-CBC-CMAC-128 |
id-PACE-DH-IM-AES-CBC-CMAC-192 |
id-PACE-DH-IM-AES-CBC-CMAC-256 |
id-PACE-ECDH-IM-3DES-CBC-CBC |
id-PACE-ECDH-IM-AES-CBC-CMAC-128 |
id-PACE-ECDH-IM-AES-CBC-CMAC-192 |
id-PACE-ECDH-IM-AES-CBC-CMAC-256 |
id-PACE-ECDH-CAM-AES-CBC-CMAC-128 |
id-PACE-ECDH-CAM-AES-CBC-CMAC-192 |
id-PACE-ECDH-CAM-AES-CBC-CMAC-256)
*/

class PACEResponseCheckError implements Exception {
  final String message;
  PACEResponseCheckError(this.message);
  @override
  String toString() => message;
}

//Specified in section 4.4.5 of ICAO 9303 p11, table 4:Exchanged data for PACE
class ExchangedDataPACE {
  //step 1 - encrypted nonce
  static const encryptedNonceResponse = 0x80;

  //step 2 - map nonce
  static const mappingDataCommand = 0x81;
  static const mappingDataResponse = 0x82;

  //step 3 - perform key agreement
  static const ephemeralPublicKeyCommand = 0x83;
  static const ephemeralPublicKeyResponse = 0x84;

  //step 4 - mutual authentication
  static const authenticationTokenCommand = 0x85;
  static const authenticationTokenResponse = 0x86;
  static const certificationAuthorityReference = 0x87;
  static const certificationAuthorityReference2 = 0x88;
  static const encryptedChipAuthenticationData = 0x8A;
}

class ResponseDataTagList {
  static const dynamicAuthenticationData = 0x7c;
}

//
// response parsers
//

class ResponseAPDUStep1PaceError implements Exception {
  final String message;
  ResponseAPDUStep1PaceError(this.message);
  @override
  String toString() => message;
}

class ResponseAPDUStep2or3PaceError implements Exception {
  final String message;
  ResponseAPDUStep2or3PaceError(this.message);
  @override
  String toString() => message;
}

class ResponseAPDUStep4PaceError implements Exception {
  final String message;
  ResponseAPDUStep4PaceError(this.message);
  @override
  String toString() => message;
}

class ResponseAPDUStep1Pace {
  late Uint8List data;

  late Uint8List _nonce;

  Uint8List get nonce => _nonce;

  static final _log = Logger("ResponseAPDUStep1Pace");

  ResponseAPDUStep1Pace(this.data);

  void parse() {
    //checking if response has data
    _log.sdVerbose("ResponseAPDUStep1Pace data: ${data.hex()}");

    TLV dynamicAuthenticationData = TLV.fromBytes(data);

    //checking if response contains dynamic authentication data
    if (dynamicAuthenticationData.tag != ResponseDataTagList.dynamicAuthenticationData) {
      _log.error("Pace.step1; Response data does not contain dynamic authentication data");
      throw ResponseAPDUStep1PaceError("Pace.step1; Response data does not contain dynamic authentication data");
    }
    _log.verbose("Pace.step1; Response data contains dynamic authentication data");

    //checking if dynamic authentication data contains encrypted nonce
    TLV encryptedNonce = TLV.fromBytes(dynamicAuthenticationData.value);
    if (encryptedNonce.tag != ExchangedDataPACE.encryptedNonceResponse) {
      _log.error("Pace.step1; Dynamic authentication data does not contain encrypted nonce");
      throw ResponseAPDUStep1PaceError("Pace.step1; Dynamic authentication data does not contain encrypted nonce");
    }
    _nonce = encryptedNonce.value;
    _log.sdVerbose("Nonce: ${_nonce.hex()}");
  }
}

class ResponseAPDUStep2or3Pace {
  late Uint8List data;

  late PublicKeyPACE _public;

  PublicKeyPACE get public => _public;

  static final _log = Logger("ResponseAPDUStep2or3Pace");

  ResponseAPDUStep2or3Pace(this.data);

  void parse({required TOKEN_AGREEMENT_ALGO tokenAgreementAlgorithm}) {
    //checking if response has data
    _log.sdVerbose("ResponseAPDUStep2and3Pace data: ${data.hex()}");

    TLV dynamicAuthenticationData = TLV.fromBytes(data);

    //checking if response contains dynamic authentication data
    if (dynamicAuthenticationData.tag != ResponseDataTagList.dynamicAuthenticationData) {
      _log.error("Pace.step2; Response data does not contain dynamic authentication data");
      throw ResponseAPDUStep2or3PaceError(
        "Pace.step2 or 3; Response data does not contain dynamic authentication data",
      );
    }
    _log.verbose("Pace.step2 or 3; Response data contains dynamic authentication data");

    //checking if dynamic authentication data contains public element
    TLV mappingData = TLV.fromBytes(dynamicAuthenticationData.value);

    int mappingDataResponseTag = mappingData.tag;
    if (mappingDataResponseTag == ExchangedDataPACE.mappingDataResponse) {
      _log.verbose("... step 2");
    } else if (mappingDataResponseTag == ExchangedDataPACE.ephemeralPublicKeyResponse) {
      _log.verbose("... step 3");
    } else {
      _log.error("Pace.step2 or 3; Dynamic authentication data does not contain mapping data");
      throw ResponseAPDUStep2or3PaceError("Pace.step2 or 3; Dynamic authentication data does not contain mapping data");
    }

    if (mappingData.value.isEmpty) {
      _log.error("Pace.step2 or 3; Mapping data is empty");
      throw ResponseAPDUStep2or3PaceError("Pace.step2 or 3; Mapping data is empty");
    }

    if (tokenAgreementAlgorithm == TOKEN_AGREEMENT_ALGO.ECDH) {
      // ECDH
      if (mappingData.value.first != 0x04) {
        _log.verbose("Pace.step2 or 3; Token agreement is ECDH, but first element is not 0x04");
        throw ResponseAPDUStep2or3PaceError("Pace.step2 or 3; Token agreement is ECDH, but first element is not 0x04");
      }
      _log.verbose("Pace.step2 or 3; Mapping data contains EC public key");
      Uint8List hexPublic = Uint8List.fromList(mappingData.value.sublist(1));
      //if length is odd number then we need to print error and throw exception
      if (hexPublic.length % 2 != 0) {
        _log.error(
          "Pace.step2 or 3; Mapping data contains EC public key, but length is odd number. No X and Y component.",
        );
        throw ResponseAPDUStep2or3PaceError(
          "Pace.step2 or 3; Mapping data contains EC public key, but length is odd number. No X and Y component.",
        );
      }
      _public = PublicKeyPACEeCDH.fromHex(hexKey: hexPublic);
    } else {
      // DH
      _log.verbose("Pace.step2 or 3; Mapping data contains DH public key");
      _public = PublicKeyPACEdH(pub: mappingData.value);
    }
    _log.sdVerbose("ICC public key: ${_public.toString()}");
  }
}

class ResponseAPDUStep4Pace {
  late Uint8List data;

  late Uint8List _authToken;
  Uint8List? _encryptedChipAuthData; // Optional: only present for PACE-CAM

  Uint8List get authToken => _authToken;

  /// Returns the Encrypted Chip Authentication Data (tag 0x8A) if present.
  /// This is only present for PACE-CAM (Chip Authentication Mapping).
  Uint8List? get encryptedChipAuthData => _encryptedChipAuthData;

  /// Returns true if this response contains Encrypted Chip Authentication Data,
  /// indicating PACE-CAM was used.
  bool get hasChipAuthData => _encryptedChipAuthData != null;

  static final _log = Logger("ResponseAPDUStep4Pace");

  ResponseAPDUStep4Pace(this.data);

  void parse() {
    //checking if response has data
    _log.sdVerbose("ResponseAPDUStep4Pace data: ${data.hex()}");

    TLV dynamicAuthenticationData = TLV.fromBytes(data);

    //checking if response contains dynamic authentication data
    if (dynamicAuthenticationData.tag != ResponseDataTagList.dynamicAuthenticationData) {
      _log.error("Pace.step4; Response data does not contain dynamic authentication data");
      throw ResponseAPDUStep4PaceError("Pace.step4; Response data does not contain dynamic authentication data");
    }
    _log.verbose("Pace.step4; Response data contains dynamic authentication data");

    // Parse all TLV elements in the dynamic authentication data
    // For GM: only tag 0x86 (auth token) is present
    // For CAM: tag 0x86 (auth token) and tag 0x8A (encrypted chip auth data) are present
    Uint8List remaining = dynamicAuthenticationData.value;
    bool foundAuthToken = false;

    while (remaining.isNotEmpty) {
      final decodedTV = TLV.decode(remaining);
      final tag = decodedTV.tag.value;
      final value = decodedTV.value;

      if (tag == ExchangedDataPACE.authenticationTokenResponse) {
        // Tag 0x86: Authentication Token
        if (value.isEmpty) {
          _log.error("Pace.step4; Authentication token is empty");
          throw ResponseAPDUStep4PaceError("Pace.step4; Authentication token is empty");
        }
        _authToken = value;
        foundAuthToken = true;
        _log.sdVerbose("Authentication token: ${_authToken.hex()}");
      } else if (tag == ExchangedDataPACE.encryptedChipAuthenticationData) {
        // Tag 0x8A: Encrypted Chip Authentication Data (PACE-CAM only)
        _encryptedChipAuthData = value;
        _log.debug("Pace.step4; Found Encrypted Chip Authentication Data (PACE-CAM)");
        _log.sdVerbose("Encrypted Chip Auth Data: ${_encryptedChipAuthData!.hex()}");
      } else {
        _log.debug("Pace.step4; Ignoring unknown tag: 0x${tag.toRadixString(16)}");
      }

      // Move to the next TLV element
      int elementSize = decodedTV.encodedLen;
      if (elementSize >= remaining.length) {
        break;
      }
      remaining = remaining.sublist(elementSize);
    }

    if (!foundAuthToken) {
      _log.error("Pace.step4; Dynamic authentication data does not contain authentication token");
      throw ResponseAPDUStep4PaceError("Pace.step4; Dynamic authentication data does not contain authentication token");
    }

    _log.debug("Parsing step 4 response data was successful");
  }
}

class PACEError implements Exception {
  final String message;
  PACEError(this.message);
  @override
  String toString() => message;
}

/// Result of a PACE session establishment, analogous to gmrtd's document.PaceResult.
class PaceResult {
  final String oid;
  final int parameterId;
  final bool chipAuthenticated;

  PaceResult({
    required this.oid,
    required this.parameterId,
    this.chipAuthenticated = false,
  });
}

/// Class defines Password Authenticated Connection Establishment (PACE)
/// as defined in ICAO 9303 p11 doc.
/// Ref: https://www.icao.int/publications/Documents/9303_p11_cons_en.pdf
class PACE {
  static final _log = Logger("pace");

  // Specified in section 4.4.4 of ICAO 9303 p11 doc
  static const cryptographicMechanismReferenceLen = 8;
  static const referenceOfPublicKeyLen = 1;

  /// Generates data for ENCODING INPUT command
  /// At least one of [ephemeralPublicPoint] or [publicKeyDH] must be provided.
  /// If both are provided [ephemeralPublicPoint] exception is thrown.
  static Uint8List generateEncodingInputData({
    required OIEPaceProtocol crytpographicMechanism,
    required PublicKeyPACE ephemeralPublic,
  }) {
    try {
      _log.debug("Generating ENCODING INPUT data ...");
      const inputDataTTag = 0x7f49;
      const objectIdentifierTag = 0x06;
      const dhPoint = 0x84;
      const ellipticCurvePoint = 0x86;
      const uncompressedPointTag = 0x04;

      // object identifier, both modes have the same identifier layout
      TLV objectIdentifierData = TLV(
        objectIdentifierTag,
        Uint8List.sublistView(Uint8List.fromList(crytpographicMechanism.identifier), 1),
      );

      _log.sdVerbose("Object identifier: ${objectIdentifierData.toBytes().hex()}");
      TLV? publicKeyData;

      _log.sdVerbose("Ephemeral public point: ${ephemeralPublic.toString()}");

      if (ephemeralPublic.agreementAlgorithm == TOKEN_AGREEMENT_ALGO.ECDH) {
        // ECDH
        Uint8List uncompressedPoint = Uint8List.fromList([uncompressedPointTag]);
        publicKeyData = TLV(ellipticCurvePoint, Uint8List.fromList(uncompressedPoint + ephemeralPublic.toBytes()));
        _log.sdVerbose("Public key EC: ${publicKeyData.toBytes().hex()}");
      } else {
        // DH
        publicKeyData = TLV(dhPoint, ephemeralPublic.toBytes());
        _log.sdVerbose("Public key DH: ${publicKeyData.toBytes().hex()}");
      }
      TLV inputData = TLV(inputDataTTag, Uint8List.fromList(objectIdentifierData.toBytes() + publicKeyData.toBytes()));

      _log.sdDebug("ENCODING INPUT data: ${inputData.toBytes().hex()}");
      return inputData.toBytes();
    } on Exception catch (e) {
      _log.error("PACE.generateEncodingInputData; Encoding input data failed: $e");
      throw PACEError("PACE.generateEncodingInputData; Encoding input data failed: $e");
    }
  }

  /// Generates data for AUTHENTICATION TEMPLATE FOR MUTUAL AUTHENTICATION
  static Uint8List generateAuthenticationTemplateForMutualAuthenticationData({
    required final Uint8List cryptographicMechanism,
    required int paceRefType,
  }) {
    _log.debug("Generating AUTHENTICATION TEMPLATE FOR MUTUAL AUTHENTICATION data ...");
    const cyryptographicMechanismRefTag = 0x80;
    const passwordRefPubKeyTag = 0x83;

    TLV cm = TLV(cyryptographicMechanismRefTag, Uint8List.sublistView(cryptographicMechanism, 1));
    TLV drp = TLV.fromIntValue(passwordRefPubKeyTag, paceRefType);
    TLVSet set = TLVSet();
    set.add(cm); //first element
    set.add(drp); //second element
    //set.add(additionalACrytpgraphicAlgorithm); //third element
    _log.sdDebug("AUTHENTICATION TEMPLATE FOR MUTUAL AUTHENTICATION data: ${set.toString()}");
    return set.toBytes();
  }

  /// Generates data for GENERAL AUTHENTICATE command
  static Uint8List generateGeneralAuthenticateDataStep1() {
    //the same message for ECDH and DH
    _log.debug("Generating GENERAL AUTHENTICATE (step 1) data ...");
    const absentTag = 0x7C;
    _log.sdDebug("GENERAL AUTHENTICATE data: ${TLVEmpty(absentTag).toBytes()}");
    return TLVEmpty(absentTag).toBytes();
  }

  static Uint8List generateGeneralAuthenticateDataStep2and3({required PublicKeyPACE public, bool isEphemeral = false}) {
    //the same message for ECDH and DH
    _log.debug("Generating GENERAL AUTHENTICATE (step 2 (or 3)) data: Is ephemeral: $isEphemeral ...");
    const dynamicAuthenticationDataTag = 0x7C;
    const mappingDataTag = 0x81;
    const mappingDataEphemeralTag = 0x83;
    const uncompressedPointTag = 0x04;
    var publicKeyTag = isEphemeral ? mappingDataEphemeralTag : mappingDataTag;

    TLV mappingData;
    if (public.agreementAlgorithm == TOKEN_AGREEMENT_ALGO.ECDH) {
      // ECDH
      Uint8List uncompressedPoint = Uint8List.fromList([uncompressedPointTag]);
      mappingData = TLV(publicKeyTag, Uint8List.fromList(uncompressedPoint + public.toBytes()));
      _log.sdVerbose("ECDH data: ${mappingData.toBytes().hex()}");
    } else {
      // DH
      mappingData = TLV(publicKeyTag, public.toBytes());
      _log.sdVerbose("DH data: ${mappingData.toBytes().hex()}");
    }

    TLV dynamicAuthenticationData = TLV(dynamicAuthenticationDataTag, mappingData.toBytes());

    _log.sdVerbose("PACE step 2 (or 3) data: ${dynamicAuthenticationData.toBytes().hex()}");
    return dynamicAuthenticationData.toBytes();
  }

  static Uint8List generateGeneralAuthenticateDataStep4({required Uint8List authToken}) {
    //the same message for ECDH and DH
    _log.debug("Generating GENERAL AUTHENTICATE (step 4)");
    const dynamicAuthenticationDataTag = 0x7C;
    const authenticationTokenTag = 0x85;
    TLV authenticationToken = TLV(authenticationTokenTag, authToken);
    TLV dynamicAuthenticationData = TLV(dynamicAuthenticationDataTag, authenticationToken.toBytes());

    _log.sdVerbose("PACE step 4 data: ${dynamicAuthenticationData.toBytes().hex()}");
    return dynamicAuthenticationData.toBytes();
  }

  static Uint8List cacluateEncKey({required OIEPaceProtocol paceProtocol, required Uint8List seed}) {
    KEY_LENGTH keyLength = paceProtocol.keyLength;
    CipherAlgorithm cipherAlgorithm = paceProtocol.cipherAlgoritm;

    _log.debug("f");
    _log.sdDebug(
      "Seed: ${seed.hex()}, "
      "Key length: $keyLength, "
      "Cipher algorithm: $cipherAlgorithm",
    );

    if (cipherAlgorithm == CipherAlgorithm.AES) {
      if (keyLength == KEY_LENGTH.s128) {
        _log.debug("Cipher algorithm: AES, Key length: 128 bits");
        return DeriveKey.aes128(seed, paceMode: false);
      } else if (keyLength == KEY_LENGTH.s192) {
        _log.debug("Cipher algorithm: AES, Key length: 192 bits");
        return DeriveKey.aes192(seed, paceMode: false);
      } else if (keyLength == KEY_LENGTH.s256) {
        _log.debug("Cipher algorithm: AES, Key length: 256 bits");
        return DeriveKey.aes256(seed, paceMode: false);
      } else {
        _log.error("Key length is not supported");
        throw PACEError("Key length is not supported");
      }
    } else if (cipherAlgorithm == CipherAlgorithm.DESede) {
      _log.debug("Cipher algorithm: DESede.");
      return DeriveKey.desEDE(seed, paceMode: false);
    } else {
      _log.error("Cipher algorithm is not supported");
      throw PACEError("Cipher algorithm is not supported");
    }
  }

  static Uint8List cacluateMacKey({required OIEPaceProtocol paceProtocol, required Uint8List seed}) {
    KEY_LENGTH keyLength = paceProtocol.keyLength;
    CipherAlgorithm cipherAlgorithm = paceProtocol.cipherAlgoritm;

    _log.debug("Calculating MAC key ...");
    _log.sdDebug(
      "Seed: ${seed.hex()}, "
      "Key length: $keyLength, "
      "Cipher algorithm: $cipherAlgorithm",
    );

    if (cipherAlgorithm == CipherAlgorithm.AES) {
      if (keyLength == KEY_LENGTH.s128) {
        _log.debug("Cipher algorithm: AES, Key length: 128 bits");
        return DeriveKey.cmac128(seed);
      } else if (keyLength == KEY_LENGTH.s192) {
        _log.debug("Cipher algorithm: AES, Key length: 192 bits");
        return DeriveKey.cmac192(seed);
      } else if (keyLength == KEY_LENGTH.s256) {
        _log.debug("Cipher algorithm: AES, Key length: 256 bits");
        return DeriveKey.cmac256(seed);
      } else {
        _log.error("Key length is not supported");
        throw PACEError("Key length is not supported");
      }
    } else if (cipherAlgorithm == CipherAlgorithm.DESede) {
      _log.debug("Cipher algorithm: DESede.");
      return DeriveKey.desEDE(seed, paceMode: false);
    } else {
      _log.error("Cipher algorithm is not supported");
      throw PACEError("Cipher algorithm is not supported");
    }
  }

  static Uint8List cacluate_K_PI_Key121({required OIEPaceProtocol paceProtocol, required Uint8List seed}) {
    //we need K_pi to decrypt nonce
    KEY_LENGTH keyLength = paceProtocol.keyLength;
    CipherAlgorithm cipherAlgorithm = paceProtocol.cipherAlgoritm;

    _log.debug("Calculating K-pi key ...");
    _log.sdDebug(
      "Seed: ${seed.hex()}, "
      "Key length: $keyLength, "
      "Cipher algorithm: $cipherAlgorithm",
    );

    if (cipherAlgorithm == CipherAlgorithm.AES) {
      if (keyLength == KEY_LENGTH.s128) {
        _log.debug("Cipher algorithm: AES, Key length: 128 bits");
        return DeriveKey.cmac128(seed);
      } else if (keyLength == KEY_LENGTH.s192) {
        _log.debug("Cipher algorithm: AES, Key length: 192 bits");
        return DeriveKey.cmac192(seed);
      } else if (keyLength == KEY_LENGTH.s256) {
        _log.debug("Cipher algorithm: AES, Key length: 256 bits");
        return DeriveKey.cmac256(seed);
      } else {
        _log.error("Key length is not supported");
        throw PACEError("Key length is not supported");
      }
    } else if (cipherAlgorithm == CipherAlgorithm.DESede) {
      _log.debug("Cipher algorithm: DESede.");
      return DeriveKey.desEDE(seed, paceMode: false);
    } else {
      _log.error("Cipher algorithm is not supported");
      throw PACEError("Cipher algorithm is not supported");
    }
  }

  static Uint8List cacluateAuthToken({
    required OIEPaceProtocol paceProtocol,
    required Uint8List inputData,
    required Uint8List macKey,
  }) {
    KEY_LENGTH keyLength = paceProtocol.keyLength;
    CipherAlgorithm cipherAlgorithm = paceProtocol.cipherAlgoritm;

    _log.debug("Calculating Auth token ...");
    _log.sdDebug(
      "Seed: ${inputData.hex()}, "
      "Key length: $keyLength, "
      "Cipher algorithm: $cipherAlgorithm, "
      "Mac key length: ${macKey.length}"
      "Mac key: ${macKey.hex()}",
    );

    if (cipherAlgorithm == CipherAlgorithm.AES) {
      _log.debug("Cipher algorithm: AES.");
      AESCipher aesCipher = AESChiperSelector.getChiper(size: keyLength);
      Uint8List computedAuthToken = aesCipher.calculateCMAC(data: inputData, key: macKey);
      _log.sdVerbose("Computed auth token: ${computedAuthToken.hex()}");
      return computedAuthToken;
    } else if (cipherAlgorithm == CipherAlgorithm.DESede) {
      _log.debug("Cipher algorithm: DESede.");
      var computedAuthToken = ISO9797.macAlg3(macKey, inputData); //padding included:)
      _log.sdVerbose("Computed auth token: ${computedAuthToken.hex()}");
      return computedAuthToken;
    } else {
      _log.error("Cipher algorithm is not supported");
      throw PACEError("Cipher algorithm is not supported");
    }
  }

  static Uint8List decryptNonce({
    required OIEPaceProtocol paceProtocol,
    required Uint8List nonce,
    required PaceKey paceKey,
  }) {
    try {
      _log.debug("PACE.decryptNonce; Decrypting nonce ...");
      _log.sdVerbose(
        "PACE.decryptNonce; Nonce: ${nonce.hex()}, "
        "Pace protocol: ${paceProtocol.toString()}",
      );
      _log.sdVerbose("PACE.decryptNonce; Access key: ${paceKey.toString()}");

      CipherAlgorithm cipherAlgo = paceProtocol.cipherAlgoritm;
      KEY_LENGTH keyLength = paceProtocol.keyLength;

      Uint8List kPi = paceKey.Kpi(cipherAlgo, keyLength);
      //Uint8List k_pi = cacluate_K_PI_Key(paceProtocol: paceProtocol, seed: key);
      _log.sdVerbose("PACE.decryptNonce; K-pi: ${kPi.hex()}");

      if (cipherAlgo == CipherAlgorithm.AES) {
        _log.debug("PACE.decryptNonce; Cipher algorithm: AES");
        AESCipher aesCipher = AESChiperSelector.getChiper(size: keyLength);
        Uint8List decryptedNonce = aesCipher.decrypt(data: nonce, key: kPi);
        _log.sdVerbose("PACE.decryptNonce; Decrypted nonce: ${decryptedNonce.hex()}");
        return decryptedNonce;
      } else if (cipherAlgo == CipherAlgorithm.DESede) {
        _log.debug("PACE.decryptNonce; Cipher algorithm: DESede");
        /*key iv data*/
        Uint8List decryptedNonce = DESedeDecrypt(edata: nonce, key: kPi, iv: Uint8List(8));
        _log.sdVerbose("PACE.decryptNonce; Decrypted nonce: ${decryptedNonce.hex()}");
        return decryptedNonce;
      } else {
        _log.error("PACE.decryptNonce; Cipher algorithm is not supported");
        throw PACEError("PACE.decryptNonce; Cipher algorithm is not supported");
      }
    } on Exception catch (e) {
      _log.error("PACE.decryptNonce; Failed: $e");
      throw PACEError("PACE.decryptNonce; Failed: $e");
    }
  }

  static Future<bool> ecdh({
    required ICC icc,
    required Uint8List nonce,
    required int paceDomainParameterId,
    required OIEPaceProtocol paceProtocol,
    required MAPPING_TYPE mappingType,
  }) async {
    try {
      _log.debug("PACE >ECDH< key establishment (from step 2 to step 4) ...");
      _log.sdVerbose(
        "PACE >ECDH< key establishment (from step 2 to step 4); "
        "Decrypted nonce: ${nonce.hex()}, "
        "Pace domain parameter id(int): $paceDomainParameterId, "
        "Pace protocol: ${paceProtocol.toString()}",
      );

      ECDHPace? domainParameter;
      PublicKeyPACEeCDH? publicICCenvelope;
      PublicKeyPACEeCDH? ephemeralPublicICCenvelope;
      try {
        _log.debug("Starting PACE step 2 ...");
        domainParameter = DomainParameterSelectorECDH.getDomainParameter(id: paceDomainParameterId);
        //generating key pair
        domainParameter.generateKeyPair();
        //get public key
        PublicKeyPACEeCDH publicKeyPaceTerminal = domainParameter.getPubKey();

        _log.sdVerbose("Private key: ${domainParameter.toStringWithCaution()}");
        _log.sdVerbose("Public key: ${publicKeyPaceTerminal.toBytes().hex()}");

        Uint8List step2data = generateGeneralAuthenticateDataStep2and3(public: publicKeyPaceTerminal);
        final step2Response = await icc.generalAuthenticatePACEstep2and3(data: step2data);
        //here the response is always 9000, otherwise exception is thrown

        ResponseAPDUStep2or3Pace apduStep2Pace = ResponseAPDUStep2or3Pace(step2Response);
        apduStep2Pace.parse(tokenAgreementAlgorithm: paceProtocol.tokenAgreementAlgorithm);

        //get public key from ICC
        publicICCenvelope = apduStep2Pace.public as PublicKeyPACEeCDH;
        _log.debug("PACE step 2 response from ICC is valid");
      } on Exception catch (e) {
        _log.error("PACE(2); Failed: $e");
        throw PACEError("PACE(2); Failed: $e");
      }

      try {
        _log.debug("Starting PACE step 3 ...");
        ECPublicKey publicICCkey = domainParameter.transformPublic(pubKey: publicICCenvelope);
        ECPoint generatorPoint = domainParameter.getMappedGenerator(otherPubKey: publicICCkey, nonce: nonce);

        _log.sdVerbose("Generator point: ${ECDHPace.ecPointToList(point: generatorPoint).toString()}");
        domainParameter.generateKeyPairWithCustomGenerator(mappedGenerator: generatorPoint);

        //get public key
        PublicKeyPACEeCDH publicKeyEphemeralPaceTerminal = domainParameter.getPubKeyEphemeral();

        _log.sdVerbose("Private key (ephemeral included): ${domainParameter.toStringWithCaution()}");
        _log.sdVerbose("Public key (ephemeral): ${publicKeyEphemeralPaceTerminal.toBytes().hex()}");

        Uint8List step3data = generateGeneralAuthenticateDataStep2and3(
          public: publicKeyEphemeralPaceTerminal,
          isEphemeral: true,
        );
        final step3Response = await icc.generalAuthenticatePACEstep2and3(data: step3data);
        //here the response is always 9000, otherwise exception is thrown

        ResponseAPDUStep2or3Pace apduStep2Pace = ResponseAPDUStep2or3Pace(step3Response);
        apduStep2Pace.parse(tokenAgreementAlgorithm: paceProtocol.tokenAgreementAlgorithm);
        ephemeralPublicICCenvelope = apduStep2Pace.public as PublicKeyPACEeCDH;
        _log.debug("PACE step 3 response from ICC is valid");
        _log.sdVerbose("Ephemeral public ICC key: ${ephemeralPublicICCenvelope.toString()}");
      } on Exception catch (e) {
        _log.error("PACE(3); Failed: $e");
        throw PACEError("PACE(3); Failed: $e");
      }

      try {
        _log.debug("Starting PACE step 4 ...");
        ECPublicKey ephemeralPublicICCkey = domainParameter.transformPublic(pubKey: ephemeralPublicICCenvelope);
        _log.debug("Epehemeral public key is successfully transformed");
        _log.sdVerbose(
          "Ephemeral public ICC key: ${ECDHPace.ecPointToList(point: ephemeralPublicICCkey.Q!).toString()}",
        );
        ECPoint ephemeralSharedSecretKey = domainParameter.getEphemeralSharedSecret(
          otherEphemeralPubKey: ephemeralPublicICCkey,
        );

        _log.sdVerbose(
          "Ephemeral shared secret (X, Y): "
          "${ECDHPace.ecPointToList(point: ephemeralSharedSecretKey).toBytes().hex()}",
        );

        Uint8List seed = ECDHPace.ecPointToList(point: ephemeralSharedSecretKey).toRelavantBytes();
        _log.sdVerbose("Seed: ${seed.hex()}");

        Uint8List encKey = PACE.cacluateEncKey(paceProtocol: paceProtocol, seed: seed);
        Uint8List macKey = PACE.cacluateMacKey(paceProtocol: paceProtocol, seed: seed);

        _log.debug("ENC and Mac keys are successfully calculated");
        _log.sdVerbose(
          "ENC key: ${encKey.hex()} "
          "MAC key: ${macKey.hex()}",
        );

        Uint8List calcInputData = PACE.generateEncodingInputData(
          crytpographicMechanism: paceProtocol,
          ephemeralPublic: ephemeralPublicICCenvelope, //domainParameter.getPubKeyEphemeral()
        );

        Uint8List inputToken = PACE.cacluateAuthToken(
          paceProtocol: paceProtocol,
          inputData: calcInputData,
          macKey: macKey,
        );

        Uint8List step4data = generateGeneralAuthenticateDataStep4(authToken: inputToken);
        final step4Response = await icc.generalAuthenticatePACEstep4(data: step4data);
        //here the response is always 9000, otherwise exception is thrown

        ResponseAPDUStep4Pace apduStep4Pace = ResponseAPDUStep4Pace(step4Response);
        apduStep4Pace.parse();
        Uint8List computedAuthTokenICC = apduStep4Pace.authToken;

        _log.debug("Checking if computed auth token is the same as auth token from ICC");

        Uint8List calcInputDataTerminalforCheck = PACE.generateEncodingInputData(
          crytpographicMechanism: paceProtocol,
          ephemeralPublic: domainParameter.getPubKeyEphemeral(),
        );

        Uint8List inputTokenTerminalforCheck = PACE.cacluateAuthToken(
          paceProtocol: paceProtocol,
          inputData: calcInputDataTerminalforCheck,
          macKey: macKey,
        );

        _log.sdVerbose(
          "Received auth token from ICC: ${computedAuthTokenICC.hex()}"
          ", Computed auth token: ${inputTokenTerminalforCheck.hex()}",
        );

        if (!inputTokenTerminalforCheck.equals(computedAuthTokenICC)) {
          _log.error("PACE(4); Auth token from ICC and terminal are not the same");
          throw PACEError("PACE(4); Auth token from ICC and terminal are not the same");
        }

        // Save ECAD and mapping public key before setting up SM (needed for CAM)
        final ecad = apduStep4Pace.encryptedChipAuthData;

        _log.debug("Finished PACE SM key establishment");
        _log.debug("Setting up SM session ...");
        CipherAlgorithm cipherAlgo = paceProtocol.cipherAlgoritm;
        if (cipherAlgo == CipherAlgorithm.AES) {
          _log.debug("PACE; Cipher algorithm: AES");
          icc.sm = MrtdSM(AES_SMCipher(encKey, macKey, size: paceProtocol.keyLength), AES_SSC());
        } else if (cipherAlgo == CipherAlgorithm.DESede) {
          _log.debug("PACE; Cipher algorithm: DESede");
          icc.sm = MrtdSM(DES_SMCipher(encKey, macKey), DESede_PACE_SSC());
        } else {
          _log.error("PACE; Cipher algorithm is not supported");
          throw PACEError("PACE.Cipher algorithm is not supported");
        }
        _log.debug("... SM (with ECDH) session is set up.");

        // PACE-CAM chip authentication verification (ICAO 9303 Part 11 §4.4.3.5)
        // Matching gmrtd pace.go:571-583 (doGenericMappingGmCam → doCamEcdh)
        bool chipAuthenticated = false;
        if (mappingType == MAPPING_TYPE.CAM) {
          if (ecad == null || ecad.isEmpty) {
            throw PACEError("PACE-CAM: ECAD missing from step 4 response");
          }

          _log.debug("PACE-CAM: reading EF.CardSecurity over SM ...");
          final cardSecurityBytes = await _readCardSecurity(icc);
          final cardSecurity = EfCardSecurity.fromBytes(cardSecurityBytes);
          final secInfos = cardSecurity.securityInfos;
          if (secInfos == null || secInfos.chipAuthenticationPublicKeyInfos.isEmpty) {
            throw PACEError("PACE-CAM: no ChipAuthenticationPublicKeyInfo in EF.CardSecurity");
          }

          // Extract PK_IC matching domain parameter ID
          // Matching gmrtd pace.go:421-443 (icPubKeyECForCAM)
          final pkIc = _extractPkIcForCAM(secInfos.chipAuthenticationPublicKeyInfos, paceDomainParameterId);

          PaceCam.verifyChipAuthentication(
            encryptedChipAuthData: ecad,
            ksEnc: encKey,
            keyLength: paceProtocol.keyLength,
            pkIcX: pkIc.x,
            pkIcY: pkIc.y,
            pkMapIcX: publicICCenvelope!.xBytes,
            pkMapIcY: publicICCenvelope!.yBytes,
            domainParameterId: paceDomainParameterId,
          );
          _log.debug("PACE-CAM verification successful");
          chipAuthenticated = true;
        }
        return chipAuthenticated;
      } on Exception catch (e) {
        _log.error("PACE <ECDH> (4); Failed: $e");
        throw PACEError("PACE <ECDH> (4); Failed: $e");
      }
    } on Exception catch (e) {
      _log.error("PACE <ECDH> key establishment failed: $e");
      throw PACEError("PACE <ECDH> key establishment failed: $e");
    }
  }

  static Future<void> dh({
    required ICC icc,
    required Uint8List nonce,
    required int paceDomainParameterId,
    required OIEPaceProtocol paceProtocol,
  }) async {
    try {
      _log.debug("PACE >DH< key establishment (from step 2 to step 4) ...");
      _log.sdVerbose(
        "PACE >DH< key establishment (from step 2 to step 4); "
        "Decrypted nonce: ${nonce.hex()}, "
        "Pace domain parameter id(int): $paceDomainParameterId, "
        "Pace protocol: ${paceProtocol.toString()}",
      );

      DHPace? domainParameter;
      PublicKeyPACEdH? publicICCenvelope;
      PublicKeyPACEdH? ephemeralPublicICCenvelope;
      try {
        _log.debug("Starting PACE step 2 ...");
        domainParameter = DomainParameterSelectorDH.getDomainParameter(id: paceDomainParameterId);
        //generating key pair
        domainParameter.generateKeyPair();
        //get public key
        PublicKeyPACEdH publicKeyPaceTerminal = domainParameter.getPubKey();

        _log.sdVerbose("Private key: ${domainParameter.toStringWithCaution()}");
        _log.sdVerbose("Public key: ${publicKeyPaceTerminal.toBytes().hex()}");

        Uint8List step2data = generateGeneralAuthenticateDataStep2and3(public: publicKeyPaceTerminal);
        final step2Response = await icc.generalAuthenticatePACEstep2and3(data: step2data);
        //here the response is always 9000, otherwise exception is thrown

        ResponseAPDUStep2or3Pace apduStep2Pace = ResponseAPDUStep2or3Pace(step2Response);
        apduStep2Pace.parse(tokenAgreementAlgorithm: paceProtocol.tokenAgreementAlgorithm);

        //get public key from ICC
        publicICCenvelope = apduStep2Pace.public as PublicKeyPACEdH;
        _log.debug("PACE step 2 response from ICC is valid");
      } on Exception catch (e) {
        _log.error("PACE(2); Failed: $e");
        throw PACEError("PACE(2); Failed: $e");
      }

      try {
        _log.debug("Starting PACE step 3 ...");
        _log.debug("Public ICC Envelope: ${publicICCenvelope.toString()}");
        Uint8List generatorPoint = domainParameter.getMappedGenerator(
          otherPubKey: publicICCenvelope.toRelavantBytes(),
          nonce: nonce,
        );

        _log.sdVerbose("Generator point: ${generatorPoint.hex()}");
        domainParameter.generateKeyPairWithCustomGenerator(ephemeralGenerator: Utils.uint8ListToBigInt(generatorPoint));

        //get public key
        PublicKeyPACEdH publicKeyEphemeralPaceTerminal = domainParameter.getPubKeyEphemeral();

        _log.sdVerbose("Private key (ephemeral included): ${domainParameter.toStringWithCaution()}");
        _log.sdDebug("Public key (ephemeral): ${publicKeyEphemeralPaceTerminal.toBytes().hex()}");

        Uint8List step3data = generateGeneralAuthenticateDataStep2and3(
          public: publicKeyEphemeralPaceTerminal,
          isEphemeral: true,
        );
        final step3Response = await icc.generalAuthenticatePACEstep2and3(data: step3data);
        //here the response is always 9000, otherwise exception is thrown

        ResponseAPDUStep2or3Pace apduStep2Pace = ResponseAPDUStep2or3Pace(step3Response);
        apduStep2Pace.parse(tokenAgreementAlgorithm: paceProtocol.tokenAgreementAlgorithm);
        ephemeralPublicICCenvelope = apduStep2Pace.public as PublicKeyPACEdH;
        _log.debug("PACE step 3 response from ICC is valid");
        _log.sdVerbose("Ephemeral public ICC key: ${ephemeralPublicICCenvelope.toString()}");
      } on Exception catch (e) {
        _log.error("PACE(3); Failed: $e");
        throw PACEError("PACE(3); Failed: $e");
      }

      try {
        _log.debug("Starting PACE step 4 ...");
        _log.debug("Ephemeral public ICC envelope: ${ephemeralPublicICCenvelope.toString()}");
        BigInt ephemeralSharedSecretKey = domainParameter.getEphemeralSharedSecret(
          otherEphemeralPubKey: ephemeralPublicICCenvelope.toRelavantBytes(),
        );

        _log.sdVerbose(
          "Ephemeral shared secret (X, Y): "
          "${Utils.bigIntToUint8List(bigInt: ephemeralSharedSecretKey).hex()}",
        );

        //not sure if correct
        Uint8List seed = Utils.bigIntToUint8List(bigInt: ephemeralSharedSecretKey);
        _log.sdVerbose("Seed: ${seed.hex()}");

        Uint8List encKey = PACE.cacluateEncKey(paceProtocol: paceProtocol, seed: seed);
        Uint8List macKey = PACE.cacluateMacKey(paceProtocol: paceProtocol, seed: seed);

        _log.debug("ENC and Mac keys are successfully calculated");
        _log.sdVerbose(
          "ENC key: ${encKey.hex()} "
          "MAC key: ${macKey.hex()}",
        );

        Uint8List calcInputData = PACE.generateEncodingInputData(
          crytpographicMechanism: paceProtocol,
          ephemeralPublic: ephemeralPublicICCenvelope, //domainParameter.getPubKeyEphemeral()
        );

        Uint8List inputToken = PACE.cacluateAuthToken(
          paceProtocol: paceProtocol,
          inputData: calcInputData,
          macKey: macKey,
        );

        Uint8List step4data = generateGeneralAuthenticateDataStep4(authToken: inputToken);
        final step4Response = await icc.generalAuthenticatePACEstep4(data: step4data);
        //here the response is always 9000, otherwise exception is thrown

        ResponseAPDUStep4Pace apduStep4Pace = ResponseAPDUStep4Pace(step4Response);
        apduStep4Pace.parse();
        Uint8List computedAuthTokenICC = apduStep4Pace.authToken;

        _log.debug("Checking if computed auth token is the same as auth token from ICC");

        Uint8List calcInputDataTerminalforCheck = PACE.generateEncodingInputData(
          crytpographicMechanism: paceProtocol,
          ephemeralPublic: domainParameter.getPubKeyEphemeral(),
        );

        Uint8List inputTokenTerminalforCheck = PACE.cacluateAuthToken(
          paceProtocol: paceProtocol,
          inputData: calcInputDataTerminalforCheck,
          macKey: macKey,
        );

        _log.sdVerbose(
          "Received auth token from ICC: ${computedAuthTokenICC.hex()}"
          ", Computed auth token: ${inputTokenTerminalforCheck.hex()}",
        );

        if (!inputTokenTerminalforCheck.equals(computedAuthTokenICC)) {
          _log.error("PACE(4); Auth token from ICC and terminal are not the same");
          throw PACEError("PACE(4); Auth token from ICC and terminal are not the same");
        }

        _log.debug("Finished PACE SM key establishment");
        _log.debug("Setting up SM session ...");
        CipherAlgorithm cipherAlgo = paceProtocol.cipherAlgoritm;
        if (cipherAlgo == CipherAlgorithm.AES) {
          _log.debug("PACE; Cipher algorithm: AES");
          icc.sm = MrtdSM(AES_SMCipher(encKey, macKey, size: paceProtocol.keyLength), AES_SSC());
        } else if (cipherAlgo == CipherAlgorithm.DESede) {
          _log.debug("PACE; Cipher algorithm: DESede");
          icc.sm = MrtdSM(DES_SMCipher(encKey, macKey), DESede_PACE_SSC());
        } else {
          _log.error("PACE; Cipher algorithm is not supported");
          throw PACEError("PACE.Cipher algorithm is not supported");
        }
        _log.debug("... SM (with DH) session is set up.");
      } on Exception catch (e) {
        _log.error("PACE <DH> (4); Failed: $e");
        throw PACEError("PACE <DH> (4); Failed: $e");
      }
    } on Exception catch (e) {
      _log.error("PACE <DH> key establishment failed: $e");
      throw PACEError("PACE <DH> key establishment failed: $e");
    }
  }

  /// Reads EF.CardSecurity (FID 0x011D) from the chip over secure messaging.
  /// Matching gmrtd pace.go:529-543 (loadCardSecurityFile).
  static Future<Uint8List> _readCardSecurity(ICC icc) async {
    _log.debug("Reading EF.CardSecurity (FID 0x011D) ...");
    final efId = Uint8List(2);
    ByteData.view(efId.buffer).setUint16(0, EfCardSecurity.FID);
    await icc.selectEF(efId: efId);

    // Read initial chunk to determine file length
    final chunk1 = await icc.readBinary(offset: 0, ne: 256);
    if (chunk1.data == null || chunk1.data!.isEmpty) {
      throw PACEError("PACE-CAM: Failed to read EF.CardSecurity");
    }

    final dtl = TLV.decodeTagAndLength(chunk1.data!);
    final totalLen = dtl.encodedLen + dtl.length.value;

    // Read remaining chunks
    var data = Uint8List.fromList(chunk1.data!);
    while (data.length < totalLen) {
      final remaining = totalLen - data.length;
      final nRead = remaining > 256 ? 256 : remaining;
      final ResponseAPDU chunk;
      if (data.length > 0x7FFF) {
        chunk = await icc.readBinaryExt(offset: data.length, ne: nRead);
      } else {
        chunk = await icc.readBinary(offset: data.length, ne: nRead);
      }
      if (chunk.data == null || chunk.data!.isEmpty) break;
      data = Uint8List.fromList(data + chunk.data!);
    }
    _log.debug("EF.CardSecurity read: ${data.length} bytes");
    return data;
  }

  /// Extracts the chip's static EC public key (PK_IC) from ChipAuthenticationPublicKeyInfo
  /// entries, matching the given domain parameter ID.
  /// Matching gmrtd pace.go:421-443 (icPubKeyECForCAM).
  static ({Uint8List x, Uint8List y}) _extractPkIcForCAM(
    List<ChipAuthenticationPublicKeyInfo> caPubKeyInfos,
    int domainParameterId,
  ) {
    for (final info in caPubKeyInfos) {
      // Only evaluate EC keys (protocol == id-PK-ECDH)
      if (info.protocol != '0.4.0.127.0.7.2.2.1.2') continue;

      final spki = info.chipAuthenticationPublicKey;
      final spkiElements = spki.elements;
      if (spkiElements == null || spkiElements.length < 2) continue;

      // SubjectPublicKeyInfo = SEQUENCE { algorithm, subjectPublicKey }
      // algorithm = SEQUENCE { algorithm OID, parameters (domain param ID) }
      final algorithmObj = spkiElements[0];
      if (algorithmObj is! ASN1Sequence) continue;
      final algElements = algorithmObj.elements;
      if (algElements == null || algElements.length < 2) continue;

      // Parameters encode the domain parameter ID
      final params = algElements[1];
      final paramBytes = params.valueBytes;
      if (paramBytes == null || paramBytes.isEmpty) continue;

      // Decode parameter ID from the encoded value
      int paramId = 0;
      for (final b in paramBytes) {
        paramId = (paramId << 8) | b;
      }
      if (paramId != domainParameterId) continue;

      // Extract the SubjectPublicKey (BIT STRING)
      // BIT STRING encoding: first byte = unused bits count, rest = data
      final subjectPublicKeyObj = spkiElements[1];
      var keyBytes = subjectPublicKeyObj.valueBytes;
      if (keyBytes == null || keyBytes.isEmpty) continue;

      // Skip unused-bits byte if present (BIT STRING)
      if (keyBytes[0] == 0x00) {
        keyBytes = keyBytes.sublist(1);
      }

      // X9.62 uncompressed point: 04 || X || Y
      if (keyBytes[0] != 0x04) {
        _log.warning("PACE-CAM: Expected uncompressed EC point (0x04 prefix)");
        continue;
      }
      final coordLen = (keyBytes.length - 1) ~/ 2;
      final x = Uint8List.fromList(keyBytes.sublist(1, 1 + coordLen));
      final y = Uint8List.fromList(keyBytes.sublist(1 + coordLen));
      return (x: x, y: y);
    }
    throw PACEError("PACE-CAM: unable to find EC public key for domain parameter $domainParameterId in EF.CardSecurity");
  }

  static Future<PaceResult> initSession({
    required PaceKey paceKey,
    required ICC icc,
    required EfCardAccess efCardAccess,
  }) async {
    try {
      _log.debug("Starting PACE key establishment ...");
      if (efCardAccess.paceInfo == null) {
        _log.error("PACEInfo is not present in EF.CardAccess");
        throw PACEError("PACEInfo is not present in EF.CardAccess");
      }

      if (efCardAccess.paceInfo?.protocol == null) {
        _log.error("Protocol is not present in EF.CardAccess.paceInfo");
        throw PACEError("Protocol is not present in EF.CardAccess.paceInfo");
      }

      if (efCardAccess.paceInfo?.isPaceDomainParameterSupported == false) {
        _log.error("PACE domain parameter is not supported");
        throw PACEError("PACE domain parameter is not supported");
      }

      _log.sdVerbose("Access key: ${paceKey.toString()}");

      OIEPaceProtocol paceProtocol = efCardAccess.paceInfo!.protocol;
      _log.debug("Protocol: $paceProtocol");

      // Reject PACE-IM before any APDU is sent (matching gmrtd pace.go:704)
      MAPPING_TYPE mappingType = paceProtocol.mappingType;
      if (mappingType == MAPPING_TYPE.IM) {
        _log.error("PACE-IM is not implemented");
        throw PACEError("PACE-IM NOT IMPLEMENTED");
      }

      int paceDomainParameterId = efCardAccess.paceInfo!.parameterId!;
      // we already know that protocol is supported
      // we also know that domain parameter is supported

      // parameters for key establishment
      Uint8List decryptedNonce;

      //step 0
      Uint8List step0data = generateAuthenticationTemplateForMutualAuthenticationData(
        cryptographicMechanism: Uint8List.fromList(paceProtocol.identifier),
        paceRefType: paceKey.PACE_REF_KEY_TAG,
      );
      try {
        final step0Response = await icc.setAT(data: step0data);
        //here the response is always 9000, otherwise exception is thrown
        _log.finest("ICC response: $step0Response");
        _log.fine("Got PACE step 0 SUCCESSFUL response from ICC");
        _log.debug("PACE step 0 response from ICC is valid");
      } on Exception catch (e) {
        _log.error("PACE(0); Failed: $e");
        throw PACEError("PACE(0); Failed: $e");
      }

      //step 1
      try {
        await Future.delayed(Duration(milliseconds: 1000));
        Uint8List step1data = generateGeneralAuthenticateDataStep1();
        final step1Response = await icc.generalAuthenticatePACEstep1(data: step1data);
        //here the response is always 9000, otherwise exception is thrown
        _log.fine("Got PACE step 1 SUCCESSFUL response from ICC");

        //parse step1 response
        ResponseAPDUStep1Pace apduStep1Pace = ResponseAPDUStep1Pace(step1Response);
        apduStep1Pace.parse(); //if completed without exception data are valid

        decryptedNonce = PACE.decryptNonce(paceProtocol: paceProtocol, nonce: apduStep1Pace.nonce, paceKey: paceKey);
        _log.debug("PACE step 1 response from ICC is valid");
      } on Exception catch (e) {
        _log.error("PACE(1); Failed: $e");
        throw PACEError("PACE(1); Failed: $e");
      }

      //step 2, 3 and 4
      bool chipAuthenticated = false;
      if (paceProtocol.tokenAgreementAlgorithm == TOKEN_AGREEMENT_ALGO.ECDH) {
        _log.debug("Going to ECDH key establishment (on step 2, 3 and 4)");
        chipAuthenticated = await ecdh(
          icc: icc,
          nonce: decryptedNonce,
          paceDomainParameterId: paceDomainParameterId,
          paceProtocol: paceProtocol,
          mappingType: mappingType,
        );
      } else if (paceProtocol.tokenAgreementAlgorithm == TOKEN_AGREEMENT_ALGO.DH) {
        _log.debug("Going to DH key establishment (on step 2, 3 and 4)");
        await dh(
          icc: icc,
          nonce: decryptedNonce,
          paceDomainParameterId: paceDomainParameterId,
          paceProtocol: paceProtocol,
        );
      } else {
        _log.error("PACE token agreement algorithm is not supported");
        throw PACEError("PACE token agreement algorithm is not supported");
      }

      return PaceResult(
        oid: paceProtocol.identifierString,
        parameterId: paceDomainParameterId,
        chipAuthenticated: chipAuthenticated,
      );
    } on Exception catch (e) {
      _log.error("PACE key establishment failed: $e");
      throw PACEError("PACE key establishment failed: $e");
    }
  }
}
