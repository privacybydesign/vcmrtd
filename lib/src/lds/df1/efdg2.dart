// Created by Crt Vavros, copyright © 2022 ZeroPass. All rights reserved.
// ignore_for_file: constant_identifier_names

import 'dart:core';
import 'dart:typed_data';
import '../../types/data.dart';
import 'dg.dart';
import '../../parsing/parser.dart';

enum ImageType { jpeg, jpeg2000 }

class EfDG2 extends DataGroup {
  static const FID = 0x0102;
  static const SFI = 0x02;
  static const TAG = DgTag(0x75);

  static const BIOMETRIC_INFORMATION_GROUP_TEMPLATE_TAG = 0x7F61;
  static const BIOMETRIC_INFORMATION_TEMPLATE_TAG = 0x7F60;

  static const BIOMETRIC_HEADER_TEMPLATE_BASE_TAG = 0xA1;

  static const BIOMETRIC_DATA_BLOCK_TAG = 0x5F2E;
  static const BIOMETRIC_DATA_BLOCK_CONSTRUCTED_TAG = 0x7F2E;

  static const BIOMETRIC_INFORMATION_COUNT_TAG = 0x02;
  static const SMT_TAG = 0x7D;
  static const VERSION_NUMBER = 0x30313000;

  final DocumentType documentType;

  EfDG2._internal(this.documentType, Uint8List data) : super.fromBytes(data);

  factory EfDG2.fromBytes(Uint8List data,
      [DocumentType docType = DocumentType.passport]) {
    return EfDG2._internal(docType, data);
  }

  @override
  int get fid => FID;

  @override
  int get sfi => SFI;

  @override
  int get tag => TAG.value;

  late int versionNumber;
  late int lengthOfRecord;
  late int numberOfFacialImages;
  late int facialRecordDataLength;
  late int nrFeaturePoints;
  late int gender;
  late int eyeColor;
  late int hairColor;
  late int featureMask;
  late int expression;
  late int poseAngle;
  late int poseAngleUncertainty;
  late int faceImageType;
  late int imageWidth;
  late int imageHeight;
  late int imageColorSpace;
  late int sourceType;
  late int deviceType;
  late int quality;

  Uint8List? imageData;
  int? _imageDataType;

  // Driving licence-specific portrait information.
  Uint8List? _driverLicencePortraitImage;
  int? _driverLicenceImageTypeCode;

  ImageType? get imageType {
    if (_imageDataType == null) return null;

    return _imageDataType == 0 ? ImageType.jpeg : ImageType.jpeg2000;
  }

  Uint8List? get driverLicencePortraitImage => _driverLicencePortraitImage;

  ImageType? get driverLicencePortraitType {
    final type = _driverLicenceImageTypeCode;
    if (type == null) return null;
    return type == 0 ? ImageType.jpeg : ImageType.jpeg2000;
  }

  @override
  void parseContent(Uint8List content) {
    final result = Dg2Parser.parse(documentType, content);

    final passportData = result.passportData;
    if (passportData != null) {
      versionNumber = passportData.versionNumber;
      lengthOfRecord = passportData.lengthOfRecord;
      numberOfFacialImages = passportData.numberOfFacialImages;
      facialRecordDataLength = passportData.facialRecordDataLength;
      nrFeaturePoints = passportData.nrFeaturePoints;
      gender = passportData.gender;
      eyeColor = passportData.eyeColor;
      hairColor = passportData.hairColor;
      featureMask = passportData.featureMask;
      expression = passportData.expression;
      poseAngle = passportData.poseAngle;
      poseAngleUncertainty = passportData.poseAngleUncertainty;
      faceImageType = passportData.faceImageType;
      imageWidth = passportData.imageWidth;
      imageHeight = passportData.imageHeight;
      imageColorSpace = passportData.imageColorSpace;
      sourceType = passportData.sourceType;
      deviceType = passportData.deviceType;
      quality = passportData.quality;
      _imageDataType = passportData.imageDataType;
      imageData = passportData.imageData;
    }

    _driverLicencePortraitImage = result.driverLicencePortrait;
    _driverLicenceImageTypeCode = result.driverLicenceImageTypeCode;

    if (_driverLicencePortraitImage != null && imageData == null) {
      imageData = _driverLicencePortraitImage;
    }

    if (_driverLicenceImageTypeCode != null && _imageDataType == null) {
      _imageDataType = _driverLicenceImageTypeCode;
    }
  }
}
