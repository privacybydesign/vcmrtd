import 'dart:convert';
import 'dart:typed_data';

import 'package:vcmrtd/extensions.dart';
import 'package:vcmrtd/src/parsers/data_groups.dart';

import '../../vcmrtd.dart';
import '../extension/byte_reader.dart';
import '../lds/df1/passportDGs.dart';
import 'document_parser.dart';

class PassportParser implements DocumentParser<PassportData> {
  static const int BIOMETRIC_INFORMATION_GROUP_TEMPLATE_TAG = 0x7F61;
  static const int BIOMETRIC_INFORMATION_COUNT_TAG = 0x02;
  static const int BIOMETRIC_INFORMATION_TEMPLATE_TAG = 0x7F60;
  static const int BIOMETRIC_HEADER_TEMPLATE_TAG = 0xA1;
  static const int BIOMETRIC_DATA_BLOCK_TAG_PRIMARY = 0x5F2E;
  static const int BIOMETRIC_DATA_BLOCK_TAG_ALTERNATE = 0x7F2E;
  static const int SMT_TAG = 0x7D;

  static const int TAG_LIST_TAG = 0x5C;

  static const int FULL_NAME_TAG = 0x5F0E;
  static const int OTHER_NAME_TAG = 0x5F0F;
  static const int PERSONAL_NUMBER_TAG = 0x5F10;
  static const int PLACE_OF_BIRTH_TAG = 0x5F11;
  static const int TELEPHONE_TAG = 0x5F12;
  static const int PROFESSION_TAG = 0x5F13;
  static const int TITLE_TAG = 0x5F14;
  static const int PERSONAL_SUMMARY_TAG = 0x5F15;
  static const int PROOF_OF_CITIZENSHIP_TAG = 0x5F16;
  static const int OTHER_VALID_TD_NUMBERS_TAG = 0x5F17;
  static const int CUSTODY_INFORMATION_TAG = 0x5F18;
  static const int ISSUING_AUTHORITY_TAG = 0x5F19;
  static const int FULL_DATE_OF_BIRTH_TAG = 0x5F2B;
  static const int PERMANENT_ADDRESS_TAG = 0x5F42;
  static const int DATE_OF_ISSUE_TAG = 0x5F26;

  // Only DG1 and DG2 is mandatory
  late PassportEfDG1 _dg1;
  late PassportEfDG2 _dg2;
  PassportEfDG11? _dg11;
  PassportEfDG12? _dg12;
  PassportEfDG15? _dg15;

  Uint8List? _dg3RawBytes;
  Uint8List? _dg4RawBytes;
  Uint8List? _dg5RawBytes;
  Uint8List? _dg6RawBytes;
  Uint8List? _dg7RawBytes;
  Uint8List? _dg8RawBytes;
  Uint8List? _dg9RawBytes;
  Uint8List? _dg10RawBytes;
  Uint8List? _dg13RawBytes;
  Uint8List? _dg14RawBytes;
  Uint8List? _dg16RawBytes;

  @override
  DgTag tagForDataGroup(DataGroups dg) {
    return switch (dg) {
      DataGroups.dg1 => PassportEfDG1.TAG,
      DataGroups.dg2 => PassportEfDG2.TAG,
      DataGroups.dg3 => PassportEfDG3.TAG,
      DataGroups.dg4 => PassportEfDG4.TAG,
      DataGroups.dg5 => PassportEfDG5.TAG,
      DataGroups.dg6 => PassportEfDG6.TAG,
      DataGroups.dg7 => PassportEfDG7.TAG,
      DataGroups.dg8 => PassportEfDG8.TAG,
      DataGroups.dg9 => PassportEfDG9.TAG,
      DataGroups.dg10 => PassportEfDG10.TAG,
      DataGroups.dg11 => PassportEfDG11.TAG,
      DataGroups.dg12 => PassportEfDG12.TAG,
      DataGroups.dg13 => PassportEfDG13.TAG,
      DataGroups.dg14 => PassportEfDG14.TAG,
      DataGroups.dg15 => PassportEfDG15.TAG,
      DataGroups.dg16 => PassportEfDG16.TAG,
    };
  }

  @override
  PassportData createDocument() {
    return PassportData(
      // DG1 - required
      mrz: _dg1.mrz,

      // DG2 - photo (extract key fields)
      photoImageData: _dg2.imageData,
      photoImageType: _dg2.imageType,
      photoImageWidth: _dg2.imageWidth,
      photoImageHeight: _dg2.imageHeight,

      // DG11 - additional personal details
      nameOfHolder: _dg11?.nameOfHolder,
      otherNames: _dg11?.otherNames,
      personalNumber: _dg11?.personalNumber,
      fullDateOfBirth: _dg11?.fullDateOfBirth,
      placeOfBirth: _dg11?.placeOfBirth,
      permanentAddress: _dg11?.permanentAddress,
      telephone: _dg11?.telephone,
      profession: _dg11?.profession,
      title: _dg11?.title,
      personalSummary: _dg11?.personalSummary,
      proofOfCitizenship: _dg11?.proofOfCitizenship,
      otherValidTDNumbers: _dg11?.otherValidTDNumbers,
      custodyInformation: _dg11?.custodyInformation,

      // DG12 - document details
      dateOfIssue: _dg12?.dateOfIssue,
      issuingAuthority: _dg12?.issuingAuthority,

      // DG15 - active auth
      aaPublicKey: _dg15?.aaPublicKey,

      // Raw bytes
      dg3RawBytes: _dg3RawBytes,
      dg4RawBytes: _dg4RawBytes,
      dg5RawBytes: _dg5RawBytes,
      dg6RawBytes: _dg6RawBytes,
      dg7RawBytes: _dg7RawBytes,
      dg8RawBytes: _dg8RawBytes,
      dg9RawBytes: _dg9RawBytes,
      dg10RawBytes: _dg10RawBytes,
      dg13RawBytes: _dg13RawBytes,
      dg14RawBytes: _dg14RawBytes,
      dg16RawBytes: _dg16RawBytes,
    );
  }

  @override
  PassportEfDG1? parseDG1(Uint8List bytes) {
    final tlv = TLV.fromBytes(bytes);

    if (tlv.tag != PassportEfDG1.TAG.value) {
      throw EfParseError("Invalid tag=${tlv.tag.hex()}, expected tag=${PassportEfDG1.TAG.value.hex()}");
    }

    final mrzTlv = TLV.fromBytes(tlv.value);
    if (mrzTlv.tag != 0x5F1F) {
      throw EfParseError("Invalid MRZ tag=${mrzTlv.tag.hex()}, expected tag=5F1F");
    }

    final mrz = PassportMRZ(mrzTlv.value);
    _dg1 = PassportEfDG1(mrz);

    return _dg1;
  }

  @override
  void parseDG2(Uint8List bytes) {
    final tlv = TLV.fromBytes(bytes);
    if (tlv.tag != PassportEfDG2.TAG.value) {
      throw EfParseError("Invalid DG2 tag=${tlv.tag.hex()}, expected tag=${PassportEfDG2.TAG.value.hex()}");
    }

    final data = tlv.value;
    final bigt = TLV.decode(data);
    if (bigt.tag.value != BIOMETRIC_INFORMATION_GROUP_TEMPLATE_TAG) {
      throw EfParseError(
        "Invalid object tag=${bigt.tag.value.hex()}, expected tag=${BIOMETRIC_INFORMATION_GROUP_TEMPLATE_TAG.hex()}",
      );
    }

    final bict = TLV.decode(bigt.value);
    if (bict.tag.value != BIOMETRIC_INFORMATION_COUNT_TAG) {
      throw EfParseError(
        "Invalid object tag=${bict.tag.value.hex()}, expected tag=${BIOMETRIC_INFORMATION_COUNT_TAG.hex()}",
      );
    }
    int bitCount = (bict.value[0] & 0xFF);
    for (var i = 0; i < bitCount; i++) {
      _parseBIT(bigt.value.sublist(bict.encodedLen), i);
    }
  }

  void _parseBIT(Uint8List stream, int index) {
    final tvl = TLV.decode(stream);
    if (tvl.tag.value != BIOMETRIC_INFORMATION_TEMPLATE_TAG) {
      throw EfParseError(
        "Invalid object tag=${tvl.tag.value.hex()}, expected tag=${BIOMETRIC_INFORMATION_TEMPLATE_TAG.hex()}",
      );
    }
    var bht = TLV.decode(tvl.value);
    if (bht.tag.value == SMT_TAG) {
      // TODO: Statically protected BIT not implemented
    } else if ((bht.tag.value & 0xA0) == 0xA0) {
      var sbh = _parseBHT(tvl.value);
      _parseBiometricDataBlock(sbh);
    }
  }

  List<DecodedTV> _parseBHT(Uint8List stream) {
    final bht = TLV.decode(stream);
    if (bht.tag.value != BIOMETRIC_HEADER_TEMPLATE_TAG) {
      throw EfParseError(
        "Invalid object tag=${bht.tag.value.hex()}, expected tag=${BIOMETRIC_HEADER_TEMPLATE_TAG.hex()}",
      );
    }
    int bhtLength = stream.length;
    int bytesRead = bht.encodedLen;
    var elements = <DecodedTV>[];
    while (bytesRead < bhtLength) {
      final tlv = TLV.decode(stream.sublist(bytesRead));
      bytesRead += tlv.encodedLen;
      elements.add(tlv);
    }
    return elements;
  }

  PassportEfDG2? _parseBiometricDataBlock(List<DecodedTV> sbh) {
    final firstBlock = sbh.first;
    if (firstBlock.tag.value != BIOMETRIC_DATA_BLOCK_TAG_PRIMARY &&
        firstBlock.tag.value != BIOMETRIC_DATA_BLOCK_TAG_ALTERNATE) {
      throw EfParseError(
        "Invalid object tag=${firstBlock.tag.value.hex()}, expected tag=${BIOMETRIC_DATA_BLOCK_TAG_PRIMARY.hex()} or ${BIOMETRIC_DATA_BLOCK_TAG_ALTERNATE.hex()}",
      );
    }
    final data = firstBlock.value;
    final br = ByteReader(data);
    if (!br.hasRemaining(4)) {
      throw EfParseError("Biometric data block too short");
    }
    final header = br.readBytes(4);
    if (header[0] != 0x46 || header[1] != 0x41 || header[2] != 0x43 || header[3] != 0x00) {
      throw EfParseError("Biometric data block invalid (missing FAC\\0 header)");
    }
    final versionNumber = br.readInt(4);
    if (versionNumber != 0x30313000) {
      throw EfParseError("Invalid biometric data version");
    }
    final lengthOfRecord = br.readInt(4);
    final numberOfFacialImages = br.readInt(2);
    final facialRecordDataLength = br.readInt(4);
    final nrFeaturePoints = br.readInt(2);
    final gender = br.readInt(1);
    final eyeColor = br.readInt(1);
    final hairColor = br.readInt(1);
    final featureMask = br.readInt(3);
    final expression = br.readInt(2);
    final poseAngle = br.readInt(3);
    final poseAngleUncertainty = br.readInt(3);
    br.skip(nrFeaturePoints * 8);
    final faceImageType = br.readInt(1);
    final imageDataType = br.readInt(1);
    final imageType = imageDataType == 0 ? ImageType.jpeg : ImageType.jpeg2000;
    final imageWidth = br.readInt(2);
    final imageHeight = br.readInt(2);
    final imageColorSpace = br.readInt(1);
    final sourceType = br.readInt(1);
    final deviceType = br.readInt(2);
    final quality = br.readInt(2);
    final imageData = br.readRemaining();
    _dg2 = PassportEfDG2(
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
    return _dg2;
  }

  @override
  void parseDG3(Uint8List bytes) => _dg3RawBytes = bytes;
  @override
  void parseDG4(Uint8List bytes) => _dg4RawBytes = bytes;
  @override
  void parseDG5(Uint8List bytes) => _dg5RawBytes = bytes;
  @override
  void parseDG6(Uint8List bytes) => _dg6RawBytes = bytes;
  @override
  void parseDG7(Uint8List bytes) => _dg7RawBytes = bytes;
  @override
  void parseDG8(Uint8List bytes) => _dg8RawBytes = bytes;
  @override
  void parseDG9(Uint8List bytes) => _dg9RawBytes = bytes;
  @override
  void parseDG10(Uint8List bytes) => _dg10RawBytes = bytes;

  @override
  void parseDG11(Uint8List bytes) {
    final tlv = TLV.fromBytes(bytes);
    if (tlv.tag != PassportEfDG11.TAG.value) {
      throw EfParseError("Invalid DG11 tag=${tlv.tag.hex()}, expected tag=${PassportEfDG11.TAG.value.hex()}");
    }
    final data = tlv.value;
    final tagListTag = TLV.decode(data);
    if (tagListTag.tag.value != TAG_LIST_TAG) {
      throw EfParseError(
        "Invalid version object tag=${tagListTag.tag.value.hex()}, expected tag=${TAG_LIST_TAG.hex()}",
      );
    }
    var tagListLength = tlv.value.length;
    int tagListBytesRead = tagListTag.encodedLen;
    String? nameOfHolder;
    List<String> otherNames = [];
    String? personalNumber;
    DateTime? fullDateOfBirth;
    List<String> placeOfBirth = [];
    List<String> permanentAddress = [];
    String? telephone;
    String? profession;
    String? title;
    String? personalSummary;
    Uint8List? proofOfCitizenship;
    List<String> otherValidTDNumbers = [];
    String? custodyInformation;
    while (tagListBytesRead < tagListLength) {
      final uvtv = TLV.decode(data.sublist(tagListBytesRead));
      tagListBytesRead += uvtv.encodedLen;
      switch (uvtv.tag.value) {
        case FULL_NAME_TAG:
          nameOfHolder = utf8.decode(uvtv.value);
          break;
        case PERSONAL_NUMBER_TAG:
          personalNumber = utf8.decode(uvtv.value);
          break;
        case OTHER_NAME_TAG:
          otherNames.add(utf8.decode(uvtv.value));
          break;
        case FULL_DATE_OF_BIRTH_TAG:
          // Some countries store the full birth date in binary coded format
          // even though that's not according to the spec
          fullDateOfBirth = uvtv.value.length == 4
              ? uvtv.value.binaryDecodeCCYYMMDD()
              : String.fromCharCodes(uvtv.value).parseDate();
          break;
        case PLACE_OF_BIRTH_TAG:
          placeOfBirth.add(utf8.decode(uvtv.value));
          break;
        case PERMANENT_ADDRESS_TAG:
          permanentAddress.add(utf8.decode(uvtv.value));
          break;
        case TELEPHONE_TAG:
          telephone = utf8.decode(uvtv.value);
          break;
        case PROFESSION_TAG:
          profession = utf8.decode(uvtv.value);
          break;
        case TITLE_TAG:
          title = utf8.decode(uvtv.value);
          break;
        case PERSONAL_SUMMARY_TAG:
          personalSummary = utf8.decode(uvtv.value);
          break;
        case PROOF_OF_CITIZENSHIP_TAG:
          proofOfCitizenship = uvtv.value;
          break;
        case OTHER_VALID_TD_NUMBERS_TAG:
          otherValidTDNumbers.add(utf8.decode(uvtv.value));
          break;
        case CUSTODY_INFORMATION_TAG:
          custodyInformation = utf8.decode(uvtv.value);
          break;
      }
    }
    _dg11 = PassportEfDG11(
      nameOfHolder: nameOfHolder,
      otherNames: otherNames,
      personalNumber: personalNumber,
      fullDateOfBirth: fullDateOfBirth,
      placeOfBirth: placeOfBirth,
      permanentAddress: permanentAddress,
      telephone: telephone,
      profession: profession,
      title: title,
      personalSummary: personalSummary,
      proofOfCitizenship: proofOfCitizenship,
      otherValidTDNumbers: otherValidTDNumbers,
      custodyInformation: custodyInformation,
    );
  }

  @override
  void parseDG12(Uint8List bytes) {
    final tlv = TLV.fromBytes(bytes);
    if (tlv.tag != PassportEfDG12.TAG.value) {
      throw EfParseError("Invalid DG12 tag=${tlv.tag.hex()}, expected tag=${PassportEfDG12.TAG.value.hex()}");
    }
    final data = tlv.value;
    final tagListTag = TLV.decode(data);
    if (tagListTag.tag.value != TAG_LIST_TAG) {
      throw EfParseError(
        "Invalid version object tag=${tagListTag.tag.value.hex()}, expected tag=${TAG_LIST_TAG.hex()}",
      );
    }
    var tagListLength = tlv.value.length;
    int tagListBytesRead = tagListTag.encodedLen;
    String? issuingAuthority;
    DateTime? dateOfIssue;
    while (tagListBytesRead < tagListLength) {
      final uvtv = TLV.decode(data.sublist(tagListBytesRead));
      tagListBytesRead += uvtv.encodedLen;
      switch (uvtv.tag.value) {
        case ISSUING_AUTHORITY_TAG:
          issuingAuthority = utf8.decode(uvtv.value);
          break;
        case DATE_OF_ISSUE_TAG:
          dateOfIssue = String.fromCharCodes(uvtv.value).parseDate();
          break;
      }
    }
    _dg12 = PassportEfDG12(issuingAuthority: issuingAuthority, dateOfIssue: dateOfIssue);
  }

  @override
  void parseDG13(Uint8List bytes) => _dg13RawBytes = bytes;
  @override
  void parseDG14(Uint8List bytes) => _dg14RawBytes = bytes;

  @override
  void parseDG15(Uint8List bytes) {
    final tlv = TLV.fromBytes(bytes);
    if (tlv.tag != PassportEfDG15.TAG.value) {
      throw EfParseError("Invalid DG15 tag=${tlv.tag.hex()}, expected tag=${PassportEfDG15.TAG.value.hex()}");
    }
    try {
      final pubkey = AAPublicKey.fromBytes(tlv.value);
      _dg15 = PassportEfDG15(pubkey);
    } on Exception catch (e) {
      throw EfParseError("Failed to parse AAPublicKey from EF.DG15: $e");
    }
  }

  @override
  void parseDG16(Uint8List bytes) => _dg16RawBytes = bytes;
}
