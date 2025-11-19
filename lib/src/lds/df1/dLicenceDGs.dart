import 'dart:typed_data';

import '../../../vcmrtd.dart';

class DrivingLicenceEfDG1 {
  // Personal data
  static const FID = 0x0101;
  static const SFI = 0x01;
  static const TAG = DgTag(0x61);

  final String issuingMemberState;
  final String holderSurname;
  final String holderOtherName;
  final String dateOfBirth;
  final String placeOfBirth;
  final String dateOfIssue;
  final String dateOfExpiry;
  final String issuingAuthority;
  final String documentNumber;

  DrivingLicenceEfDG1({
    required this.issuingMemberState,
    required this.holderSurname,
    required this.holderOtherName,
    required this.dateOfBirth,
    required this.placeOfBirth,
    required this.dateOfIssue,
    required this.dateOfExpiry,
    required this.issuingAuthority,
    required this.documentNumber,
  });
}

class DrivingLicenceEfDG2 {
  static const FID = 0x0102;
  static const SFI = 0x02;
}

class DrivingLicenceEfDG3 {
  static const FID = 0x0103;
  static const SFI = 0x03;
}

class DrivingLicenceEfDG4 {
  static const FID = 0x0104;
  static const SFI = 0x04;
}

// Mandatory
class DrivingLicenceEfDG5 {
  // Signature or usual mark image
  static const FID = 0x0105;
  static const SFI = 0x05;
  static const TAG = DgTag(0x67);

  final ImageType? imageType;
  final Uint8List? imageData;

  DrivingLicenceEfDG5({required this.imageType, required this.imageData});
}

// Mandatory
class DrivingLicenceEfDG6 {
  // Portrait image
  static const FID = 0x0106;
  static const SFI = 0x06;
  static const TAG = DgTag(0x75);

  final int? versionNumber;
  final int? lengthOfRecord;
  final int? numberOfFacialImages;
  final int? facialRecordDataLength;
  final int? nrFeaturePoints;
  final int? gender;
  final int? eyeColor;
  final int? hairColor;
  final int? featureMask;
  final int? expression;
  final int? poseAngle;
  final int? poseAngleUncertainty;
  final int? faceImageType;
  final int? imageWidth;
  final int? imageHeight;
  final int? imageColorSpace;
  final int? sourceType;
  final int? deviceType;
  final int? quality;
  final Uint8List imageData;
  final ImageType? imageType;

  DrivingLicenceEfDG6({
    this.versionNumber,
    this.lengthOfRecord,
    this.numberOfFacialImages,
    this.facialRecordDataLength,
    this.nrFeaturePoints,
    this.gender,
    this.eyeColor,
    this.hairColor,
    this.featureMask,
    this.expression,
    this.poseAngle,
    this.poseAngleUncertainty,
    this.faceImageType,
    this.imageWidth,
    this.imageHeight,
    this.imageColorSpace,
    this.sourceType,
    this.deviceType,
    this.quality,
    required this.imageData,
    required this.imageType,
  });
}

class DrivingLicenceEfDG7 {
  static const FID = 0x0107;
  static const SFI = 0x07;
  static const TAG = DgTag(0x67);
}

class DrivingLicenceEfDG8 {
  static const FID = 0x0108;
  static const SFI = 0x08;
}

class DrivingLicenceEfDG9 {
  static const FID = 0x0109;
  static const SFI = 0x09;
}

class DrivingLicenceEfDG10 {
  static const FID = 0x010A;
  static const SFI = 0x0A;
}

// Mandatory
class DrivingLicenceEfDG11 {
  // Caution: contains BSN, in real world apps
  // only read if you are allowed to process this data
  static const FID = 0x010B;
  static const SFI = 0x0B;
  static const TAG = DgTag(0x6D);
}

// Mandatory
class DrivingLicenceEfDG12 {
  // Contains BAP input string (position 2-29 of the 30 char MRZ) and the MRZ
  static const FID = 0x010C;
  static const SFI = 0x0C;
  static const TAG = DgTag(0x71);

  final String bapInputString; // 28 chars from MRZ positions 2-29
  final String saiType;

  DrivingLicenceEfDG12({required this.bapInputString, required this.saiType});
}

// Mandatory
class DrivingLicenceEfDG13 {
  // Active authentication public key
  static const FID = 0x010D;
  static const SFI = 0x0D;
  static const TAG = DgTag(0x6f);

  final AAPublicKey aaPublicKey;

  DrivingLicenceEfDG13({required this.aaPublicKey});
}

class DrivingLicenceEfDG14 {
  static const FID = 0x010E;
  static const SFI = 0x0E;
}
