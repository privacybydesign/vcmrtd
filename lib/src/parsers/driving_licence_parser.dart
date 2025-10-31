import 'dart:convert';
import 'dart:typed_data';

import 'package:vcmrtd/src/models/document.dart';
import 'package:vcmrtd/vcmrtd.dart';
import '../lds/df1/dLicenceDGs.dart';

import 'document_parser.dart';

class DrivingLicenceParser extends DocumentParser<DrivingLicenceData> {
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

        // Parse nested TLVs inside 0x5F02 tag
        if (tagValue.tag.value == 0x5F02) {
          int innerOffset = 0;
          final innerBytes = tagValue.value;

          while (innerOffset < innerBytes.length) {
            try {
              final tlv = TLV.decode(innerBytes.sublist(innerOffset));

              switch (tlv.tag.value) {
                case 0x5F03: // ISSUING_MEMBER_STATE_TAG
                  issuingMemberState = utf8.decode(tlv.value);
                  break;
                case 0x5F04: // HOLDER_SURNAME_TAG
                  holderSurname = utf8.decode(tlv.value);
                  break;
                case 0x5F05: // HOLDER_OTHER_NAME_TAG
                  holderOtherName = utf8.decode(tlv.value);
                  break;
                case 0x5F06: // DATE_OF_BIRTH_TAG
                  dateOfBirth = _decodeBcd(tlv.value);
                  break;
                case 0x5F07: // PLACE_OF_BIRTH_TAG
                  placeOfBirth = utf8.decode(tlv.value);
                  break;
                case 0x5F0A: // DATE_OF_ISSUE_TAG
                  dateOfIssue = _decodeBcd(tlv.value);
                  break;
                case 0x5F0B: // DATE_OF_EXPIRY_TAG
                  dateOfExpiry = _decodeBcd(tlv.value);
                  break;
                case 0x5F0C: // ISSUING_AUTHORITY_TAG
                  issuingAuthority = utf8.decode(tlv.value);
                  break;
                case 0x5F0E: // DOCUMENT_NUMBER_TAG
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

    if (tlv.tag == 0x7F61) { // BIOMETRIC_INFORMATION_GROUP_TEMPLATE_TAG
      _parseBiometricGroup(tlv.value);
    }
  }

  void _parseBiometricGroup(Uint8List bytes) {
    int offset = 0;

    while (offset < bytes.length) {
      final tlv = TLV.decode(bytes.sublist(offset));

      if (tlv.tag.value == 0x7F60) { // BIOMETRIC_INFORMATION_TEMPLATE_TAG
        _parseBiometricTemplate(tlv.value);
      }

      offset += tlv.encodedLen;
    }
  }

  void _parseBiometricTemplate(Uint8List bytes) {
    int offset = 0;

    while (offset < bytes.length) {
      final tlv = TLV.decode(bytes.sublist(offset));

      if (tlv.tag.value == 0x5F2E) { // BIOMETRIC_DATA_BLOCK_TAG
        _parseFacialImageData(tlv.value);
      }

      offset += tlv.encodedLen;
    }
  }

  void _parseFacialImageData(Uint8List bytes) {
    // Verify "FAC\0" header
    if (bytes.length < 4 ||
        bytes[0] != 0x46 ||
        bytes[1] != 0x41 ||
        bytes[2] != 0x43 ||
        bytes[3] != 0x00) {
      // Try to use raw data anyway
      _dg6 = DrivingLicenceEfDG6(
        imageData: bytes,
        imageType: null,
      );
      return;
    }

    int offset = 4;

    // Version number (4 bytes)
    final versionNumber = _extractInt(bytes, offset, 4);
    offset += 4;

    // Length of record (4 bytes)
    final lengthOfRecord = _extractInt(bytes, offset, 4);
    offset += 4;

    // Number of facial images (2 bytes)
    final numberOfFacialImages = _extractInt(bytes, offset, 2);
    offset += 2;

    // Facial record data length (4 bytes)
    final facialRecordDataLength = _extractInt(bytes, offset, 4);
    offset += 4;

    // Number of feature points (2 bytes)
    final nrFeaturePoints = _extractInt(bytes, offset, 2);
    offset += 2;

    // Gender (1 byte)
    final gender = _extractInt(bytes, offset, 1);
    offset += 1;

    // Eye color (1 byte)
    final eyeColor = _extractInt(bytes, offset, 1);
    offset += 1;

    // Hair color (1 byte)
    final hairColor = _extractInt(bytes, offset, 1);
    offset += 1;

    // Feature mask (3 bytes)
    final featureMask = _extractInt(bytes, offset, 3);
    offset += 3;

    // Expression (2 bytes)
    final expression = _extractInt(bytes, offset, 2);
    offset += 2;

    // Pose angle (3 bytes)
    final poseAngle = _extractInt(bytes, offset, 3);
    offset += 3;

    // Pose angle uncertainty (3 bytes)
    final poseAngleUncertainty = _extractInt(bytes, offset, 3);
    offset += 3;

    // Skip feature points (8 bytes each)
    offset += nrFeaturePoints * 8;

    // Face image type (1 byte)
    final faceImageType = _extractInt(bytes, offset, 1);
    offset += 1;

    // Image data type (1 byte) - 0 = JPEG, 1 = JPEG2000
    final imageDataType = bytes[offset];
    final imageType = imageDataType == 0 ? ImageType.jpeg : ImageType.jpeg2000;
    offset += 1;

    // Image width (2 bytes)
    final imageWidth = _extractInt(bytes, offset, 2);
    offset += 2;

    // Image height (2 bytes)
    final imageHeight = _extractInt(bytes, offset, 2);
    offset += 2;

    // Image color space (1 byte)
    final imageColorSpace = _extractInt(bytes, offset, 1);
    offset += 1;

    // Source type (1 byte)
    final sourceType = _extractInt(bytes, offset, 1);
    offset += 1;

    // Device type (2 bytes)
    final deviceType = _extractInt(bytes, offset, 2);
    offset += 2;

    // Quality (2 bytes)
    final quality = _extractInt(bytes, offset, 2);
    offset += 2;

    // Now the actual image data starts
    final imageData = bytes.sublist(offset);

    // Create DrivingLicenceEfDG6 object
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

  int _extractInt(Uint8List data, int start, int length) {
    if (length == 1) {
      return data[start];
    } else if (length == 2) {
      return (data[start] << 8) | data[start + 1];
    } else if (length == 3) {
      return (data[start] << 16) | (data[start + 1] << 8) | data[start + 2];
    } else if (length == 4) {
      return (data[start] << 24) |
      (data[start + 1] << 16) |
      (data[start + 2] << 8) |
      data[start + 3];
    }
    return 0;
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