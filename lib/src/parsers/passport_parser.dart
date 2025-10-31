import 'dart:convert';
import 'dart:typed_data';

import 'package:vcmrtd/extensions.dart';

import '../../vcmrtd.dart';
import '../lds/df1/passportDGs.dart';
import '../models/document.dart';
import 'document_parser.dart';

class PassportParser implements DocumentParser<PassportData> {

  // Groups with parsing logic
  PassportEfDG1? _dg1;
  PassportEfDG2? _dg2;
  PassportEfDG11? _dg11;
  PassportEfDG12? _dg12;
  PassportEfDG15? _dg15;

  // Raw bytes
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
  PassportData createDocument() {
    return PassportData(
      // DG1 - required
      mrz: _dg1!.mrz,

      // DG2 - photo (extract key fields)
      photoImageData: _dg2?.imageData,
      photoImageType: _dg2?.imageType,
      photoImageWidth: _dg2?.imageWidth,
      photoImageHeight: _dg2?.imageHeight,

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
  void parseDG1(Uint8List bytes) {
    final tlv = TLV.fromBytes(bytes);

    // Check for outer DG1 tag (0x61), not MRZ tag
    if (tlv.tag != PassportEfDG1.TAG.value) {  // Changed from 0x5F1F to PassportEfDG1.TAG.value
      throw EfParseError(
          "Invalid DG1 tag=${tlv.tag.hex()}, expected tag=${PassportEfDG1.TAG.value.hex()}"
      );
    }

    // Now extract the inner MRZ tag (0x5F1F) from the value
    final mrzTlv = TLV.fromBytes(tlv.value);
    if (mrzTlv.tag != 0x5F1F) {
      throw EfParseError(
          "Invalid MRZ tag=${mrzTlv.tag.hex()}, expected tag=5F1F"
      );
    }

    final mrz = PassportMRZ(mrzTlv.value);
    _dg1 = PassportEfDG1(mrz);
  }

  @override
  void parseDG2(Uint8List bytes) {
    final tlv = TLV.fromBytes(bytes);
    if (tlv.tag != PassportEfDG2.TAG.value) {
      throw EfParseError("Invalid DG2 tag=${tlv.tag.hex()}, expected tag=${PassportEfDG2.TAG.value.hex()}");
    }

    final data = tlv.value;
    final bigt = TLV.decode(data);

    if (bigt.tag.value != 0x7F61) {  // BIOMETRIC_INFORMATION_GROUP_TEMPLATE_TAG
      throw EfParseError("Invalid object tag=${bigt.tag.value.hex()}, expected tag=7F61");
    }

    final bict = TLV.decode(bigt.value);

    if (bict.tag.value != 0x02) {  // BIOMETRIC_INFORMATION_COUNT_TAG
      throw EfParseError("Invalid object tag=${bict.tag.value.hex()}, expected tag=02");
    }

    int bitCount = (bict.value[0] & 0xFF);

    for (var i = 0; i < bitCount; i++) {
      _parseBIT(bigt.value.sublist(bict.encodedLen), i);
    }
  }

  void _parseBIT(Uint8List stream, int index) {
    final tvl = TLV.decode(stream);

    if (tvl.tag.value != 0x7F60) {  // BIOMETRIC_INFORMATION_TEMPLATE_TAG
      throw EfParseError("Invalid object tag=${tvl.tag.value.hex()}, expected tag=7F60");
    }

    var bht = TLV.decode(tvl.value);

    if (bht.tag.value == 0x7D) {  // SMT_TAG
      // TODO: Statically protected BIT not implemented
    } else if ((bht.tag.value & 0xA0) == 0xA0) {
      var sbh = _parseBHT(tvl.value);
      _parseBiometricDataBlock(sbh);
    }
  }

  List<DecodedTV> _parseBHT(Uint8List stream) {
    final bht = TLV.decode(stream);

    if (bht.tag.value != 0xA1) {  // BIOMETRIC_HEADER_TEMPLATE_BASE_TAG
      throw EfParseError("Invalid object tag=${bht.tag.value.hex()}, expected tag=A1");
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

  void _parseBiometricDataBlock(List<DecodedTV> sbh) {
    var firstBlock = sbh.first;
    if (firstBlock.tag.value != 0x5F2E && firstBlock.tag.value != 0x7F2E) {
      throw EfParseError(
          "Invalid object tag=${firstBlock.tag.value.hex()}, expected tag=5F2E or 7F2E"
      );
    }

    var data = firstBlock.value;
    if (data[0] != 0x46 || data[1] != 0x41 || data[2] != 0x43 || data[3] != 0x00) {
      throw EfParseError("Biometric data block is invalid");
    }

    var offset = 4;

    // Extract all the fields
    final versionNumber = _extractContent(data, start: offset, end: offset + 4);
    offset += 4;

    if (versionNumber != 0x30313000) {  // VERSION_NUMBER
      throw EfParseError("Version of Biometric data is not valid");
    }

    final lengthOfRecord = _extractContent(data, start: offset, end: offset + 4);
    offset += 4;

    final numberOfFacialImages = _extractContent(data, start: offset, end: offset + 2);
    offset += 2;

    final facialRecordDataLength = _extractContent(data, start: offset, end: offset + 4);
    offset += 4;

    final nrFeaturePoints = _extractContent(data, start: offset, end: offset + 2);
    offset += 2;

    final gender = _extractContent(data, start: offset, end: offset + 1);
    offset += 1;

    final eyeColor = _extractContent(data, start: offset, end: offset + 1);
    offset += 1;

    final hairColor = _extractContent(data, start: offset, end: offset + 1);
    offset += 1;

    final featureMask = _extractContent(data, start: offset, end: offset + 3);
    offset += 3;

    final expression = _extractContent(data, start: offset, end: offset + 2);
    offset += 2;

    final poseAngle = _extractContent(data, start: offset, end: offset + 3);
    offset += 3;

    final poseAngleUncertainty = _extractContent(data, start: offset, end: offset + 3);
    offset += 3;

    offset += nrFeaturePoints * 8;  // Skip features

    final faceImageType = _extractContent(data, start: offset, end: offset + 1);
    offset += 1;

    final imageDataType = _extractContent(data, start: offset, end: offset + 1);
    offset += 1;

    final imageWidth = _extractContent(data, start: offset, end: offset + 2);
    offset += 2;

    final imageHeight = _extractContent(data, start: offset, end: offset + 2);
    offset += 2;

    final imageColorSpace = _extractContent(data, start: offset, end: offset + 1);
    offset += 1;

    final sourceType = _extractContent(data, start: offset, end: offset + 1);
    offset += 1;

    final deviceType = _extractContent(data, start: offset, end: offset + 2);
    offset += 2;

    final quality = _extractContent(data, start: offset, end: offset + 2);
    offset += 2;

    final imageData = sbh.first.value.sublist(offset);

    final imageType = imageDataType == 0 ? ImageType.jpeg : ImageType.jpeg2000;

    // PassportEfDG2 object
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
  }

  int _extractContent(Uint8List data, {required int start, required int end}) {
    if (end - start == 1) {
      return data.sublist(start, end).buffer.asByteData().getInt8(0);
    } else if (end - start < 4) {
      return data.sublist(start, end).buffer.asByteData().getInt16(0);
    }
    return data.sublist(start, end).buffer.asByteData().getInt32(0);
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
    _dg6RawBytes = bytes;
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
    final tlv = TLV.fromBytes(bytes);
    if (tlv.tag != PassportEfDG11.TAG.value) {
      throw EfParseError("Invalid DG11 tag=${tlv.tag.hex()}, expected tag=${PassportEfDG11.TAG.value.hex()}");
    }

    final data = tlv.value;
    final tagListTag = TLV.decode(data);

    if (tagListTag.tag.value != 0x5c) {  // TAG_LIST_TAG
      throw EfParseError("Invalid version object tag=${tagListTag.tag.value.hex()}, expected tag=5c");
    }

    var tagListLength = tlv.value.length;
    int tagListBytesRead = tagListTag.encodedLen;

    // Temporary storage for building the object
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
        case 0x5F0E:  // FULL_NAME_TAG
          nameOfHolder = utf8.decode(uvtv.value);
          break;
        case 0x5F10:  // PERSONAL_NUMBER_TAG
          personalNumber = utf8.decode(uvtv.value);
          break;
        case 0x5F0F:  // OTHER_NAME_TAG
          otherNames.add(utf8.decode(uvtv.value));
          break;
        case 0x5F2B:  // FULL_DATE_OF_BIRTH_TAG
          fullDateOfBirth = String.fromCharCodes(uvtv.value).parseDate();
          break;
        case 0x5F11:  // PLACE_OF_BIRTH_TAG
          placeOfBirth.add(utf8.decode(uvtv.value));
          break;
        case 0x5F42:  // PERMANENT_ADDRESS_TAG
          permanentAddress.add(utf8.decode(uvtv.value));
          break;
        case 0x5F12:  // TELEPHONE_TAG
          telephone = utf8.decode(uvtv.value);
          break;
        case 0x5F13:  // PROFESSION_TAG
          profession = utf8.decode(uvtv.value);
          break;
        case 0x5F14:  // TITLE_TAG
          title = utf8.decode(uvtv.value);
          break;
        case 0x5F15:  // PERSONAL_SUMMARY_TAG
          personalSummary = utf8.decode(uvtv.value);
          break;
        case 0x5F16:  // PROOF_OF_CITIZENSHIP_TAG
          proofOfCitizenship = uvtv.value;
          break;
        case 0x5F17:  // OTHER_VALID_TD_NUMBERS_TAG
          otherValidTDNumbers.add(utf8.decode(uvtv.value));
          break;
        case 0x5F18:  // CUSTODY_INFORMATION_TAG
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

    if (tagListTag.tag.value != 0x5c) {  // TAG_LIST_TAG
      throw EfParseError("Invalid version object tag=${tagListTag.tag.value.hex()}, expected tag=5c");
    }

    var tagListLength = tlv.value.length;
    int tagListBytesRead = tagListTag.encodedLen;

    String? issuingAuthority;
    DateTime? dateOfIssue;

    while (tagListBytesRead < tagListLength) {
      final uvtv = TLV.decode(data.sublist(tagListBytesRead));
      tagListBytesRead += uvtv.encodedLen;

      switch (uvtv.tag.value) {
        case 0x5F19:  // ISSUING_AUTHORITY_TAG
          issuingAuthority = utf8.decode(uvtv.value);
          break;
        case 0x5F26:  // DATE_OF_ISSUE_TAG
          dateOfIssue = String.fromCharCodes(uvtv.value).parseDate();
          break;
      }
    }

    _dg12 = PassportEfDG12(
      issuingAuthority: issuingAuthority,
      dateOfIssue: dateOfIssue,
    );
  }

  @override
  void parseDG13(Uint8List bytes) {
    _dg13RawBytes = bytes;
  }

  @override
  void parseDG14(Uint8List bytes) {
    _dg14RawBytes = bytes;
  }

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
  void parseDG16(Uint8List bytes) {
    _dg16RawBytes = bytes;
  }

}