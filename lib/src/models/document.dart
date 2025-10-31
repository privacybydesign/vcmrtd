import 'dart:typed_data';

import 'package:vcmrtd/src/lds/mrz.dart';

import '../../vcmrtd.dart';

abstract class DocumentData {}


class PassportData implements DocumentData {
  // From DG1
  final PassportMRZ? mrz;

  // From DG2 (photo)
  final Uint8List? photoImageData;
  final ImageType? photoImageType;
  final int? photoImageWidth;
  final int? photoImageHeight;

  // From DG11 (additional personal details)
  final String? nameOfHolder;
  final List<String>? otherNames;
  final String? personalNumber;
  final DateTime? fullDateOfBirth;
  final List<String>? placeOfBirth;
  final List<String>? permanentAddress;
  final String? telephone;
  final String? profession;
  final String? title;
  final String? personalSummary;
  final Uint8List? proofOfCitizenship;
  final List<String>? otherValidTDNumbers;
  final String? custodyInformation;

  // From DG12 (document details)
  final DateTime? dateOfIssue;
  final String? issuingAuthority;

  // From DG15 (active auth)
  final AAPublicKey? aaPublicKey;

  // Raw bytes for unparsed DGs
  final Uint8List? dg3RawBytes;
  final Uint8List? dg4RawBytes;
  final Uint8List? dg5RawBytes;
  final Uint8List? dg6RawBytes;
  final Uint8List? dg7RawBytes;
  final Uint8List? dg8RawBytes;
  final Uint8List? dg9RawBytes;
  final Uint8List? dg10RawBytes;
  final Uint8List? dg13RawBytes;
  final Uint8List? dg14RawBytes;
  final Uint8List? dg16RawBytes;

  PassportData({
    required this.mrz,
    this.photoImageData,
    this.photoImageType,
    this.photoImageWidth,
    this.photoImageHeight,
    this.nameOfHolder,
    this.otherNames,
    this.personalNumber,
    this.fullDateOfBirth,
    this.placeOfBirth,
    this.permanentAddress,
    this.telephone,
    this.profession,
    this.title,
    this.personalSummary,
    this.proofOfCitizenship,
    this.otherValidTDNumbers,
    this.custodyInformation,
    this.dateOfIssue,
    this.issuingAuthority,
    this.aaPublicKey,
    this.dg3RawBytes,
    this.dg4RawBytes,
    this.dg5RawBytes,
    this.dg6RawBytes,
    this.dg7RawBytes,
    this.dg8RawBytes,
    this.dg9RawBytes,
    this.dg10RawBytes,
    this.dg13RawBytes,
    this.dg14RawBytes,
    this.dg16RawBytes,
  });
}

class DrivingLicenceData implements DocumentData {
  // From DG1
  final String? issuingMemberState;
  final String? holderSurname;
  final String? holderOtherName;
  final String? dateOfBirth;
  final String? placeOfBirth;
  final String? dateOfIssue;
  final String? dateOfExpiry;
  final String? issuingAuthority;
  final String? documentNumber;

  // From DG6 (photo)
  final Uint8List? photoImageData;
  final ImageType? photoImageType;
  final int? patronHeaderVersion;
  final int? biometricType;
  final int? numberOfInstances;

  // Raw bytes for unparsed DGs
  final Uint8List? dg2RawBytes;
  final Uint8List? dg3RawBytes;
  final Uint8List? dg4RawBytes;
  final Uint8List? dg5RawBytes;
  final Uint8List? dg7RawBytes;
  final Uint8List? dg8RawBytes;
  final Uint8List? dg9RawBytes;
  final Uint8List? dg10RawBytes;
  final Uint8List? dg11RawBytes;
  final Uint8List? dg12RawBytes;
  final Uint8List? dg13RawBytes;
  final Uint8List? dg14RawBytes;

  DrivingLicenceData({
    this.issuingMemberState,
    this.holderSurname,
    this.holderOtherName,
    this.dateOfBirth,
    this.placeOfBirth,
    this.dateOfIssue,
    this.dateOfExpiry,
    this.issuingAuthority,
    this.documentNumber,
    this.photoImageData,
    this.photoImageType,
    this.patronHeaderVersion,
    this.biometricType,
    this.numberOfInstances,
    this.dg2RawBytes,
    this.dg3RawBytes,
    this.dg4RawBytes,
    this.dg5RawBytes,
    this.dg7RawBytes,
    this.dg8RawBytes,
    this.dg9RawBytes,
    this.dg10RawBytes,
    this.dg11RawBytes,
    this.dg12RawBytes,
    this.dg13RawBytes,
    this.dg14RawBytes,
  });
}