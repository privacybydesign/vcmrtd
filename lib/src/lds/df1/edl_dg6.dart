import 'dart:typed_data';
import '../../../vcmrtd.dart';

class EDL_DG6 {
  static const BIOMETRIC_INFORMATION_GROUP_TEMPLATE_TAG = 0x7F61;
  static const BIOMETRIC_INFORMATION_TEMPLATE_TAG = 0x7F60;
  static const BIOMETRIC_HEADER_TEMPLATE_TAG = 0xA1;
  static const BIOMETRIC_DATA_BLOCK_TAG = 0x5F2E;
  static const NUMBER_OF_INSTANCES_TAG = 0x02;

  static const PATRON_HEADER_VERSION_TAG = 0x80;
  static const BIOMETRIC_TYPE_TAG = 0x81;
  static const BIOMETRIC_SUBTYPE_TAG = 0x82;
  static const CREATION_DATE_TAG = 0x83;
  static const VALIDITY_PERIOD_TAG = 0x85;
  static const CREATOR_TAG = 0x86;
  static const FORMAT_OWNER_TAG = 0x87;
  static const FORMAT_TYPE_TAG = 0x88;

  Uint8List? imageData;
  int? imageDataType; // 0 = JPEG, 1 = JPEG2000

  int? patronHeaderVersion;
  int? biometricType;
  int? numberOfInstances;

  EDL_DG6();

  ImageType? get imageType {
    if (imageDataType == null) return null;
    return imageDataType == 0 ? ImageType.jpeg : ImageType.jpeg2000;
  }

  static EDL_DG6 fromBytes(Uint8List bytes) {
    final data = EDL_DG6();

    try {

      final tlv = TLV.fromBytes(bytes);

      if (tlv.tag == BIOMETRIC_INFORMATION_GROUP_TEMPLATE_TAG) {
        _parseBiometricGroup(data, tlv.value);
      } else {
      }

      if (data.imageData != null) {
        final preview = data.imageData!.take(10).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
      } else {
      }
    } catch (e, stackTrace) {
      throw Exception("Error Decoding DG6: $e");
    }

    return data;
  }

  static void _parseBiometricGroup(EDL_DG6 data, Uint8List bytes) {
    int offset = 0;

    while (offset < bytes.length) {
      final tlv = TLV.decode(bytes.sublist(offset));

      switch (tlv.tag.value) {
        case NUMBER_OF_INSTANCES_TAG:
          data.numberOfInstances = tlv.value[0];
          break;

        case BIOMETRIC_INFORMATION_TEMPLATE_TAG:
          _parseBiometricTemplate(data, tlv.value);
          break;

        default:
          print('Unknown tag in biometric group: 0x${tlv.tag.value.toRadixString(16)}');
      }

      offset += tlv.encodedLen;
    }
  }

  static void _parseBiometricTemplate(EDL_DG6 data, Uint8List bytes) {
    int offset = 0;

    while (offset < bytes.length) {
      final tlv = TLV.decode(bytes.sublist(offset));

      switch (tlv.tag.value) {
        case BIOMETRIC_HEADER_TEMPLATE_TAG:
          _parseBiometricHeader(data, tlv.value);
          break;

        case BIOMETRIC_DATA_BLOCK_TAG:
          _parseFacialImageData(data, tlv.value);
          break;

        default:
      }

      offset += tlv.encodedLen;
    }
  }

  static void _parseFacialImageData(EDL_DG6 data, Uint8List bytes) {

    // Verify "FAC\0" header
    if (bytes.length < 4 ||
        bytes[0] != 0x46 || bytes[1] != 0x41 ||
        bytes[2] != 0x43 || bytes[3] != 0x00) {
      // Try to use raw data anyway
      data.imageData = bytes;
      return;
    }

    int offset = 4;

    // Version number (4 bytes) - should be "010\0"
    final version = _extractInt(bytes, offset, 4);
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
    offset += 1;

    // Eye color (1 byte)
    offset += 1;

    // Hair color (1 byte)
    offset += 1;

    // Feature mask (3 bytes)
    offset += 3;

    // Expression (2 bytes)
    offset += 2;

    // Pose angle (3 bytes)
    offset += 3;

    // Pose angle uncertainty (3 bytes)
    offset += 3;

    // Skip feature points (8 bytes each)
    offset += nrFeaturePoints * 8;

    // Face image type (1 byte)
    final faceImageType = bytes[offset];
    offset += 1;

    // Image data type (1 byte) - 0 = JPEG, 1 = JPEG2000
    data.imageDataType = bytes[offset];
    offset += 1;

    // Image width (2 bytes)
    final imageWidth = _extractInt(bytes, offset, 2);
    offset += 2;

    // Image height (2 bytes)
    final imageHeight = _extractInt(bytes, offset, 2);
    offset += 2;

    // Image color space (1 byte)
    offset += 1;

    // Source type (1 byte)
    offset += 1;

    // Device type (2 bytes)
    offset += 2;

    // Quality (2 bytes)
    offset += 2;

    // Now the actual image data starts
    data.imageData = bytes.sublist(offset);

    // Verify image format
    if (data.imageData!.length > 4) {
      final preview = data.imageData!.take(10).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');

      // Double check with magic bytes
      if (data.imageData![0] == 0xFF && data.imageData![1] == 0xD8) {
      } else if (data.imageData![0] == 0x00 && data.imageData![1] == 0x00 &&
          data.imageData![2] == 0x00 && data.imageData![3] == 0x0C) {
      }
    }
  }

  static void _parseBiometricHeader(EDL_DG6 data, Uint8List bytes) {
    int offset = 0;

    while (offset < bytes.length) {
      final tlv = TLV.decode(bytes.sublist(offset));

      switch (tlv.tag.value) {
        case PATRON_HEADER_VERSION_TAG:
          data.patronHeaderVersion = tlv.value.isNotEmpty ? tlv.value[0] : null;
          break;

        case BIOMETRIC_TYPE_TAG:
          data.biometricType = tlv.value.isNotEmpty ? tlv.value[0] : null;
          break;

        case FORMAT_TYPE_TAG:
          final formatBytes = tlv.value.take(4).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
          break;
      }

      offset += tlv.encodedLen;
    }
  }

  static int _extractInt(Uint8List data, int start, int length) {
    if (length == 1) {
      return data[start];
    } else if (length == 2) {
      return (data[start] << 8) | data[start + 1];
    } else if (length == 4) {
      return (data[start] << 24) |
      (data[start + 1] << 16) |
      (data[start + 2] << 8) |
      data[start + 3];
    }
    return 0;
  }
}