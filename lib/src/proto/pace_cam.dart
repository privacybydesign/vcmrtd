// PACE-CAM (Chip Authentication Mapping) verification
// Per ICAO 9303 Part 11, Section 4.4.3.3.3 and 4.4.3.5

import 'dart:typed_data';

import 'package:logging/logging.dart';

import '../crypto/aes.dart';
import '../crypto/iso9797.dart';
import '../extension/logging_apis.dart';
import '../lds/asn1ObjectIdentifiers.dart';
import 'ecdh_pace.dart';

/// Error thrown when PACE-CAM verification fails
class PaceCamError implements Exception {
  final String message;
  PaceCamError(this.message);
  @override
  String toString() => 'PaceCamError: $message';
}

/// PACE-CAM (Chip Authentication Mapping) verification utilities
///
/// Per ICAO 9303 Part 11:
/// - Section 4.4.3.3.3: Chip Authentication Mapping
/// - Section 4.4.3.5: Encrypted Chip Authentication Data
/// - Section 4.4.3.5.2: Verification by the terminal
class PaceCam {
  static final _log = Logger('PaceCam');

  /// Decrypts the Encrypted Chip Authentication Data (ECAD) from PACE step 4 response
  ///
  /// Per ICAO 9303 Part 11 Section 4.4.3.5.2:
  /// - IV = E(KSenc, 0xFF...FF) where E is the block cipher encryption
  /// - Decrypt ECAD using CBC mode with the computed IV
  /// - Remove ISO 9797-1 Method 2 padding
  ///
  /// Returns the decrypted CA_IC (chip's ephemeral private key contribution)
  static Uint8List decryptEcad({
    required Uint8List encryptedChipAuthData,
    required Uint8List ksEnc,
    required KEY_LENGTH keyLength,
  }) {
    _log.debug('Decrypting ECAD...');
    _log.sdVerbose('ECAD: ${encryptedChipAuthData.length} bytes');
    _log.sdVerbose('KsEnc: ${ksEnc.length} bytes');

    // Get AES cipher
    final aesCipher = AESChiperSelector.getChiper(size: keyLength);

    // IV = E(KSenc, 0xFF...FF)
    // Per spec: IV is computed by encrypting a block of all 1s
    final allOnes = Uint8List(16);
    for (int i = 0; i < 16; i++) {
      allOnes[i] = 0xFF;
    }
    final iv = aesCipher.encrypt(data: allOnes, key: ksEnc);
    _log.sdVerbose('IV: ${iv.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}');

    // Decrypt ECAD using CBC mode
    final decryptedPadded = aesCipher.decrypt(data: encryptedChipAuthData, key: ksEnc, iv: iv);
    _log.sdVerbose('Decrypted (padded): ${decryptedPadded.length} bytes');

    // Remove ISO 9797-1 Method 2 padding
    final caIc = ISO9797.unpad(decryptedPadded);
    _log.sdVerbose('CA_IC: ${caIc.length} bytes');
    _log.sdVerbose('CA_IC value: ${caIc.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}');

    return caIc;
  }

  /// Verifies PACE-CAM by checking that PKMap,IC = KA(CA_IC, PK_IC, D_IC)
  ///
  /// Per ICAO 9303 Part 11 Section 4.4.3.5.2:
  /// "The terminal SHALL decrypt AIC to recover CAIC and verify
  /// PKMap,IC = KA(CAIC, PKIC, DIC), where PKIC is the static public
  /// key of the eMRTD chip."
  ///
  /// Parameters:
  /// - [caIc]: Decrypted Chip Authentication data (chip's ephemeral private key)
  /// - [pkIcX]: Chip's static public key X coordinate (from ChipAuthenticationPublicKeyInfo)
  /// - [pkIcY]: Chip's static public key Y coordinate (from ChipAuthenticationPublicKeyInfo)
  /// - [pkMapIcX]: Chip's mapping public key X coordinate (from PACE step 2 response)
  /// - [pkMapIcY]: Chip's mapping public key Y coordinate (from PACE step 2 response)
  /// - [domainParameterId]: The domain parameter ID (curve identifier)
  ///
  /// Returns true if verification succeeds
  /// Throws [PaceCamError] if verification fails
  static bool verify({
    required Uint8List caIc,
    required Uint8List pkIcX,
    required Uint8List pkIcY,
    required Uint8List pkMapIcX,
    required Uint8List pkMapIcY,
    required int domainParameterId,
  }) {
    _log.debug('Verifying PACE-CAM...');
    _log.sdVerbose('CA_IC: ${caIc.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}');
    _log.sdVerbose('PK_IC X: ${pkIcX.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}');
    _log.sdVerbose('PK_IC Y: ${pkIcY.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}');
    _log.sdVerbose('PKMap_IC X: ${pkMapIcX.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}');
    _log.sdVerbose('PKMap_IC Y: ${pkMapIcY.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}');

    // Get the domain parameters for the curve
    final domainParams = DomainParameterSelectorECDH.getDomainParameter(id: domainParameterId);
    final curve = domainParams.domainParameters;

    // Parse PK_IC (chip's static public key from CardSecurity)
    final pkIcXBigInt = BigInt.parse(pkIcX.map((b) => b.toRadixString(16).padLeft(2, '0')).join(), radix: 16);
    final pkIcYBigInt = BigInt.parse(pkIcY.map((b) => b.toRadixString(16).padLeft(2, '0')).join(), radix: 16);
    final pkIc = curve.curve.createPoint(pkIcXBigInt, pkIcYBigInt);

    // Parse PKMap_IC (chip's mapping public key from PACE step 2)
    final pkMapIcXBigInt = BigInt.parse(pkMapIcX.map((b) => b.toRadixString(16).padLeft(2, '0')).join(), radix: 16);
    final pkMapIcYBigInt = BigInt.parse(pkMapIcY.map((b) => b.toRadixString(16).padLeft(2, '0')).join(), radix: 16);

    // Parse CA_IC as a scalar (chip's ephemeral private key contribution)
    final caIcBigInt = BigInt.parse(caIc.map((b) => b.toRadixString(16).padLeft(2, '0')).join(), radix: 16);

    // Compute KA = CA_IC * PK_IC (scalar multiplication)
    // This is the key agreement: KA(CA_IC, PK_IC, D_IC)
    final ka = (pkIc * caIcBigInt)!;

    _log.sdVerbose('KA X: ${ka.x!.toBigInteger()!.toRadixString(16)}');
    _log.sdVerbose('KA Y: ${ka.y!.toBigInteger()!.toRadixString(16)}');

    // Verify that KA == PKMap_IC
    final kaX = ka.x!.toBigInteger()!;
    final kaY = ka.y!.toBigInteger()!;

    if (kaX != pkMapIcXBigInt || kaY != pkMapIcYBigInt) {
      _log.error('PACE-CAM verification failed: KA != PKMap_IC');
      _log.sdDebug('Expected X: ${pkMapIcXBigInt.toRadixString(16)}');
      _log.sdDebug('Actual X: ${kaX.toRadixString(16)}');
      _log.sdDebug('Expected Y: ${pkMapIcYBigInt.toRadixString(16)}');
      _log.sdDebug('Actual Y: ${kaY.toRadixString(16)}');
      throw PaceCamError('PACE-CAM verification failed: computed KA does not match PKMap_IC');
    }

    _log.info('PACE-CAM verification successful');
    return true;
  }

  /// Performs complete PACE-CAM verification
  ///
  /// This combines decryption and verification in one call.
  ///
  /// Parameters:
  /// - [encryptedChipAuthData]: The ECAD from PACE step 4 response (tag 0x8A)
  /// - [ksEnc]: Session encryption key from PACE
  /// - [keyLength]: Key length used in PACE
  /// - [pkIcX]: Chip's static public key X coordinate (from ChipAuthenticationPublicKeyInfo in CardSecurity)
  /// - [pkIcY]: Chip's static public key Y coordinate
  /// - [pkMapIcX]: Chip's mapping public key X coordinate (from PACE step 2 response)
  /// - [pkMapIcY]: Chip's mapping public key Y coordinate
  /// - [domainParameterId]: The domain parameter ID (curve identifier)
  ///
  /// Returns true if verification succeeds
  /// Throws [PaceCamError] if verification fails
  static bool verifyChipAuthentication({
    required Uint8List encryptedChipAuthData,
    required Uint8List ksEnc,
    required KEY_LENGTH keyLength,
    required Uint8List pkIcX,
    required Uint8List pkIcY,
    required Uint8List pkMapIcX,
    required Uint8List pkMapIcY,
    required int domainParameterId,
  }) {
    _log.debug('Performing complete PACE-CAM verification...');

    // Step 1: Decrypt ECAD to get CA_IC
    final caIc = decryptEcad(encryptedChipAuthData: encryptedChipAuthData, ksEnc: ksEnc, keyLength: keyLength);

    // Step 2: Verify that PKMap_IC = KA(CA_IC, PK_IC, D_IC)
    return verify(
      caIc: caIc,
      pkIcX: pkIcX,
      pkIcY: pkIcY,
      pkMapIcX: pkMapIcX,
      pkMapIcY: pkMapIcY,
      domainParameterId: domainParameterId,
    );
  }
}
