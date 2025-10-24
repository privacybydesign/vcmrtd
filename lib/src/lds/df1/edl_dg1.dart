import 'dart:convert';
import 'dart:typed_data';
import '../../../vcmrtd.dart';
import '../tlvSet.dart';

class EDL_DG1 {
  static const ISSUING_MEMBER_STATE_TAG = 0x5F03;
  static const HOLDER_SURNAME_TAG = 0x5F04;
  static const HOLDER_OTHER_NAME_TAG = 0x5F05;
  static const DATE_OF_BIRTH_TAG = 0x5F06;
  static const PLACE_OF_BIRTH_TAG = 0x5F07;
  static const DATE_OF_ISSUE_TAG = 0x5F0A;
  static const DATE_OF_EXPIRY_TAG = 0x5F0B;
  static const ISSUING_AUTHORITY_TAG = 0x5F0C;
  static const DOCUMENT_NUMBER_TAG = 0x5F0E;

  String? issuingMemberState;
  String? holderSurname;
  String? holderOtherName;
  String? dateOfBirth;
  String? placeOfBirth;
  String? dateOfIssue;
  String? dateOfExpiry;
  String? issuingAuthority;
  String? documentNumber;

  EDL_DG1();

  static EDL_DG1 fromBytes(Uint8List bytes) {
    final data = EDL_DG1();
    int offset = 0;
    final bytesLength = bytes.length;

    while (offset < bytesLength) {
      try {
        final tagValue = TLV.decode(bytes.sublist(offset));

        // Parse nested TLVs inside 0x5F02 tag
        if (tagValue.tag.value == 0x5F02) {
          final inner = TLVSet.decode(encodedData: tagValue.value);

          for (final innerTlv in inner.all) {
            _parseInnerTag(data, innerTlv);
          }
        }

        offset += tagValue.encodedLen;
      } catch (e) {
        break;
      }
    }

    return data;
  }

  /// Parse individual inner TLV tags and populate data fields
  static void _parseInnerTag(EDL_DG1 data, dynamic innerTlv) {
    switch (innerTlv.tag) {
      case ISSUING_MEMBER_STATE_TAG:
        data.issuingMemberState = utf8.decode(innerTlv.value);
        break;
      case HOLDER_SURNAME_TAG:
        data.holderSurname = utf8.decode(innerTlv.value);
        break;
      case HOLDER_OTHER_NAME_TAG:
        data.holderOtherName = utf8.decode(innerTlv.value);
        break;
      case DATE_OF_BIRTH_TAG:
        data.dateOfBirth = _decodeBcd(innerTlv.value);
        break;
      case PLACE_OF_BIRTH_TAG:
        data.placeOfBirth = utf8.decode(innerTlv.value);
        break;
      case DATE_OF_ISSUE_TAG:
        data.dateOfIssue = _decodeBcd(innerTlv.value);
        break;
      case DATE_OF_EXPIRY_TAG:
        data.dateOfExpiry = _decodeBcd(innerTlv.value);
        break;
      case ISSUING_AUTHORITY_TAG:
        data.issuingAuthority = utf8.decode(innerTlv.value);
        break;
      case DOCUMENT_NUMBER_TAG:
        data.documentNumber = utf8.decode(innerTlv.value);
        break;
      default:
        print(
          "Skipping unknown nested tag 0x${innerTlv.tag.toRadixString(16)}",
        );
    }
  }

  /// Convert BCD bytes (DDMMYYYY) to string like "21081990"
  static String _decodeBcd(List<int> bcd) {
    return bcd.map((b) {
      final high = (b >> 4) & 0x0F;
      final low = b & 0x0F;
      return '$high$low';
    }).join();
  }
}
