import 'dart:typed_data';

import 'package:vcmrtd/extensions.dart';

import '../lds/ef.dart';
import '../lds/mrz.dart';
import '../lds/tlv.dart';
import '../types/data.dart';
import 'package:logging/logging.dart';


const _dg2BiometricInformationGroupTemplateTag = 0x7F61;
const _dg2BiometricInformationTemplateTag = 0x7F60;
const _dg2BiometricHeaderTemplateBaseTag = 0xA1;
const _dg2BiometricDataBlockTag = 0x5F2E;
const _dg2BiometricDataBlockConstructedTag = 0x7F2E;
const _dg2BiometricInformationCountTag = 0x02;
const _dg2SmtTag = 0x7D;
const _dg2VersionNumber = 0x30313000;

class Dg1ParseResult {
  const Dg1ParseResult({
    this.passportMrz,
    this.driverLicenceNumber,
    this.driverLicenceCountry,
    this.driverLicenceGeneration,
  });

  final MRZ? passportMrz;
  final String? driverLicenceNumber;
  final String? driverLicenceCountry;
  final int? driverLicenceGeneration;
}

class Dg1Parser {
  const Dg1Parser._();

  static final _log = Logger('Dg1Parser');

  static Dg1ParseResult parse(DocumentType documentType, Uint8List mrzData) {
    _log.fine('Parsing MRZ data for document type: $documentType, data length: ${mrzData.length}, data: ${mrzData.toString()}');
    
    switch (documentType) {
      case DocumentType.passport:
        return Dg1ParseResult(passportMrz: MRZ(mrzData));
      case DocumentType.driverLicence:
        final mrz = _DriverLicenceParser().parse(mrzData);
        return Dg1ParseResult(
          driverLicenceNumber: mrz.licenseNumber,
          driverLicenceCountry: mrz.country,
          driverLicenceGeneration: mrz.generation,
        );
    }
  }
}

class _DriverLicenceParser {
  DriverLicenceMrz parse(Uint8List mrzData) {
    if (mrzData.isEmpty) {
      throw FormatException('MRZ payload is empty');
    }

    final mrzString = String.fromCharCodes(mrzData);
    if (mrzString.length < 17) {
      throw FormatException('MRZ payload too short for driving licence data');
    }

    final country = mrzString.substring(2, 5);
    final generationChar = mrzString[5];
    final generation = int.tryParse(generationChar);
    if (generation == null) {
      throw FormatException('Invalid generation digit in driving licence MRZ');
    }

    final licenseNumber = mrzString.substring(6, 17).trim();

    return DriverLicenceMrz(
      country: country,
      generation: generation,
      licenseNumber: licenseNumber,
    );
  }
}

class DriverLicenceMrz {
  const DriverLicenceMrz({
    required this.country,
    required this.generation,
    required this.licenseNumber,
  });

  final String country;
  final int generation;
  final String licenseNumber;
}

class Dg2ParseResult {
  const Dg2ParseResult({
    this.passportData,
    this.driverLicencePortrait,
    this.driverLicenceImageTypeCode,
  });

  final PassportDg2Data? passportData;
  final Uint8List? driverLicencePortrait;
  final int? driverLicenceImageTypeCode;
}

class PassportDg2Data {
  const PassportDg2Data({
    required this.versionNumber,
    required this.lengthOfRecord,
    required this.numberOfFacialImages,
    required this.facialRecordDataLength,
    required this.nrFeaturePoints,
    required this.gender,
    required this.eyeColor,
    required this.hairColor,
    required this.featureMask,
    required this.expression,
    required this.poseAngle,
    required this.poseAngleUncertainty,
    required this.faceImageType,
    required this.imageWidth,
    required this.imageHeight,
    required this.imageColorSpace,
    required this.sourceType,
    required this.deviceType,
    required this.quality,
    required this.imageDataType,
    required this.imageData,
  });

  final int versionNumber;
  final int lengthOfRecord;
  final int numberOfFacialImages;
  final int facialRecordDataLength;
  final int nrFeaturePoints;
  final int gender;
  final int eyeColor;
  final int hairColor;
  final int featureMask;
  final int expression;
  final int poseAngle;
  final int poseAngleUncertainty;
  final int faceImageType;
  final int imageWidth;
  final int imageHeight;
  final int imageColorSpace;
  final int sourceType;
  final int deviceType;
  final int quality;
  final int? imageDataType;
  final Uint8List? imageData;
}

class Dg2Parser {
  const Dg2Parser._();

  static Dg2ParseResult parse(DocumentType documentType, Uint8List content) {
    final passportData = _PassportDg2Parser().parse(content);

    switch (documentType) {
      case DocumentType.passport:
        return Dg2ParseResult(passportData: passportData);
      case DocumentType.driverLicence:
        return Dg2ParseResult(
          passportData: passportData,
          driverLicencePortrait: passportData.imageData,
          driverLicenceImageTypeCode: passportData.imageDataType,
        );
    }
  }
}

class _PassportDg2Parser {
  PassportDg2Data parse(Uint8List content) {
    final bigt = TLV.decode(content);
    if (bigt.tag.value != _dg2BiometricInformationGroupTemplateTag) {
      throw EfParseError(
        "Invalid object tag=${bigt.tag.value.hex()}, expected tag=${_dg2BiometricInformationGroupTemplateTag.hex()}",
      );
    }

    final bict = TLV.decode(bigt.value);
    if (bict.tag.value != _dg2BiometricInformationCountTag) {
      throw EfParseError(
        "Invalid object tag=${bict.tag.value.hex()}, expected tag=${_dg2BiometricInformationCountTag.hex()}",
      );
    }

    // Currently only one Biometric Information Template is expected.
    final bitStream = bigt.value.sublist(bict.encodedLen);
    final tvl = TLV.decode(bitStream);
    if (tvl.tag.value != _dg2BiometricInformationTemplateTag) {
      throw EfParseError(
        "Invalid object tag=${tvl.tag.value.hex()}, expected tag=${_dg2BiometricInformationTemplateTag.hex()}",
      );
    }

    final bhtTag = TLV.decode(tvl.value);
    if (bhtTag.tag.value == _dg2SmtTag) {
      throw EfParseError('Secure messaging protected BITs are not supported');
    }

    if ((bhtTag.tag.value & 0xA0) != 0xA0) {
      throw EfParseError('Unsupported Biometric Header Template encoding');
    }

    final sbh = _readBht(tvl.value);
    return _readBiometricDataBlock(sbh);
  }

  List<DecodedTV> _readBht(Uint8List stream) {
    final bht = TLV.decode(stream);
    if (bht.tag.value != _dg2BiometricHeaderTemplateBaseTag) {
      throw EfParseError(
        "Invalid object tag=${bht.tag.value.hex()}, expected tag=${_dg2BiometricHeaderTemplateBaseTag.hex()}",
      );
    }

    final elements = <DecodedTV>[];
    var bytesRead = bht.encodedLen;
    while (bytesRead < stream.length) {
      final tlv = TLV.decode(stream.sublist(bytesRead));
      bytesRead += tlv.encodedLen;
      elements.add(tlv);
    }

    return elements;
  }

  PassportDg2Data _readBiometricDataBlock(List<DecodedTV> sbh) {
    final firstBlock = sbh.first;
    final tag = firstBlock.tag.value;
    final isDataBlock = tag == _dg2BiometricDataBlockTag ||
        tag == _dg2BiometricDataBlockConstructedTag;
    if (!isDataBlock) {
      throw EfParseError(
        "Invalid object tag=${tag.hex()}, expected tag=${_dg2BiometricDataBlockTag.hex()} or ${_dg2BiometricDataBlockConstructedTag.hex()}",
      );
    }

    final data = firstBlock.value;
    if (data.length < 4 ||
        data[0] != 0x46 ||
        data[1] != 0x41 ||
        data[2] != 0x43 ||
        data[3] != 0x00) {
      throw EfParseError('Biometric data block is invalid');
    }

    var offset = 4;

    final versionNumber = _extractContent(data, start: offset, end: offset + 4);
    if (versionNumber != _dg2VersionNumber) {
      throw EfParseError('Version of Biometric data is not valid');
    }
    offset += 4;

    final lengthOfRecord =
        _extractContent(data, start: offset, end: offset + 4);
    offset += 4;

    final numberOfFacialImages =
        _extractContent(data, start: offset, end: offset + 2);
    offset += 2;

    final facialRecordDataLength =
        _extractContent(data, start: offset, end: offset + 4);
    offset += 4;

    final nrFeaturePoints =
        _extractContent(data, start: offset, end: offset + 2);
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

    final poseAngleUncertainty =
        _extractContent(data, start: offset, end: offset + 3);
    offset += 3;

    // Skip feature point data if present (each feature takes 8 bytes).
    offset += nrFeaturePoints * 8;

    final faceImageType = _extractContent(data, start: offset, end: offset + 1);
    offset += 1;

    final imageDataType = _extractContent(data, start: offset, end: offset + 1);
    offset += 1;

    final imageWidth = _extractContent(data, start: offset, end: offset + 2);
    offset += 2;

    final imageHeight = _extractContent(data, start: offset, end: offset + 2);
    offset += 2;

    final imageColorSpace =
        _extractContent(data, start: offset, end: offset + 1);
    offset += 1;

    final sourceType = _extractContent(data, start: offset, end: offset + 1);
    offset += 1;

    final deviceType = _extractContent(data, start: offset, end: offset + 2);
    offset += 2;

    final quality = _extractContent(data, start: offset, end: offset + 2);
    offset += 2;

    final imageData = firstBlock.value.sublist(offset);

    return PassportDg2Data(
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
      imageDataType: imageDataType,
      imageData: imageData.isEmpty ? null : imageData,
    );
  }

  int _extractContent(Uint8List data, {required int start, required int end}) {
    final length = end - start;
    final view = data.sublist(start, end).buffer.asByteData();
    if (length == 1) {
      return view.getInt8(0);
    }
    if (length < 4) {
      return view.getInt16(0);
    }
    return view.getInt32(0);
  }
}
