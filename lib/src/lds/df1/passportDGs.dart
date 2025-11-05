import 'dart:typed_data';

import '../../../vcmrtd.dart';

class PassportEfDG1 {
  // MRZ data
  static const FID = 0x0101;
  static const SFI = 0x01;
  static const TAG = DgTag(0x61);
  late final PassportMRZ mrz;
  PassportEfDG1(this.mrz);
}

class PassportEfDG2 {
  // Passport photo data
  static const FID = 0x0102;
  static const SFI = 0x02;
  static const TAG = DgTag(0x75);

  static const BIGT= 0x7F61;
  static const BICT = 0x02;
  static const BITT = 0x7F60;

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
  final Uint8List? imageData;
  final ImageType? imageType;

  PassportEfDG2({
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
    this.imageData,
    this.imageType,
  });
}

class PassportEfDG3 {
  // Fingerprint data, commonly not needed for privacy reasons
  static const FID = 0x0103;
  static const SFI = 0x03;
  static const TAG = DgTag(0x63);
}

class PassportEfDG4 {
  // Iris data
  static const FID = 0x0104;
  static const SFI = 0x04;
  static const TAG = DgTag(0x76);
}

class PassportEfDG5 {
  static const FID = 0x0105;
  static const SFI = 0x05;
  static const TAG = DgTag(0x65);
}

class PassportEfDG6 {
  static const FID = 0x0106;
  static const SFI = 0x06;
  static const TAG = DgTag(0x66);
}

class PassportEfDG7 {
  static const FID = 0x0107;
  static const SFI = 0x07;
  static const TAG = DgTag(0x67);
}

class PassportEfDG8 {
  static const FID = 0x0108;
  static const SFI = 0x08;
  static const TAG = DgTag(0x68);
}

class PassportEfDG9 {
  static const FID = 0x0109;
  static const SFI = 0x09;
  static const TAG = DgTag(0x69);
}

class PassportEfDG10 {
  static const FID = 0x010A;
  static const SFI = 0x0A;
  static const TAG = DgTag(0x6A);
}

class PassportEfDG11 {
  static const FID = 0x010B;
  static const SFI = 0x0B;
  static const TAG = DgTag(0x6B);

  final String? nameOfHolder;
  final List<String> otherNames;
  final String? personalNumber;
  final DateTime? fullDateOfBirth;
  final List<String> placeOfBirth;
  final List<String> permanentAddress;
  final String? telephone;
  final String? profession;
  final String? title;
  final String? personalSummary;
  final Uint8List? proofOfCitizenship;
  final List<String> otherValidTDNumbers;
  final String? custodyInformation;

  PassportEfDG11({
    this.nameOfHolder,
    this.otherNames = const [],
    this.personalNumber,
    this.fullDateOfBirth,
    this.placeOfBirth = const [],
    this.permanentAddress = const [],
    this.telephone,
    this.profession,
    this.title,
    this.personalSummary,
    this.proofOfCitizenship,
    this.otherValidTDNumbers = const [],
    this.custodyInformation,
  });
}

class PassportEfDG12 {
  static const FID = 0x010C;
  static const SFI = 0x0C;
  static const TAG = DgTag(0x6C);

  final DateTime? dateOfIssue;
  final String? issuingAuthority;

  PassportEfDG12({this.dateOfIssue, this.issuingAuthority});
}

class PassportEfDG13 {
  static const FID = 0x010D;
  static const SFI = 0x0D;
  static const TAG = DgTag(0x6D);
}

class PassportEfDG14 {
  static const FID = 0x010E;
  static const SFI = 0x0E;
  static const TAG = DgTag(0x6E);
}

class PassportEfDG15 {
  static const FID = 0x010F;
  static const SFI = 0x0F;
  static const TAG = DgTag(0x6F);

  final AAPublicKey aaPublicKey;

  PassportEfDG15(this.aaPublicKey);
}

class PassportEfDG16 {
  static const FID = 0x0110;
  static const SFI = 0x10;
  static const TAG = DgTag(0x70);
}
