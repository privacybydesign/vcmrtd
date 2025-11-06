import 'dart:convert';
import 'dart:typed_data';

import 'package:vcmrtd/vcmrtd.dart';
import '../extension/byte_reader.dart';
import '../lds/df1/dLicenceDGs.dart';

import 'document_parser.dart';

class DrivingLicenceParser extends DocumentParser<DrivingLicenceData> {
  // TLV tag constants for DG1
  static const int _DG1_CONTAINER_TAG = 0x5F02;
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

  // Groups with parsing logic
  DrivingLicenceEfDG1? _dg1;
  DrivingLicenceEfDG6? _dg6;

  // Raw bytes for other data groups
  Uint8List? _dg2RawBytes;
  Uint8List? _dg3RawBytes;
  Uint8List? _dg4RawBytes;
  Uint8List? _dg5RawBytes;
  Uint8List? _dg7RawBytes;
  Uint8List? _dg8RawBytes;
  Uint8List? _dg9RawBytes;
  Uint8List? _dg10RawBytes;
  Uint8List? _dg11RawBytes;
  Uint8List? _dg12RawBytes;
  Uint8List? _dg13RawBytes;
  Uint8List? _dg14RawBytes;

  @override
  DrivingLicenceData createDocument() {
    return DrivingLicenceData(
      // DG1 - holder information
      issuingMemberState: _dg1?.issuingMemberState,
      holderSurname: _dg1?.holderSurname,
      holderOtherName: _dg1?.holderOtherName,
      dateOfBirth: _dg1?.dateOfBirth,
      placeOfBirth: _dg1?.placeOfBirth,
      dateOfIssue: _dg1?.dateOfIssue,
      dateOfExpiry: _dg1?.dateOfExpiry,
      issuingAuthority: _dg1?.issuingAuthority,
      documentNumber: _dg1?.documentNumber,

      // DG6 - photo
      photoImageData: _dg6?.imageData,
      photoImageType: _dg6?.imageType,

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
    int offset = 0;
    final bytesLength = bytes.length;

    // Temporary storage for building the object
    String? issuingMemberState;
    String? holderSurname;
    String? holderOtherName;
    String? dateOfBirth;
    String? placeOfBirth;
    String? dateOfIssue;
    String? dateOfExpiry;
    String? issuingAuthority;
    String? documentNumber;

    while (offset < bytesLength) {
      try {
        final tagValue = TLV.decode(bytes.sublist(offset));

        // Parse nested TLVs inside container tag
        if (tagValue.tag.value == _DG1_CONTAINER_TAG) {
          int innerOffset = 0;
          final innerBytes = tagValue.value;

          while (innerOffset < innerBytes.length) {
            try {
              final tlv = TLV.decode(innerBytes.sublist(innerOffset));

              switch (tlv.tag.value) {
                case _ISSUING_MEMBER_STATE_TAG:
                  issuingMemberState = utf8.decode(tlv.value);
                  break;
                case _HOLDER_SURNAME_TAG:
                  holderSurname = utf8.decode(tlv.value);
                  break;
                case _HOLDER_OTHER_NAME_TAG:
                  holderOtherName = utf8.decode(tlv.value);
                  break;
                case _DATE_OF_BIRTH_TAG:
                  dateOfBirth = _decodeBcd(tlv.value);
                  break;
                case _PLACE_OF_BIRTH_TAG:
                  placeOfBirth = utf8.decode(tlv.value);
                  break;
                case _DATE_OF_ISSUE_TAG:
                  dateOfIssue = _decodeBcd(tlv.value);
                  break;
                case _DATE_OF_EXPIRY_TAG:
                  dateOfExpiry = _decodeBcd(tlv.value);
                  break;
                case _ISSUING_AUTHORITY_TAG:
                  issuingAuthority = utf8.decode(tlv.value);
                  break;
                case _DOCUMENT_NUMBER_TAG:
                  documentNumber = utf8.decode(tlv.value);
                  break;
              }

              innerOffset += tlv.encodedLen;
            } catch (e) {
              break;
            }
          }
        }

        offset += tagValue.encodedLen;
      } catch (e) {
        break;
      }
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
    );
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
  }

  @override
  void parseDG6(Uint8List bytes) {
    final tlv = TLV.fromBytes(bytes);

    if (tlv.tag == _BIOMETRIC_GROUP_TEMPLATE_TAG) {
      _parseBiometricGroup(tlv.value);
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
    if (!reader.hasRemaining(4) ||
        bytes[0] != 0x46 ||
        bytes[1] != 0x41 ||
        bytes[2] != 0x43 ||
        bytes[3] != 0x00) {
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
  }

  @override
  void parseDG13(Uint8List bytes) {
    _dg13RawBytes = bytes;
  }

  @override
  void parseDG14(Uint8List bytes) {
    _dg14RawBytes = bytes;
  }
}
