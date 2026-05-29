import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:vcmrtd/src/extension/uint8list_apis.dart';
import 'package:vcmrtd/vcmrtd.dart';
import '../extension/byte_reader.dart';

import 'document_parser.dart';

class DrivingLicenceParser extends DocumentParser<DrivingLicenceData> {
  DrivingLicenceParser({required this.failDg1CategoriesGracefully});

  // TLV tag constants for DG1
  static const int _DG1_MAIN_TAG = 0x5F02;
  static const int _DG1_SECONDARY_TAG = 0x7F63;
  static const int _ISSUING_MEMBER_STATE_TAG = 0x5F03;
  static const int _HOLDER_SURNAME_TAG = 0x5F04;
  static const int _HOLDER_OTHER_NAME_TAG = 0x5F05;
  static const int _DATE_OF_BIRTH_TAG = 0x5F06;
  static const int _PLACE_OF_BIRTH_TAG = 0x5F07;
  static const int _DATE_OF_ISSUE_TAG = 0x5F0A;
  static const int _DATE_OF_EXPIRY_TAG = 0x5F0B;
  static const int _ISSUING_AUTHORITY_TAG = 0x5F0C;
  static const int _DOCUMENT_NUMBER_TAG = 0x5F0E;

  // TLV tag constants for DG6 (biometric data)
  static const int _BIOMETRIC_GROUP_TEMPLATE_TAG = 0x7F61;
  static const int _BIOMETRIC_INFO_TEMPLATE_TAG = 0x7F60;
  static const int _BIOMETRIC_DATA_BLOCK_TAG = 0x5F2E;

  // TLV tag constants for DG5 (signature)
  static const int _SIGNATURE_IMAGE_FORMAT_TAG = 0x89;
  static const int _SIGNATURE_IMAGE_DATA_TAG = 0X5F43;

  final bool failDg1CategoriesGracefully;

  // Groups with parsing logic
  late DrivingLicenceEfDG1 _dg1;
  DrivingLicenceEfDG5? _dg5;
  late DrivingLicenceEfDG6 _dg6;
  late DrivingLicenceEfDG13 _dg13;
  late DrivingLicenceEfDG12 _dg12;

  // Raw bytes for other data groups
  Uint8List? _dg2RawBytes;
  Uint8List? _dg3RawBytes;
  Uint8List? _dg4RawBytes;
  Uint8List? _dg5RawBytes;
  Uint8List? _dg7RawBytes;
  Uint8List? _dg8RawBytes;
  Uint8List? _dg9RawBytes;
  Uint8List? _dg10RawBytes;
  late Uint8List _dg11RawBytes;
  late Uint8List _dg12RawBytes;
  Uint8List? _dg13RawBytes;
  Uint8List? _dg14RawBytes;

  @override
  bool documentContainsDataGroup(DataGroups dg) {
    return com.dgTags.contains(_tagForDataGroup(dg));
  }

  DgTag? _tagForDataGroup(DataGroups dg) {
    return switch (dg) {
      DataGroups.dg1 => DrivingLicenceEfDG1.TAG,
      DataGroups.dg2 => null,
      DataGroups.dg3 => null,
      DataGroups.dg4 => null,
      DataGroups.dg5 => DrivingLicenceEfDG5.TAG,
      DataGroups.dg6 => DrivingLicenceEfDG6.TAG,
      DataGroups.dg7 => DrivingLicenceEfDG7.TAG,
      DataGroups.dg8 => null,
      DataGroups.dg9 => null,
      DataGroups.dg10 => null,
      DataGroups.dg11 => DrivingLicenceEfDG11.TAG,
      DataGroups.dg12 => DrivingLicenceEfDG12.TAG,
      DataGroups.dg13 => DrivingLicenceEfDG13.TAG,
      DataGroups.dg14 => null,
      DataGroups.dg15 => null,
      DataGroups.dg16 => null,
    };
  }

  @override
  DrivingLicenceData createDocument() {
    return DrivingLicenceData(
      // DG1 - holder information
      issuingMemberState: _dg1.issuingMemberState,
      holderSurname: _dg1.holderSurname,
      holderOtherName: _dg1.holderOtherName,
      dateOfBirth: _dg1.dateOfBirth,
      placeOfBirth: _dg1.placeOfBirth,
      dateOfIssue: _dg1.dateOfIssue,
      dateOfExpiry: _dg1.dateOfExpiry,
      issuingAuthority: _dg1.issuingAuthority,
      documentNumber: _dg1.documentNumber,
      categories: _dg1.categories,

      // DG5 - signature image
      signatureImageType: _dg5?.imageType,
      signatureImageData: _dg5?.imageData,

      // DG6 - photo
      photoImageData: _dg6.imageData,
      photoImageType: _dg6.imageType,

      // DG12 - BAP input and SAI content for Non-Match Alert
      bapInputString: _dg12.bapInputString,
      saiType: _dg12.saiType,

      // DG13 - Active auth public key
      aaPublicKey: _dg13.aaPublicKey,

      // Raw bytes for other data groups
      dg2RawBytes: _dg2RawBytes,
      dg3RawBytes: _dg3RawBytes,
      dg4RawBytes: _dg4RawBytes,
      dg5RawBytes: _dg5RawBytes,
      dg7RawBytes: _dg7RawBytes,
      dg8RawBytes: _dg8RawBytes,
      dg9RawBytes: _dg9RawBytes,
      dg10RawBytes: _dg10RawBytes,
      dg11RawBytes: _dg11RawBytes,
      dg12RawBytes: _dg12RawBytes,
      dg13RawBytes: _dg13RawBytes,
      dg14RawBytes: _dg14RawBytes,
    );
  }

  @override
  void parseDG1(Uint8List bytes) {
    // Unwrap outer 0x61 tag
    final outerTlv = TLV.decode(bytes);
    final childrenBytes = outerTlv.value;

    // Temporary storage for building the object
    late String issuingMemberState;
    late String holderSurname;
    late String holderOtherName;
    late String dateOfBirth;
    late String placeOfBirth;
    late String dateOfIssue;
    late String dateOfExpiry;
    late String issuingAuthority;
    late String documentNumber;
    late List<DrivingLicenceCategory> categories;

    // Loop through siblings inside 0x61 (0x5F01, 0x5F02, etc.)
    int offset = 0;
    while (offset < childrenBytes.length) {
      final tlv = TLV.decode(childrenBytes.sublist(offset));

      // Found 0x5F02 container with personal data
      if (tlv.tag.value == _DG1_MAIN_TAG) {
        int fieldOffset = 0;
        final fieldBytes = tlv.value;

        // Parse fields inside 0x5F02
        while (fieldOffset < fieldBytes.length) {
          final fieldTlv = _withContext(
            "Decoding TLV (fieldOffset: $fieldBytes)",
            () => TLV.decode(fieldBytes.sublist(fieldOffset)),
            sensitive: "Field bytes: ${fieldBytes.hex()}",
          );

          final value = fieldTlv.value;
          final hex = value.hex();

          switch (fieldTlv.tag.value) {
            case _ISSUING_MEMBER_STATE_TAG:
              issuingMemberState = _withContext(
                "Parsing issuing member state",
                () => utf8.decode(value),
                sensitive: hex,
              );
            case _HOLDER_SURNAME_TAG:
              holderSurname = _withContext("Parsing holder surname", () => latin1.decode(value), sensitive: hex);
            case _HOLDER_OTHER_NAME_TAG:
              holderOtherName = _withContext("Parsing holder other name", () => latin1.decode(value), sensitive: hex);
            case _DATE_OF_BIRTH_TAG:
              dateOfBirth = _withContext("Parsing date of birth", () => _decodeBcd(value), sensitive: hex);
            case _PLACE_OF_BIRTH_TAG:
              placeOfBirth = _withContext("Parsing place of birth", () => latin1.decode(value), sensitive: hex);
            case _DATE_OF_ISSUE_TAG:
              dateOfIssue = _withContext("Parsing date of issue", () => _decodeBcd(value), sensitive: hex);
            case _DATE_OF_EXPIRY_TAG:
              dateOfExpiry = _withContext("Parsing date of expiry", () => _decodeBcd(value), sensitive: hex);
            case _ISSUING_AUTHORITY_TAG:
              issuingAuthority = _withContext("Parsing issuing authority", () => latin1.decode(value), sensitive: hex);
            case _DOCUMENT_NUMBER_TAG:
              documentNumber = _withContext("Parsing document number", () => latin1.decode(value), sensitive: hex);
          }

          fieldOffset += fieldTlv.encodedLen;
        }
      } else if (tlv.tag.value == _DG1_SECONDARY_TAG) {
        try {
          categories = _parseCategories(tlv);
        } catch (e) {
          if (failDg1CategoriesGracefully) {
            debugPrint("failed to parse categories: $e");
            categories = [];
          } else {
            throw Exception("Failed to parse categories: $e");
          }
        }
      }
      offset += tlv.encodedLen;
    }

    _dg1 = DrivingLicenceEfDG1(
      issuingMemberState: issuingMemberState,
      holderSurname: holderSurname,
      holderOtherName: holderOtherName,
      dateOfBirth: dateOfBirth,
      placeOfBirth: placeOfBirth,
      dateOfIssue: dateOfIssue,
      dateOfExpiry: dateOfExpiry,
      issuingAuthority: issuingAuthority,
      documentNumber: documentNumber,
      categories: categories,
    );
  }

  /// Runs the provided function and wraps the exception thrown by it with some extra context
  T _withContext<T>(String context, T Function() toExecute, {String? sensitive}) {
    try {
      return toExecute();
    } catch (e) {
      throw SensitiveException(nonSensitive: "Error in context: $context:\n$e", sensitive: sensitive);
    }
  }

  List<DrivingLicenceCategory> _parseCategories(DecodedTV tlv) {
    // Parse field for category / restrictions / conditions
    // Note: category is usually the first record and is mandatory, restrictions and conditions
    // May not apply to the driver
    List<DrivingLicenceCategory> categories = [];

    int categoryOffset = 0;
    while (categoryOffset < tlv.value.length) {
      final categoryTlv = TLV.decode(tlv.value.sublist(categoryOffset));

      if (categoryTlv.tag.value == 0x87) {
        final bytes = categoryTlv.value;

        // The delimiter is a semicolon  category; issue date (bcd); expiry date (bcd)
        int firstSemicolon = bytes.indexOf(0x3b);
        if (firstSemicolon == -1) continue;

        final category = utf8.decode(bytes.sublist(0, firstSemicolon));

        // Issue date: 4 bytes after first semicolon (DD MM YY YY in BCD/hex)
        if (bytes.length >= firstSemicolon + 5) {
          final issueDay = bytes[firstSemicolon + 1].toRadixString(16).padLeft(2, '0');
          final issueMonth = bytes[firstSemicolon + 2].toRadixString(16).padLeft(2, '0');
          final issueYear =
              '${bytes[firstSemicolon + 3].toRadixString(16).padLeft(2, '0')}${bytes[firstSemicolon + 4].toRadixString(16).padLeft(2, '0')}';

          // Expiry date: 4 bytes after second semicolon
          if (bytes.length >= firstSemicolon + 10) {
            final expiryDay = bytes[firstSemicolon + 6].toRadixString(16).padLeft(2, '0');
            final expiryMonth = bytes[firstSemicolon + 7].toRadixString(16).padLeft(2, '0');
            final expiryYear =
                '${bytes[firstSemicolon + 8].toRadixString(16).padLeft(2, '0')}${bytes[firstSemicolon + 9].toRadixString(16).padLeft(2, '0')}';

            categories.add(
              DrivingLicenceCategory(
                category: category,
                dateOfIssue: '$issueDay/$issueMonth/$issueYear',
                dateOfExpiry: '$expiryDay/$expiryMonth/$expiryYear',
              ),
            );
          }
        }
      }
      categoryOffset += categoryTlv.encodedLen;
    }
    return categories;
  }

  String _decodeBcd(List<int> bcd) {
    return bcd.map((b) {
      final high = (b >> 4) & 0x0F;
      final low = b & 0x0F;
      return '$high$low';
    }).join();
  }

  @override
  void parseDG2(Uint8List bytes) {
    _dg2RawBytes = bytes;
  }

  @override
  void parseDG3(Uint8List bytes) {
    _dg3RawBytes = bytes;
  }

  @override
  void parseDG4(Uint8List bytes) {
    _dg4RawBytes = bytes;
  }

  @override
  void parseDG5(Uint8List bytes) {
    _dg5RawBytes = bytes;
    ImageType? signatureImageType;
    Uint8List? signatureImageData;
    // Unwrap outer tag 0x67
    final outerTlv = TLV.fromBytes(bytes);

    int offset = 0;
    while (offset < outerTlv.value.length) {
      final innerTlv = TLV.decode(outerTlv.value.sublist(offset));

      switch (innerTlv.tag.value) {
        case _SIGNATURE_IMAGE_FORMAT_TAG:
          final formatByte = innerTlv.value[0];
          signatureImageType = formatByte == 0x03 ? ImageType.jpeg : ImageType.jpeg2000;

        case _SIGNATURE_IMAGE_DATA_TAG:
          signatureImageData = innerTlv.value;
      }

      offset += innerTlv.encodedLen;
    }

    if (signatureImageData != null && signatureImageType != null) {
      _dg5 = DrivingLicenceEfDG5(imageData: signatureImageData, imageType: signatureImageType);
    } else {
      throw Exception("Something went wrong with EDL DG5 parsing");
    }
  }

  @override
  void parseDG6(Uint8List bytes) {
    // Unwrap outer 0x75 tag
    final outerTlv = TLV.fromBytes(bytes);

    final innerTlv = TLV.decode(outerTlv.value);

    // Look for 0x7F61 inner tag inside
    if (innerTlv.tag.value == _BIOMETRIC_GROUP_TEMPLATE_TAG) {
      _parseBiometricGroup(innerTlv.value);
    }
  }

  void _parseBiometricGroup(Uint8List bytes) {
    int offset = 0;

    while (offset < bytes.length) {
      final tlv = TLV.decode(bytes.sublist(offset));

      if (tlv.tag.value == _BIOMETRIC_INFO_TEMPLATE_TAG) {
        _parseBiometricTemplate(tlv.value);
      }

      offset += tlv.encodedLen;
    }
  }

  void _parseBiometricTemplate(Uint8List bytes) {
    int offset = 0;

    while (offset < bytes.length) {
      final tlv = TLV.decode(bytes.sublist(offset));

      if (tlv.tag.value == _BIOMETRIC_DATA_BLOCK_TAG) {
        _parseFacialImageData(tlv.value);
      }

      offset += tlv.encodedLen;
    }
  }

  void _parseFacialImageData(Uint8List bytes) {
    final reader = ByteReader(bytes);

    // Verify "FAC\0" header
    if (!reader.hasRemaining(4) || bytes[0] != 0x46 || bytes[1] != 0x41 || bytes[2] != 0x43 || bytes[3] != 0x00) {
      _dg6 = DrivingLicenceEfDG6(imageData: bytes, imageType: null);
      return;
    }
    reader.skip(4); // Skip "FAC\0"

    final versionNumber = reader.readInt(4);
    final lengthOfRecord = reader.readInt(4);
    final numberOfFacialImages = reader.readInt(2);
    final facialRecordDataLength = reader.readInt(4);
    final nrFeaturePoints = reader.readInt(2);
    final gender = reader.readInt(1);
    final eyeColor = reader.readInt(1);
    final hairColor = reader.readInt(1);
    final featureMask = reader.readInt(3);
    final expression = reader.readInt(2);
    final poseAngle = reader.readInt(3);
    final poseAngleUncertainty = reader.readInt(3);

    reader.skip(nrFeaturePoints * 8); // Skip feature points

    final faceImageType = reader.readInt(1);
    final imageDataType = reader.readInt(1);
    final imageType = imageDataType == 0 ? ImageType.jpeg : ImageType.jpeg2000;
    final imageWidth = reader.readInt(2);
    final imageHeight = reader.readInt(2);
    final imageColorSpace = reader.readInt(1);
    final sourceType = reader.readInt(1);
    final deviceType = reader.readInt(2);
    final quality = reader.readInt(2);
    final imageData = reader.readBytes(bytes.length - reader.position);

    _dg6 = DrivingLicenceEfDG6(
      versionNumber: versionNumber,
      lengthOfRecord: lengthOfRecord,
      numberOfFacialImages: numberOfFacialImages,
      facialRecordDataLength: facialRecordDataLength,
      nrFeaturePoints: nrFeaturePoints,
      gender: gender,
      eyeColor: eyeColor,
      hairColor: hairColor,
      featureMask: featureMask,
      expression: expression,
      poseAngle: poseAngle,
      poseAngleUncertainty: poseAngleUncertainty,
      faceImageType: faceImageType,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      imageColorSpace: imageColorSpace,
      sourceType: sourceType,
      deviceType: deviceType,
      quality: quality,
      imageData: imageData,
      imageType: imageType,
    );
  }

  @override
  void parseDG7(Uint8List bytes) {
    _dg7RawBytes = bytes;
  }

  @override
  void parseDG8(Uint8List bytes) {
    _dg8RawBytes = bytes;
  }

  @override
  void parseDG9(Uint8List bytes) {
    _dg9RawBytes = bytes;
  }

  @override
  void parseDG10(Uint8List bytes) {
    _dg10RawBytes = bytes;
  }

  @override
  void parseDG11(Uint8List bytes) {
    _dg11RawBytes = bytes;
  }

  @override
  void parseDG12(Uint8List bytes) {
    _dg12RawBytes = bytes;

    // Unwrap outer 0x71 tag
    final outerTlv = TLV.fromBytes(bytes);

    String? bapInputString;
    String? saiType;

    int offset = 0;
    while (offset < outerTlv.value.length) {
      final tlv = TLV.decode(outerTlv.value.sublist(offset));

      switch (tlv.tag.value) {
        case 0x82: // 2-29 of MRZ (BAP input string)
          // First byte is '00', then 28 chars of BAP input
          if (tlv.value.length > 1) {
            bapInputString = utf8.decode(tlv.value.sublist(1));
          }

        case 0x81: // Shows type of SAI (MRZ or other kinds) according to ISO18013-3 part 8.3.2.5.5
          saiType = tlv.value[0] == 0x41 ? 'MRZ' : 'UNKNOWN';
      }

      offset += tlv.encodedLen;
    }

    _dg12 = DrivingLicenceEfDG12(bapInputString: bapInputString ?? '', saiType: saiType ?? '');
  }

  @override
  void parseDG13(Uint8List bytes) {
    _dg13RawBytes = bytes;

    // Unwrap outer 0x6F tag
    final outerTlv = TLV.fromBytes(bytes);

    _dg13 = DrivingLicenceEfDG13(aaPublicKey: AAPublicKey.fromBytes(outerTlv.value));
  }

  @override
  void parseDG14(Uint8List bytes) {
    _dg14RawBytes = bytes;
  }

  @override
  void parseDG15(Uint8List bytes) {
    throw UnimplementedError("Data Group 15 doesn't exist for Driving Licences");
  }

  @override
  void parseDG16(Uint8List bytes) {
    throw UnimplementedError("Data Group 16 doesn't exist for Driving Licences");
  }
}
