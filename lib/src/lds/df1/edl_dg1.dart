import 'dart:convert';
import 'dart:typed_data';

import 'package:vcmrtd/src/lds/df1/dg.dart';
import 'package:vcmrtd/src/lds/df1/efdg1.dart';

import '../../../vcmrtd.dart';

class EDL_DG1 {

  static const  ISSUING_MEMBER_STATE_TAG = 0X5F03;

  static const HOLDER_SURNAME_TAG = 0X5F04;
  static const HOLDER_OTHER_NAME_TAG = 0x5F05;

  // Dates are in DDMMYYYY format
  static const DATE_OF_BIRTH_TAG = 0X5F06;
  static const DATE_OF_ISSUE_TAG = 0X5F0A;
  static const DATE_OF_EXPIRY_TAG = 0x5F0B;

  static const PLACE_OF_BIRTH_TAG = 0X5F07;

  static const ISSUING_AUTHORITY_TAG = 0X5F0C;

  static const DOCUMENT_NUMBER_TAG = 0X5F0E;

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

  static EDL_DG1 fromTlv(TLV tlv) {

    final data = EDL_DG1();
    final bytes = tlv.value;
    int bytesRead = 0;

    while (bytesRead < bytes.length) {
      final tagValue = TLV.decode(bytes.sublist(bytesRead));
      bytesRead += tagValue.encodedLen;

      switch (tagValue.tag.value) {
        case ISSUING_MEMBER_STATE_TAG:
          data.issuingMemberState = utf8.decode(tagValue.value);
          break;
        case HOLDER_SURNAME_TAG:
          data.holderSurname = utf8.decode(tagValue.value);
          break;
        case HOLDER_OTHER_NAME_TAG:
          data.holderOtherName = utf8.decode(tagValue.value);
          break;
        case DATE_OF_BIRTH_TAG:
          data.dateOfBirth = utf8.decode(tagValue.value);
          break;
        case PLACE_OF_BIRTH_TAG:
          data.placeOfBirth = utf8.decode(tagValue.value);
          break;
        case DATE_OF_ISSUE_TAG:
          data.dateOfIssue = utf8.decode(tagValue.value);
          break;
        case DATE_OF_EXPIRY_TAG:
          data.dateOfExpiry = utf8.decode(tagValue.value);
          break;
        case ISSUING_AUTHORITY_TAG:
          data.issuingAuthority = utf8.decode(tagValue.value);
          break;
        case DOCUMENT_NUMBER_TAG:
          data.documentNumber = utf8.decode(tagValue.value);
          break;
        default:
          break;
      }
    }
    return data;
  }

}


