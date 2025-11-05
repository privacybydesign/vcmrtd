import 'dart:typed_data';

import '../../../vcmrtd.dart';

class DrivingLicenceEfDG1 {
  // Personal data
  static const FID = 0x0101;
  static const SFI = 0x01;
  static const TAG = DgTag(0x6E);

  final String? issuingMemberState;
  final String? holderSurname;
  final String? holderOtherName;
  final String? dateOfBirth;
  final String? placeOfBirth;
  final String? dateOfIssue;
  final String? dateOfExpiry;
  final String? issuingAuthority;
  final String? documentNumber;

  DrivingLicenceEfDG1({
    this.issuingMemberState,
    this.holderSurname,
    this.holderOtherName,
    this.dateOfBirth,
    this.placeOfBirth,
    this.dateOfIssue,
    this.dateOfExpiry,
    this.issuingAuthority,
    this.documentNumber,
  });
}

class DrivingLicenceEfDG2 {
  // Driving license specific data (categories, restrictions, etc.)
  static const FID = 0x0102;
  static const SFI = 0x02;
  static const TAG = DgTag(0x6F);
}

class DrivingLicenceEfDG3 {
  // Additional personal data
  static const FID = 0x0103;
  static const SFI = 0x03;
  static const TAG = DgTag(0x63);
}

class DrivingLicenceEfDG4 {
  // Additional document data
  static const FID = 0x0104;
  static const SFI = 0x04;
  static const TAG = DgTag(0x76);
}

class DrivingLicenceEfDG5 {
  // Portrait image
  static const FID = 0x0105;
  static const SFI = 0x05;
  static const TAG = DgTag(0x65);
}

class DrivingLicenceEfDG6 {
  // Signature or usual mark image
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
  final Uint8List? imageData;
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
    this.imageData,
    this.imageType,
  });
}

class DrivingLicenceEfDG7 {
  // Fingerprint image
  static const FID = 0x0107;
  static const SFI = 0x07;
  static const TAG = DgTag(0x67);
}

class DrivingLicenceEfDG8 {
  // Iris image
  static const FID = 0x0108;
  static const SFI = 0x08;
  static const TAG = DgTag(0x68);
}

class DrivingLicenceEfDG9 {
  // Additional biometric data
  static const FID = 0x0109;
  static const SFI = 0x09;
  static const TAG = DgTag(0x69);
}

class DrivingLicenceEfDG10 {
  // Notations
  static const FID = 0x010A;
  static const SFI = 0x0A;
  static const TAG = DgTag(0x6A);
}

class DrivingLicenceEfDG11 {
  // Optional data
  static const FID = 0x010B;
  static const SFI = 0x0B;
  static const TAG = DgTag(0x6B);
}

class DrivingLicenceEfDG12 {
  // Reserved for future use
  static const FID = 0x010C;
  static const SFI = 0x0C;
  static const TAG = DgTag(0x6C);
}

class DrivingLicenceEfDG13 {
  // Reserved for future use
  static const FID = 0x010D;
  static const SFI = 0x0D;
  static const TAG = DgTag(0x6D);
}

class DrivingLicenceEfDG14 {
  // Reserved for future use / Security options
  static const FID = 0x010E;
  static const SFI = 0x0E;
  static const TAG = DgTag(0x77);
}
