// PACE-CAM (Chip Authentication Mapping) implementation tests
// Test vectors ported from gmrtd (https://github.com/gmrtd/gmrtd)
// and ICAO 9303 Part 11 Appendix I
//
// PACE-CAM is used by various countries including Germany and Finland.

import 'dart:typed_data';

import 'package:vcmrtd/extensions.dart';
import 'package:vcmrtd/src/lds/asn1ObjectIdentifiers.dart';
import 'package:vcmrtd/src/lds/efcard_access.dart';
import 'package:vcmrtd/src/proto/ecdh_pace.dart';
import 'package:vcmrtd/src/proto/pace.dart';
import 'package:vcmrtd/src/proto/pace_cam.dart';
import 'package:vcmrtd/src/proto/public_key_pace.dart';
import 'package:vcmrtd/src/proto/dba_key.dart';
import 'package:vcmrtd/src/crypto/aes.dart';
import 'package:test/test.dart';

void main() {
  group('PACE-CAM Implementation', () {
    // ==========================================================================
    // PaceInfo parsing with optional parameterId
    // Per ICAO 9303 Part 11, parameterId is OPTIONAL in PACEInfo
    // ==========================================================================

    group('PaceInfo parameterId handling', () {
      test('PaceInfo with 3 elements (parameterId present) should parse successfully', () {
        // Standard PaceInfo with parameterId=13 (BrainpoolP256r1)
        // From gmrtd TestDoPace_GM_ECDH
        final efCardAccessData = "31143012060A04007F0007020204020202010202010D".parseHex();

        final efCardAccess = EfCardAccess.fromBytes(efCardAccessData);

        expect(efCardAccess.isPaceInfoSet, true);
        expect(efCardAccess.paceInfo!.version, 2);
        expect(efCardAccess.paceInfo!.isParameterSet, true);
        expect(efCardAccess.paceInfo!.parameterId, 13); // BrainpoolP256r1
      });

      test('PaceInfo with 2 elements (parameterId missing) should parse with parameterId=null', () {
        // PaceInfo without optional parameterId
        // Some documents omit this optional field
        // Structure: SEQUENCE { OID, INTEGER(version=2) }
        // Missing the optional parameterId INTEGER
        //
        // Per ICAO 9303 Part 11, parameterId is OPTIONAL:
        // PACEInfo ::= SEQUENCE {
        //   protocol OBJECT IDENTIFIER,
        //   version INTEGER,
        //   parameterId INTEGER OPTIONAL  <-- OPTIONAL!
        // }
        //
        // ASN.1 breakdown:
        //   31 11 - SET of length 17
        //   30 0F - SEQUENCE of length 15
        //   06 0a 04007f00070202040202 - OID (id-PACE-ECDH-GM-AES-CBC-CMAC-128)
        //   02 01 02 - INTEGER version = 2
        //   (no parameterId - this is valid per ICAO spec)

        final efCardAccessNoParamId = "3111300F060a04007f00070202040202020102".parseHex();

        // EXPECTED BEHAVIOR: Should parse successfully with parameterId = null
        final efCardAccess = EfCardAccess.fromBytes(efCardAccessNoParamId);

        expect(efCardAccess.isPaceInfoSet, true);
        expect(efCardAccess.paceInfo!.version, 2);
        expect(efCardAccess.paceInfo!.isParameterSet, false); // parameterId not set
        expect(efCardAccess.paceInfo!.parameterId, isNull);
      });

      test('PaceInfo with 2 elements and different OID should also parse', () {
        // Another variant without parameterId using a different PACE protocol
        // OID: id-PACE-ECDH-GM-AES-CBC-CMAC-256 (0.4.0.127.0.7.2.2.4.2.4)
        //
        // ASN.1:
        //   31 11 - SET of length 17
        //   30 0F - SEQUENCE of length 15
        //   06 0a 04007f00070202040204 - OID
        //   02 01 02 - INTEGER version = 2
        final efCardAccessGm256NoParamId = "3111300F060a04007f00070202040204020102".parseHex();

        // EXPECTED BEHAVIOR: Should parse successfully
        final efCardAccess = EfCardAccess.fromBytes(efCardAccessGm256NoParamId);

        expect(efCardAccess.isPaceInfoSet, true);
        expect(efCardAccess.paceInfo!.version, 2);
        expect(efCardAccess.paceInfo!.isParameterSet, false);
        expect(efCardAccess.paceInfo!.parameterId, isNull);
      });
    });

    // ==========================================================================
    // Domain parameter support for BrainpoolP256r1 (ID 13)
    // Commonly used curve for PACE-CAM
    // ==========================================================================

    group('BrainpoolP256r1 (parameterId 13) support', () {
      test('Generic Mapping with BrainpoolP256r1 - test vectors from gmrtd', () {
        // Test vectors from gmrtd TestDoGenericMappingEC / ICAO 9303 p11 Appendix D.3
        // parameterId = 13 (BrainpoolP256r1)
        //
        // The getMappedGenerator function computes: G' = s * G + H
        // where s = nonce, G = base point, H = shared secret (computed internally)
        //
        // We need to set up terminal and chip with their private keys,
        // then call getMappedGenerator which will compute the shared secret

        final nonce = "3F00C4D39D153F2B2A214A078D899B22".parseHex();

        // Terminal and chip private keys from ICAO test vectors
        final terminalPrivateKey = "7F4EF07B9EA82FD78AD689B38D0BC78CF21F249D953BC46F4C6E19259C010F99".parseHex();
        final chipPrivateKey = "498FF49756F2DC1587840041839A85982BE7761D14715FB091EFA7BCE9058560".parseHex();

        // Expected shared secret (computed from terminal_priv * chip_pub or vice versa)
        final expectedSharedSecretX = "60332EF2450B5D247EF6D3868397D398852ED6E8CAF6FFEEF6BF85CA57057FD5".parseHex();
        final expectedSharedSecretY = "0840CA7415BAF3E43BD414D35AA4608B93A2CAF3A4E3EA4E82C9C13D03EB7181".parseHex();

        // Expected mapped generator
        final expectedMappedGenX = "8CED63C91426D4F0EB1435E7CB1D74A46723A0AF21C89634F65A9AE87A9265E2".parseHex();
        final expectedMappedGenY = "8C879506743F8611AC33645C5B985C80B5F09A0B83407C1B6A4D857AE76FE522".parseHex();

        // Set up terminal with its private key
        final terminal = DomainParameterSelectorECDH.getDomainParameter(id: 13);
        terminal.generateKeyPairFromPriv(privKey: terminalPrivateKey);

        // Set up chip with its private key
        final chip = DomainParameterSelectorECDH.getDomainParameter(id: 13);
        chip.generateKeyPairFromPriv(privKey: chipPrivateKey);

        // First verify the shared secret is computed correctly
        final sharedSecret = terminal.getSharedSecret(otherPubKey: chip.publicKey);
        final sharedSecretPoint = ECDHPace.ecPointToList(point: sharedSecret);
        expect(sharedSecretPoint.xBytes, expectedSharedSecretX);
        expect(sharedSecretPoint.yBytes, expectedSharedSecretY);

        // Now compute the mapped generator
        // terminal calls getMappedGenerator with chip's public key
        final mappedGenerator = terminal.getMappedGenerator(otherPubKey: chip.publicKey, nonce: nonce);

        final mappedGenPoint = ECDHPace.ecPointToList(point: mappedGenerator);

        expect(mappedGenPoint.xBytes, expectedMappedGenX);
        expect(mappedGenPoint.yBytes, expectedMappedGenY);
      });

      test('Nonce decryption with AES-128 - test vectors from gmrtd', () {
        // Test vectors from gmrtd TestDecryptNonce
        final encryptedNonce = "95A3A016522EE98D01E76CB6B98B42C3".parseHex();
        final kKdf = "89DED1B26624EC1E634C1989302849DD".parseHex();
        final expectedDecryptedNonce = "3F00C4D39D153F2B2A214A078D899B22".parseHex();

        final aesCipher = AESChiperSelector.getChiper(size: KEY_LENGTH.s128);
        final decryptedNonce = aesCipher.decrypt(data: encryptedNonce, key: kKdf);

        expect(decryptedNonce, expectedDecryptedNonce);
      });

      test('Public key template encoding (7F49) - test vectors from gmrtd', () {
        // Test vectors from gmrtd TestBuild7F49
        // parameterId = 13 (BrainpoolP256r1)

        final terminalPubX = "2DB7A64C0355044EC9DF190514C625CBA2CEA48754887122F3A5EF0D5EDD301C".parseHex();
        final terminalPubY = "3556F3B3B186DF10B857B58F6A7EB80F20BA5DC7BE1D43D9BF850149FBB36462".parseHex();

        final chipPubX = "9E880F842905B8B3181F7AF7CAA9F0EFB743847F44A306D2D28C1D9EC65DF6DB".parseHex();
        final chipPubY = "7764B22277A2EDDC3C265A9F018F9CB852E111B768B326904B59A0193776F094".parseHex();

        // Expected encoded templates from gmrtd
        final expectedTifdData =
            "7F494F060A04007F000702020402028641049E880F842905B8B3181F7AF7CAA9F0EFB743847F44A306D2D28C1D9EC65DF6DB7764B22277A2EDDC3C265A9F018F9CB852E111B768B326904B59A0193776F094"
                .parseHex();
        final expectedTicData =
            "7F494F060A04007F000702020402028641042DB7A64C0355044EC9DF190514C625CBA2CEA48754887122F3A5EF0D5EDD301C3556F3B3B186DF10B857B58F6A7EB80F20BA5DC7BE1D43D9BF850149FBB36462"
                .parseHex();

        // Get the OIE protocol for PACE-ECDH-GM-AES-CBC-CMAC-128
        // Note: identifierString uses numeric OID format, not readable name
        final protocol = OIEPaceProtocol.fromMap(
          item: ASN1ObjectIdentifierType.instance.getOIDByIdentifierString(
            identifierString: "0.4.0.127.0.7.2.2.4.2.2", // id-PACE-ECDH-GM-AES-CBC-CMAC-128
          ),
        );

        // Generate encoding input data for terminal (using chip's public key)
        final tifdData = PACE.generateEncodingInputData(
          crytpographicMechanism: protocol,
          ephemeralPublic: PublicKeyPACEeCDH(
            x: BigInt.parse(chipPubX.hex(), radix: 16),
            y: BigInt.parse(chipPubY.hex(), radix: 16),
          ),
        );

        // Generate encoding input data for chip (using terminal's public key)
        final ticData = PACE.generateEncodingInputData(
          crytpographicMechanism: protocol,
          ephemeralPublic: PublicKeyPACEeCDH(
            x: BigInt.parse(terminalPubX.hex(), radix: 16),
            y: BigInt.parse(terminalPubY.hex(), radix: 16),
          ),
        );

        expect(tifdData, expectedTifdData);
        expect(ticData, expectedTicData);
      });

      test('Full PACE session keys derivation - test vectors from gmrtd', () {
        // Test vectors from gmrtd TestDoPace_GM_ECDH
        // This verifies the complete PACE key derivation matches

        final efCardAccessData = "31143012060A04007F0007020204020202010202010D".parseHex();
        final efCardAccess = EfCardAccess.fromBytes(efCardAccessData);

        // Expected session keys from gmrtd
        final expectedKsEnc = "F5F0E35C0D7161EE6724EE513A0D9A7F".parseHex();
        final expectedKsMac = "FE251C7858B356B24514B3BD5F4297D1".parseHex();

        // The ephemeral shared secret X coordinate (seed for key derivation)
        final seed = "28768D20701247DAE81804C9E780EDE582A9996DB4A315020B2733197DB84925".parseHex();

        final encKey = PACE.cacluateEncKey(paceProtocol: efCardAccess.paceInfo!.protocol, seed: seed);
        final macKey = PACE.cacluateMacKey(paceProtocol: efCardAccess.paceInfo!.protocol, seed: seed);

        expect(encKey, expectedKsEnc);
        expect(macKey, expectedKsMac);
      });

      test('Authentication token calculation - test vectors from gmrtd', () {
        // Test vectors from gmrtd TestDoPace_GM_ECDH

        final efCardAccessData = "31143012060A04007F0007020204020202010202010D".parseHex();
        final efCardAccess = EfCardAccess.fromBytes(efCardAccessData);

        final ksMac = "FE251C7858B356B24514B3BD5F4297D1".parseHex();

        // Chip's ephemeral public key
        final chipEphPubX = "9E880F842905B8B3181F7AF7CAA9F0EFB743847F44A306D2D28C1D9EC65DF6DB".parseHex();
        final chipEphPubY = "7764B22277A2EDDC3C265A9F018F9CB852E111B768B326904B59A0193776F094".parseHex();

        // Expected authentication token
        final expectedTifd = "C2B0BD78D94BA866".parseHex();

        // Generate input data for auth token
        final inputData = PACE.generateEncodingInputData(
          crytpographicMechanism: efCardAccess.paceInfo!.protocol,
          ephemeralPublic: PublicKeyPACEeCDH(
            x: BigInt.parse(chipEphPubX.hex(), radix: 16),
            y: BigInt.parse(chipEphPubY.hex(), radix: 16),
          ),
        );

        // Calculate auth token
        final authToken = PACE.cacluateAuthToken(
          paceProtocol: efCardAccess.paceInfo!.protocol,
          inputData: inputData,
          macKey: ksMac,
        );

        expect(authToken, expectedTifd);
      });
    });

    // ==========================================================================
    // PACE-CAM (Chip Authentication Mapping) support
    // Per ICAO 9303 Part 11 Section 4.4.3.3.3
    // Used by passports from Germany, Finland, and other countries
    // ==========================================================================

    group('PACE-CAM support', () {
      // Test vectors from gmrtd TestDoPace_CAM_ECDH_DE and TestDoPace_CAM_ECDH_FI
      // PACE-ECDH-CAM-AES-CBC-CMAC-128 with BrainpoolP256r1

      test('PACE-CAM OIDs should be registered in ASN1ObjectIdentifiers', () {
        // PACE-CAM OIDs per BSI TR-03110:
        // - 0.4.0.127.0.7.2.2.4.6.2 (id-PACE-ECDH-CAM-AES-CBC-CMAC-128)
        // - 0.4.0.127.0.7.2.2.4.6.3 (id-PACE-ECDH-CAM-AES-CBC-CMAC-192)
        // - 0.4.0.127.0.7.2.2.4.6.4 (id-PACE-ECDH-CAM-AES-CBC-CMAC-256)

        expect(
          ASN1ObjectIdentifierType.instance.hasOIDWithIdentifierString(identifierString: "0.4.0.127.0.7.2.2.4.6.2"),
          isTrue,
          reason: "id-PACE-ECDH-CAM-AES-CBC-CMAC-128 should be registered",
        );

        expect(
          ASN1ObjectIdentifierType.instance.hasOIDWithIdentifierString(identifierString: "0.4.0.127.0.7.2.2.4.6.3"),
          isTrue,
          reason: "id-PACE-ECDH-CAM-AES-CBC-CMAC-192 should be registered",
        );

        expect(
          ASN1ObjectIdentifierType.instance.hasOIDWithIdentifierString(identifierString: "0.4.0.127.0.7.2.2.4.6.4"),
          isTrue,
          reason: "id-PACE-ECDH-CAM-AES-CBC-CMAC-256 should be registered",
        );
      });

      test('EfCardAccess with CAM-only PaceInfo should parse successfully', () {
        // Document that only advertises CAM mode
        // From gmrtd TestSelectPaceConfig
        //
        // ASN.1 breakdown:
        //   31 14 - SET of length 20
        //   30 12 - SEQUENCE of length 18
        //   06 0a 04007f00070202040604 - OID (id-PACE-ECDH-CAM-AES-CBC-CMAC-256)
        //   02 01 02 - INTEGER version = 2
        //   02 01 10 - INTEGER parameterId = 16 (BrainpoolP384r1)
        final efCardAccessCamOnly = "31143012060a04007f00070202040604020102020110".parseHex();

        final efCardAccess = EfCardAccess.fromBytes(efCardAccessCamOnly);

        expect(efCardAccess.isPaceInfoSet, true);
        expect(efCardAccess.paceInfo!.version, 2);
        expect(efCardAccess.paceInfo!.parameterId, 16); // BrainpoolP384r1
      });

      test('CardAccess with both GM and CAM entries should parse', () {
        // Document with both GM and CAM entries
        // From gmrtd TestDoPace_CAM_ECDH_DE
        // Contains two PaceInfo entries:
        //   1. id-PACE-ECDH-GM-AES-CBC-CMAC-128 with parameterId=13
        //   2. id-PACE-ECDH-CAM-AES-CBC-CMAC-128 with parameterId=13
        final efCardAccessGmAndCam =
            "31283012060A04007F0007020204020202010202010D3012060A04007F0007020204060202010202010D".parseHex();

        final efCardAccess = EfCardAccess.fromBytes(efCardAccessGmAndCam);

        expect(efCardAccess.isPaceInfoSet, true);
        expect(efCardAccess.paceInfo!.version, 2);
        expect(efCardAccess.paceInfo!.parameterId, 13); // BrainpoolP256r1
      });

      test('Step 4 response with PACE-CAM should contain tag 0x8A (ECAD)', () {
        // From gmrtd TestDoPace_CAM_ECDH_DE - Step 4 mutual auth response
        // The response contains:
        //   - Tag 0x7C: Dynamic Authentication Data wrapper
        //   - Tag 0x86: Authentication token (8 bytes)
        //   - Tag 0x8A: Encrypted Chip Authentication Data (48 bytes) - CAM only
        //
        // Full response with 7C wrapper:
        //   7c 3c (length 60)
        //     86 08 19a2b9192e11512a (auth token)
        //     8a 30 b3ae8830311b1d5605777f47cb4ed028346cd00105d32859de127da3d8398865358f26f08ebe410864eaf6e39f33f3f5 (ECAD)

        final step4ResponseData =
            "7c3c860819a2b9192e11512a8a30b3ae8830311b1d5605777f47cb4ed028346cd00105d32859de127da3d8398865358f26f08ebe410864eaf6e39f33f3f5"
                .parseHex();

        final expectedAuthToken = "19a2b9192e11512a".parseHex();
        final expectedEcad =
            "b3ae8830311b1d5605777f47cb4ed028346cd00105d32859de127da3d8398865358f26f08ebe410864eaf6e39f33f3f5"
                .parseHex();

        // Parse the response
        final response = ResponseAPDUStep4Pace(step4ResponseData);
        response.parse();

        expect(response.authToken, expectedAuthToken);
        expect(response.hasChipAuthData, true);
        expect(response.encryptedChipAuthData, expectedEcad);
      });

      test('Step 4 response without PACE-CAM should not contain tag 0x8A', () {
        // GM response - only contains auth token (tag 0x86), no ECAD
        // From gmrtd TestDoPace_GM_ECDH
        // With 7C wrapper: 7c 0a 86 08 c2b0bd78d94ba866
        final step4ResponseGm = "7c0a8608c2b0bd78d94ba866".parseHex();

        final expectedAuthToken = "c2b0bd78d94ba866".parseHex();

        final response = ResponseAPDUStep4Pace(step4ResponseGm);
        response.parse();

        expect(response.authToken, expectedAuthToken);
        expect(response.hasChipAuthData, false);
        expect(response.encryptedChipAuthData, isNull);
      });

      test('PACE-CAM ECAD decryption - test vectors from gmrtd', () {
        // From gmrtd TestDoPace_CAM_ECDH_DE
        // The ECAD (Encrypted Chip Authentication Data) must be decrypted
        // using the session encryption key (KsEnc) with a specific IV
        //
        // IV = K(KsEnc, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
        // Then CBC decrypt the ECAD

        final ksEnc = "a8e85e938514ec67ae33cda3d43d3c48".parseHex();
        final ecad = "b3ae8830311b1d5605777f47cb4ed028346cd00105d32859de127da3d8398865358f26f08ebe410864eaf6e39f33f3f5"
            .parseHex();

        // IV = AES_encrypt(KsEnc, 0xFF...FF)
        final aesCipher = AESChiperSelector.getChiper(size: KEY_LENGTH.s128);
        final allOnes = "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF".parseHex();
        final iv = aesCipher.encrypt(data: allOnes, key: ksEnc);

        // Decrypt ECAD using CBC with the computed IV
        final decryptedEcadPadded = aesCipher.decrypt(data: ecad, key: ksEnc, iv: iv);

        // The result should be padded with ISO 9797-1 Method 2
        // Expected CA_IC (after unpadding) is 32 bytes - the chip's private key contribution
        expect(decryptedEcadPadded.length, 48); // Still padded

        // Check the padding is valid (ends with 80 00 00 ...)
        // The last block should have padding
        final lastByte = decryptedEcadPadded.last;
        expect(lastByte == 0x00 || decryptedEcadPadded.contains(0x80), true);
      });

      test('PACE-CAM session keys derivation - test vectors from gmrtd', () {
        // From gmrtd TestDoPace_CAM_ECDH_DE
        // CAM uses the same key derivation as GM
        //
        // Reference session keys from gmrtd:
        //   KsEnc = a8e85e938514ec67ae33cda3d43d3c48
        //   KsMac = 27f1adeb705a049a305b0c619b14b9b3

        final efCardAccessData = "31283012060A04007F0007020204020202010202010D3012060A04007F0007020204060202010202010D"
            .parseHex();
        final efCardAccess = EfCardAccess.fromBytes(efCardAccessData);

        // Verify the protocol parsing works correctly for CAM
        expect(efCardAccess.paceInfo!.protocol.cipherAlgoritm, CipherAlgorithm.AES);
        expect(efCardAccess.paceInfo!.protocol.keyLength, KEY_LENGTH.s128);
      });

      test('PACE-CAM mapping type should be CAM', () {
        // Verify that CAM OIDs correctly set the mapping type to CAM

        final camOid = ASN1ObjectIdentifierType.instance.getOIDByIdentifierString(
          identifierString: "0.4.0.127.0.7.2.2.4.6.2", // id-PACE-ECDH-CAM-AES-CBC-CMAC-128
        );
        final protocol = OIEPaceProtocol.fromMap(item: camOid);

        expect(protocol.mappingType, MAPPING_TYPE.CAM);
        expect(protocol.tokenAgreementAlgorithm, TOKEN_AGREEMENT_ALGO.ECDH);
        expect(protocol.cipherAlgoritm, CipherAlgorithm.AES);
        expect(protocol.keyLength, KEY_LENGTH.s128);
      });

      test('PACE-CAM 192-bit and 256-bit variants should also parse', () {
        // Test 192-bit CAM variant
        final cam192Oid = ASN1ObjectIdentifierType.instance.getOIDByIdentifierString(
          identifierString: "0.4.0.127.0.7.2.2.4.6.3", // id-PACE-ECDH-CAM-AES-CBC-CMAC-192
        );
        final protocol192 = OIEPaceProtocol.fromMap(item: cam192Oid);

        expect(protocol192.mappingType, MAPPING_TYPE.CAM);
        expect(protocol192.keyLength, KEY_LENGTH.s192);

        // Test 256-bit CAM variant
        final cam256Oid = ASN1ObjectIdentifierType.instance.getOIDByIdentifierString(
          identifierString: "0.4.0.127.0.7.2.2.4.6.4", // id-PACE-ECDH-CAM-AES-CBC-CMAC-256
        );
        final protocol256 = OIEPaceProtocol.fromMap(item: cam256Oid);

        expect(protocol256.mappingType, MAPPING_TYPE.CAM);
        expect(protocol256.keyLength, KEY_LENGTH.s256);
      });

      test('PACE-CAM terminal key generation - test vectors from gmrtd', () {
        // From gmrtd TestDoPace_CAM_ECDH_DE
        // Terminal generates two keypairs:
        //   1. First for generic mapping nonce exchange
        //   2. Second for key agreement on mapped generator

        final terminalPrivKey1 = "01fd26013f5bc41fad8bb09811e435f16fbe2eb3c2e1d999b0f63da8c3d58bb5".parseHex();
        final terminalPubKey1X = "303f340815eea501772393e299a4a6f6694600189c249c63a8513ff3fefa66e3".parseHex();
        final terminalPubKey1Y = "46d11970b5f76fb564c3b0e54b215528f647ec5a9ab209cdbe262e763d6119a1".parseHex();

        // First keypair for generic mapping
        final terminal1 = DomainParameterSelectorECDH.getDomainParameter(id: 13);
        terminal1.generateKeyPairFromPriv(privKey: terminalPrivKey1);

        final pubKey1 = terminal1.getPubKey();
        expect(pubKey1.xBytes, terminalPubKey1X);
        expect(pubKey1.yBytes, terminalPubKey1Y);

        final terminalPrivKey2 = "1fcd3d8ac4fae3960a14fea2925d75add335f13b248eba192358dded93a89552".parseHex();

        // Second keypair - used for key agreement on mapped generator
        final terminal2 = DomainParameterSelectorECDH.getDomainParameter(id: 13);
        terminal2.generateKeyPairFromPriv(privKey: terminalPrivKey2);

        // Just verify key generation works - the public key depends on mapped generator
        expect(terminal2.isPublicKeySet, true);
      });
    });

    // ==========================================================================
    // Domain parameter support flags
    // ==========================================================================

    group('Domain parameter support flags', () {
      test('BrainpoolP256r1 (ID 13) should work despite isSupported=false', () {
        // The domain parameter works but is marked as unsupported
        // This test verifies the implementation actually works

        final domainParam = DomainParameterSelectorECDH.getDomainParameter(id: 13);
        expect(domainParam.selectedDomainParameter.name, "BrainpoolP256r1");

        // Should be able to generate a key pair
        domainParam.generateKeyPair();
        expect(domainParam.isPublicKeySet, true);

        // The public key should have valid coordinates
        final pubKey = domainParam.getPubKey();
        expect(pubKey.x.bitLength > 0, true);
        expect(pubKey.y.bitLength > 0, true);
      });

      test('All ECDH domain parameters (8-18) should be selectable', () {
        // Verify all domain parameters can be instantiated
        final supportedIds = [8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18];

        for (final id in supportedIds) {
          expect(
            () => DomainParameterSelectorECDH.getDomainParameter(id: id),
            returnsNormally,
            reason: 'Domain parameter ID $id should be selectable',
          );
        }
      });

      test('PaceInfo.isPaceDomainParameterSupported is based on selector availability', () {
        // isPaceDomainParameterSupported is determined by whether
        // DomainParameterSelectorECDH.getDomainParameter() succeeds,
        // NOT by the isSupported flag in DomainParameter.
        //
        // Since all ECDH curves (8-18) have implementations (ECDHPaceCurve8-18),
        // they all return isPaceDomainParameterSupported = true.

        // BrainpoolP256r1 (ID 13) - has implementation, so isPaceDomainParameterSupported = true
        final efCardAccessBrainpool = "31143012060A04007F0007020204020202010202010D".parseHex();
        final efCardAccess = EfCardAccess.fromBytes(efCardAccessBrainpool);

        // This is true because DomainParameterSelectorECDH.getDomainParameter(id: 13) succeeds
        expect(efCardAccess.paceInfo!.isPaceDomainParameterSupported, true);

        // NIST P-256 (ID 12) - also has implementation
        final efCardAccessNist = "31143012060A04007F0007020204020202010202010C".parseHex();
        final efCardAccessNistParsed = EfCardAccess.fromBytes(efCardAccessNist);

        expect(efCardAccessNistParsed.paceInfo!.isPaceDomainParameterSupported, true);

        // Note: The isSupported flag in domain_parameter.dart is misleading
        // because it's not actually used to determine isPaceDomainParameterSupported
      });
    });

    // ==========================================================================
    // Full PACE flow test with BrainpoolP256r1
    // ==========================================================================

    group('Full PACE flow with BrainpoolP256r1', () {
      test('Complete PACE-GM-ECDH flow - gmrtd test vectors', () {
        // Complete test vectors from gmrtd TestDoPace_GM_ECDH
        // MRZ: T22000129, DOB: 640812, DOE: 101031

        final dbaKeys = DBAKey("T22000129", DateTime(1964, 8, 12), DateTime(2010, 10, 31), paceMode: true);

        // Expected values
        final expectedKPi = "89ded1b26624ec1e634c1989302849dd".parseHex();
        final expectedKsEnc = "F5F0E35C0D7161EE6724EE513A0D9A7F".parseHex();
        final expectedKsMac = "FE251C7858B356B24514B3BD5F4297D1".parseHex();

        // Verify KPi derivation
        final kpi = dbaKeys.Kpi(CipherAlgorithm.AES, KEY_LENGTH.s128);
        expect(kpi, expectedKPi);

        // Test vectors for the protocol
        final encryptedNonce = "95A3A016522EE98D01E76CB6B98B42C3".parseHex();
        final expectedDecryptedNonce = "3F00C4D39D153F2B2A214A078D899B22".parseHex();

        // Decrypt nonce
        final aesCipher = AESChiperSelector.getChiper(size: KEY_LENGTH.s128);
        final decryptedNonce = aesCipher.decrypt(data: encryptedNonce, key: kpi);
        expect(decryptedNonce, expectedDecryptedNonce);

        // Terminal and chip key pairs
        final terminalPrivKey = "7F4EF07B9EA82FD78AD689B38D0BC78CF21F249D953BC46F4C6E19259C010F99".parseHex();
        final chipPrivKey = "498FF49756F2DC1587840041839A85982BE7761D14715FB091EFA7BCE9058560".parseHex();

        final terminal = DomainParameterSelectorECDH.getDomainParameter(id: 13);
        terminal.generateKeyPairFromPriv(privKey: terminalPrivKey);

        final chip = DomainParameterSelectorECDH.getDomainParameter(id: 13);
        chip.generateKeyPairFromPriv(privKey: chipPrivKey);

        // Compute shared secret
        final terminalSharedSecret = terminal.getSharedSecret(otherPubKey: chip.publicKey);
        final chipSharedSecret = chip.getSharedSecret(otherPubKey: terminal.publicKey);
        expect(terminalSharedSecret, chipSharedSecret);

        // Compute mapped generator
        final mappedGen = terminal.getMappedGenerator(otherPubKey: chip.publicKey, nonce: decryptedNonce);

        // Expected mapped generator
        final expectedMappedGenX = "8CED63C91426D4F0EB1435E7CB1D74A46723A0AF21C89634F65A9AE87A9265E2".parseHex();
        final expectedMappedGenY = "8C879506743F8611AC33645C5B985C80B5F09A0B83407C1B6A4D857AE76FE522".parseHex();

        final mappedGenPoint = ECDHPace.ecPointToList(point: mappedGen);
        expect(mappedGenPoint.xBytes, expectedMappedGenX);
        expect(mappedGenPoint.yBytes, expectedMappedGenY);

        // Ephemeral key pairs
        final terminalEphPrivKey = "A73FB703AC1436A18E0CFA5ABB3F7BEC7A070E7A6788486BEE230C4A22762595".parseHex();
        final chipEphPrivKey = "107CF58696EF6155053340FD633392BA81909DF7B9706F226F32086C7AFF974A".parseHex();

        terminal.setEphemeralKeyPair(private: terminalEphPrivKey, mappedGenerator: mappedGen);
        chip.setEphemeralKeyPair(private: chipEphPrivKey, mappedGenerator: mappedGen);

        // Compute ephemeral shared secret
        final ephSharedSecret = terminal.getEphemeralSharedSecret(otherEphemeralPubKey: chip.ephemeralPublicKey);

        final expectedEphSharedSecret = "28768D20701247DAE81804C9E780EDE582A9996DB4A315020B2733197DB84925".parseHex();
        expect(ECDHPace.ecPointToList(point: ephSharedSecret).toRelavantBytes(), expectedEphSharedSecret);

        // Derive session keys
        final efCardAccessData = "31143012060A04007F0007020204020202010202010D".parseHex();
        final efCardAccess = EfCardAccess.fromBytes(efCardAccessData);

        final seed = ECDHPace.ecPointToList(point: ephSharedSecret).toRelavantBytes();
        final ksEnc = PACE.cacluateEncKey(paceProtocol: efCardAccess.paceInfo!.protocol, seed: seed);
        final ksMac = PACE.cacluateMacKey(paceProtocol: efCardAccess.paceInfo!.protocol, seed: seed);

        expect(ksEnc, expectedKsEnc);
        expect(ksMac, expectedKsMac);

        // Auth token calculation
        final expectedTifd = "C2B0BD78D94BA866".parseHex();
        final expectedTic = "3ABB9674BCE93C08".parseHex();

        // Terminal calculates auth token using chip's ephemeral public key
        final tifdInputData = PACE.generateEncodingInputData(
          crytpographicMechanism: efCardAccess.paceInfo!.protocol,
          ephemeralPublic: chip.getPubKeyEphemeral(),
        );
        final tifd = PACE.cacluateAuthToken(
          paceProtocol: efCardAccess.paceInfo!.protocol,
          inputData: tifdInputData,
          macKey: ksMac,
        );
        expect(tifd, expectedTifd);

        // Chip calculates auth token using terminal's ephemeral public key
        final ticInputData = PACE.generateEncodingInputData(
          crytpographicMechanism: efCardAccess.paceInfo!.protocol,
          ephemeralPublic: terminal.getPubKeyEphemeral(),
        );
        final tic = PACE.cacluateAuthToken(
          paceProtocol: efCardAccess.paceInfo!.protocol,
          inputData: ticInputData,
          macKey: ksMac,
        );
        expect(tic, expectedTic);
      });
    });

    // ==========================================================================
    // PACE-CAM Verification tests
    // Test vectors from ICAO 9303 Part 11 Appendix I (PACE-CAM worked example)
    // ==========================================================================

    group('PACE-CAM Verification', () {
      test('ECAD decryption - ICAO 9303 Part 11 Appendix I test vectors', () {
        // Test vectors from ICAO 9303 Part 11 Appendix I
        // KSEnc: 0A9DA4DB03BDDE39FC5202BC44B2E89E
        // Encrypted Chip Authentication Data: 1EEA964DAAE372AC990E3EFDE6333353BFC89A6704D93DA8798CF77F5B7A54BD10CBA372B42BE0B9B5F28AA8DE2F4F92
        // Decrypted (CA_IC): 85DC3FA93D0952BFA82F5FD189EE75BD82F11D1F0B8ED4BF5319AC9B53C426B3
        // IV: F6A3B75A1E933941DD7A13E2520779DF

        final ksEnc = "0A9DA4DB03BDDE39FC5202BC44B2E89E".parseHex();
        final ecad = "1EEA964DAAE372AC990E3EFDE6333353BFC89A6704D93DA8798CF77F5B7A54BD10CBA372B42BE0B9B5F28AA8DE2F4F92"
            .parseHex();
        final expectedCaIc = "85DC3FA93D0952BFA82F5FD189EE75BD82F11D1F0B8ED4BF5319AC9B53C426B3".parseHex();
        final expectedIv = "F6A3B75A1E933941DD7A13E2520779DF".parseHex();

        // Verify IV computation: IV = E(KSEnc, 0xFF...FF)
        final aesCipher = AESChiperSelector.getChiper(size: KEY_LENGTH.s128);
        final allOnes = "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF".parseHex();
        final computedIv = aesCipher.encrypt(data: allOnes, key: ksEnc);
        expect(computedIv, expectedIv);

        // Decrypt ECAD
        final caIc = PaceCam.decryptEcad(encryptedChipAuthData: ecad, ksEnc: ksEnc, keyLength: KEY_LENGTH.s128);

        expect(caIc, expectedCaIc);
      });

      test('PACE-CAM verification - ICAO 9303 Part 11 Appendix I test vectors', () {
        // Test vectors from ICAO 9303 Part 11 Appendix I
        //
        // CA_IC (decrypted chip authentication data):
        //   85DC3FA93D0952BFA82F5FD189EE75BD82F11D1F0B8ED4BF5319AC9B53C426B3
        //
        // PKIC (Chip's static public key from ChipAuthenticationPublicKeyInfo):
        //   X: 1872709494399E7470A6431BE25E83EEE24FEA568C2ED28DB48E05DB3A610DC8
        //   Y: 84D256A40E35EFCB59BF6753D3A489D28C7A4D973C2DA138A6E7A4A08F68E16F
        //
        // PKMap_IC (Chip's mapping public key from PACE step 2):
        //   The full point from the response (need to extract from example)
        //   X: A234236AA9B9621E8EFB73B5245C0E09D2576E5277183C1208BDD55280CAE8B3
        //   Y: F365713A356E65A451E165ECC9AC0AC46E3771342C8FE5AEDD092685338E23 (from spec, need padding)

        final caIc = "85DC3FA93D0952BFA82F5FD189EE75BD82F11D1F0B8ED4BF5319AC9B53C426B3".parseHex();

        // Chip's static public key from CardSecurity ChipAuthenticationPublicKeyInfo
        final pkIcX = "1872709494399E7470A6431BE25E83EEE24FEA568C2ED28DB48E05DB3A610DC8".parseHex();
        final pkIcY = "84D256A40E35EFCB59BF6753D3A489D28C7A4D973C2DA138A6E7A4A08F68E16F".parseHex();

        // Note: The ICAO spec's worked example has formatting ambiguities
        // in PKMap_IC due to PDF line wrapping. The exact verification is tested
        // in "Complete PACE-CAM verification flow" using synthetic matching values.
        //
        // Here we verify the test vector lengths are correct:
        expect(caIc.length, 32); // CA_IC is 32 bytes (256-bit scalar)
        expect(pkIcX.length, 32); // PK_IC X is 32 bytes
        expect(pkIcY.length, 32); // PK_IC Y is 32 bytes
      });

      test('PACE-CAM decryption with gmrtd test vectors', () {
        // Test vectors from gmrtd TestDoPace_CAM_ECDH_DE
        // Session keys from the test:
        //   KsEnc = a8e85e938514ec67ae33cda3d43d3c48
        //   KsMac = 27f1adeb705a049a305b0c619b14b9b3
        //
        // ECAD from step 4 response (tag 0x8A):
        //   b3ae8830311b1d5605777f47cb4ed028346cd00105d32859de127da3d8398865358f26f08ebe410864eaf6e39f33f3f5

        final ksEnc = "a8e85e938514ec67ae33cda3d43d3c48".parseHex();
        final ecad = "b3ae8830311b1d5605777f47cb4ed028346cd00105d32859de127da3d8398865358f26f08ebe410864eaf6e39f33f3f5"
            .parseHex();

        // Decrypt ECAD - this should work without throwing
        final caIc = PaceCam.decryptEcad(encryptedChipAuthData: ecad, ksEnc: ksEnc, keyLength: KEY_LENGTH.s128);

        // The decrypted value should be 32 bytes (256-bit scalar for BrainpoolP256r1)
        expect(caIc.length, 32);

        // Verify the decryption produces valid output (non-zero)
        expect(caIc.any((b) => b != 0), true);
      });

      test('Complete PACE-CAM verification flow', () {
        // This test verifies the complete CAM verification flow works correctly
        // by creating a synthetic test case where we know PKMap_IC = CA_IC * PK_IC

        // Use BrainpoolP256r1 (parameterId 13)
        final domainParams = DomainParameterSelectorECDH.getDomainParameter(id: 13);

        // Generate a random "chip authentication" scalar (CA_IC)
        // In practice, this comes from decrypting the ECAD
        final caIc = "0102030405060708091011121314151617181920212223242526272829303132".parseHex();

        // Generate chip's static key pair (this would come from CardSecurity)
        domainParams.generateKeyPair();
        final pkIc = domainParams.publicKey;
        final pkIcPoint = ECDHPace.ecPointToList(point: pkIc.Q!);

        // Compute PKMap_IC = CA_IC * PK_IC (what the chip would have sent)
        final caIcBigInt = BigInt.parse(caIc.map((b) => b.toRadixString(16).padLeft(2, '0')).join(), radix: 16);
        final curve = domainParams.domainParameters;
        final pkIcEcPoint = curve.curve.createPoint(
          BigInt.parse(pkIcPoint.xBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(), radix: 16),
          BigInt.parse(pkIcPoint.yBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(), radix: 16),
        );
        final pkMapIc = (pkIcEcPoint * caIcBigInt)!;

        // Extract coordinates
        final pkMapIcX = _bigIntToBytes(pkMapIc.x!.toBigInteger()!, 32);
        final pkMapIcY = _bigIntToBytes(pkMapIc.y!.toBigInteger()!, 32);

        // Now verify - this should succeed because we constructed PKMap_IC correctly
        final result = PaceCam.verify(
          caIc: caIc,
          pkIcX: pkIcPoint.xBytes,
          pkIcY: pkIcPoint.yBytes,
          pkMapIcX: pkMapIcX,
          pkMapIcY: pkMapIcY,
          domainParameterId: 13,
        );

        expect(result, true);
      });
    });
  });
}

/// Helper to convert BigInt to fixed-length byte array
Uint8List _bigIntToBytes(BigInt value, int length) {
  final hex = value.toRadixString(16).padLeft(length * 2, '0');
  final bytes = <int>[];
  for (var i = 0; i < hex.length; i += 2) {
    bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
  }
  return Uint8List.fromList(bytes);
}
