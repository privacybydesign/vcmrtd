// Created by Crt Vavros, copyright © 2022 ZeroPass. All rights reserved.
// ignore_for_file: constant_identifier_names

import 'dart:typed_data';

import 'package:logging/logging.dart';
import 'package:pointycastle/asn1/asn1_parser.dart';
import 'package:pointycastle/asn1/primitives/asn1_sequence.dart';

import 'ef.dart';
import 'substruct/security_infos.dart';

class EfCardSecurity extends ElementaryFile {
  static const FID = 0x011D;
  static const SFI = 0x1D;

  static final _log = Logger('EfCardSecurity');

  SecurityInfos? _securityInfos;
  SecurityInfos? get securityInfos => _securityInfos;

  EfCardSecurity.fromBytes(super.data) : super.fromBytes();

  @override
  int get fid => FID;

  @override
  int get sfi => SFI;

  @override
  void parse(Uint8List content) {
    _log.fine('Parsing EF.CardSecurity (${content.length} bytes)');

    // EF.CardSecurity is a CMS SignedData (RFC 3369) wrapping SecurityInfos.
    // Structure:
    //   SEQUENCE (ContentInfo)
    //     OID signedData (1.2.840.113549.1.7.2)
    //     [0] SEQUENCE (SignedData)
    //       INTEGER version
    //       SET digestAlgorithms
    //       SEQUENCE (EncapsulatedContentInfo)
    //         OID (id-SecurityObject)
    //         [0] OCTET STRING (eContent = DER-encoded SecurityInfos SET)
    //       ...
    //
    // We extract the eContent and parse it as SecurityInfos.
    final secInfosBytes = _extractEContent(content);
    if (secInfosBytes == null) {
      _log.warning('Could not extract SecurityInfos from EF.CardSecurity');
      return;
    }

    _securityInfos = SecurityInfos.parse(secInfosBytes);
    _log.fine(
      'Parsed EF.CardSecurity: '
      'chipAuthPubKeyInfos=${_securityInfos!.chipAuthenticationPublicKeyInfos.length}',
    );
  }

  /// Extracts the eContent (SecurityInfos SET) from CMS SignedData.
  static Uint8List? _extractEContent(Uint8List data) {
    try {
      final parser = ASN1Parser(data);
      if (!parser.hasNext()) return null;

      // ContentInfo SEQUENCE
      final contentInfo = parser.nextObject();
      if (contentInfo is! ASN1Sequence) return null;
      final ciElements = contentInfo.elements;
      if (ciElements == null || ciElements.length < 2) return null;

      // [0] EXPLICIT wrapping SignedData
      final signedDataWrapper = ciElements[1];
      final sdParser = ASN1Parser(signedDataWrapper.valueBytes);
      if (!sdParser.hasNext()) return null;

      // SignedData SEQUENCE
      final signedData = sdParser.nextObject();
      if (signedData is! ASN1Sequence) return null;
      final sdElements = signedData.elements;
      if (sdElements == null || sdElements.length < 3) return null;

      // sdElements[0] = version (INTEGER)
      // sdElements[1] = digestAlgorithms (SET)
      // sdElements[2] = encapContentInfo (SEQUENCE)
      final encapContentInfo = sdElements[2];
      if (encapContentInfo is! ASN1Sequence) return null;
      final eciElements = encapContentInfo.elements;
      if (eciElements == null || eciElements.length < 2) return null;

      // eciElements[0] = eContentType (OID)
      // eciElements[1] = [0] EXPLICIT OCTET STRING containing SecurityInfos
      final eContentWrapper = eciElements[1];

      // The [0] EXPLICIT wrapper contains an OCTET STRING
      final eContentParser = ASN1Parser(eContentWrapper.valueBytes);
      if (!eContentParser.hasNext()) return null;
      final eContentObj = eContentParser.nextObject();

      // The OCTET STRING value is the DER-encoded SecurityInfos SET
      return Uint8List.fromList(eContentObj.valueBytes!);
    } catch (e) {
      _log.warning('Failed to extract eContent from CMS SignedData: $e');
      return null;
    }
  }
}
