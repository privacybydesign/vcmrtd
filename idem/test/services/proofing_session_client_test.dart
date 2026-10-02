import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mrz_capture/mrz_capture.dart';
import 'package:vcmrtd/vcmrtd.dart';
import 'package:idem/services/proofing_session_client.dart';

void main() {
  group('timeouts', _timeoutTests);

  group('ProofingChipAccess', () {
    test('round-trips a driving licence key through the server view into the NFC screen\'s MRZ', () {
      final key = ProofingChipAccess.fromScannedMrz(
        ScannedDriverLicenseMRZ(
          documentNumber: 'DL123',
          countryCode: 'NLD',
          version: '1',
          randomData: 'RND',
          configuration: 'CFG',
        ),
        DocumentType.drivingLicence,
      );
      final json = key.toJson();
      expect(json['documentType'], 'drivers_license');
      final mrz = ProofingChipAccess.fromJson(json)!.toScannedMrz() as ScannedDriverLicenseMRZ;
      expect([mrz.documentNumber, mrz.version, mrz.randomData, mrz.configuration], ['DL123', '1', 'RND', 'CFG']);
    });

    test('an incomplete key opens nothing', () {
      expect(ProofingChipAccess.fromJson({'documentType': 'passport'}), isNull);
      expect(ProofingChipAccess.fromJson({'documentType': 'passport', 'documentNumber': 'X1'})!.toScannedMrz(), isNull);
    });
  });

  group('ProofingFaceVerification', () {
    Map<String, dynamic> view([Object? faceVerification]) => {
      'id': 's1',
      'relyingParty': 'RP',
      'expiresAt': '2030-01-01T00:00:00Z',
      'faceVerification': ?faceVerification,
    };

    test('parses the Regula announcement from the session view', () {
      final info = ProofingSessionInfo.fromJson(
        view({'provider': 'regula', 'faceApiUrl': 'https://faceapi.test', 'tag': 'ips-tref_s1'}),
      );
      expect(info.faceVerification?.isRegula, isTrue);
      expect(info.faceVerification?.faceApiUrl, 'https://faceapi.test');
      expect(info.faceVerification?.tag, 'ips-tref_s1');
      expect(info.faceVerification?.requiredBySession, isTrue);
    });

    test('is absent without an announcement, and not Regula without a Face API url', () {
      expect(ProofingSessionInfo.fromJson(view()).faceVerification, isNull);
      final partial = ProofingSessionInfo.fromJson(view({'provider': 'regula'}));
      expect(partial.faceVerification?.isRegula, isFalse);
    });
  });

  group('ProofingSessionInfo.requiresActiveAuthentication', () {
    Map<String, dynamic> view([List<String>? requiredChecks]) => {
      'id': 's1',
      'relyingParty': 'RP',
      'expiresAt': '2030-01-01T00:00:00Z',
      'requiredChecks': ?requiredChecks,
    };

    test('follows the flow: on with nfc.chip_auth, off without it', () {
      final withChipAuth = ProofingSessionInfo.fromJson(view(['nfc.passive_auth', checkNfcChipAuth]));
      expect(withChipAuth.requiresActiveAuthentication, isTrue);
      expect(ProofingSessionInfo.fromJson(view(['nfc.passive_auth'])).requiresActiveAuthentication, isFalse);
    });

    test('is on for a server that does not list its checks', () {
      expect(ProofingSessionInfo.fromJson(view()).requiresActiveAuthentication, isTrue);
    });
  });

  group('ProofingSessionRef.parse', () {
    test('parses the https qr payload (https://{host}/s/{token})', () {
      final ref = ProofingSessionRef.parse('https://proof.example.com/s/abc123');
      expect(ref, isNotNull);
      expect(ref!.apiBase, 'https://proof.example.com');
      expect(ref.token, 'abc123');
    });

    test('parses the vcmrtd:// deep link', () {
      final ref = ProofingSessionRef.parse('vcmrtd://verify?token=abc123&api=https://proof.example.com');
      expect(ref, isNotNull);
      expect(ref!.apiBase, 'https://proof.example.com');
      expect(ref.token, 'abc123');
    });

    test('preserves a non-default port on the https form', () {
      final ref = ProofingSessionRef.parse('http://localhost:8080/s/abc123');
      expect(ref, isNotNull);
      expect(ref!.apiBase, 'http://localhost:8080');
      expect(ref.token, 'abc123');
    });

    test('rejects unrelated QR content', () {
      expect(ProofingSessionRef.parse('https://example.com/some/other/path'), isNull);
      expect(ProofingSessionRef.parse('not a url at all'), isNull);
      expect(ProofingSessionRef.parse('vcmrtd://verify?token=onlytoken'), isNull);
    });
  });

  group('ProofingDocumentInfo', () {
    test('fromPassportData + toJson round-trips MRZ fields, prefers DG11 displayName', () {
      final data = _fakePassportData(nameOfHolder: 'Anna Marià Eriksson');
      final json = ProofingDocumentInfo.fromPassportData(data).toJson();
      final mrz = data.mrz;
      expect(json['type'], mrz.documentCode);
      expect(json['number'], mrz.documentNumber);
      expect(json['issuingState'], mrz.country);
      expect(json['nationality'], mrz.nationality);
      expect(json['firstName'], mrz.firstName);
      expect(json['lastName'], mrz.lastName);
      expect(json['dateOfBirth'], '1990-01-05');
      expect(json['dateOfExpiry'], '2030-12-31');
      // DG11 name (diacritics preserved), not the ICAO-transliterated MRZ name.
      expect(json['displayName'], 'Anna Marià Eriksson');
      // A PassportMRZ that parsed without throwing already passed every
      // check digit; only notExpired is independently computed.
      expect(json['validity'], {
        'documentNumberCheckDigitValid': true,
        'dateOfBirthCheckDigitValid': true,
        'dateOfExpiryCheckDigitValid': true,
        'compositeCheckDigitValid': true,
        'notExpired': true,
      });
    });

    test('falls back to the MRZ name for displayName when DG11 is absent', () {
      final data = _fakePassportData();
      final json = ProofingDocumentInfo.fromPassportData(data).toJson();
      expect(json['displayName'], data.displayName);
      expect(json.containsKey('personalNumber'), isFalse);
      expect(json.containsKey('placeOfBirth'), isFalse);
    });

    test('includes DG11 extras only when the document carries them', () {
      final data = _fakePassportData(personalNumber: 'ABC123', placeOfBirth: ['Stockholm', 'SWE']);
      final json = ProofingDocumentInfo.fromPassportData(data).toJson();
      expect(json['personalNumber'], 'ABC123');
      expect(json['placeOfBirth'], 'Stockholm, SWE');
    });

    test('fromDrivingLicenceData + toJson maps DG1 fields, with no nationality/sex (DL DG1 carries neither)', () {
      final data = _fakeDrivingLicenceData();
      final json = ProofingDocumentInfo.fromDrivingLicenceData(data).toJson();
      expect(json['type'], documentTypeToString(DocumentType.drivingLicence));
      expect(json['number'], data.documentNumber);
      expect(json['issuingState'], data.issuingMemberState);
      expect(json['firstName'], data.holderOtherName);
      expect(json['lastName'], data.holderSurname);
      expect(json['displayName'], 'Anna Maria Eriksson');
      expect(json['dateOfBirth'], '1974-08-12');
      expect(json['dateOfExpiry'], '2034-02-01');
      expect(json['placeOfBirth'], 'Utopia');
      expect(json.containsKey('nationality'), isFalse);
      expect(json.containsKey('sex'), isFalse);
      // Driving licences have no MRZ to compute check-digit validity from.
      expect(json.containsKey('validity'), isFalse);
    });
  });

  group('ProofingPhotoInfo.fromImage', () {
    test('base64-encodes the image bytes and maps ImageType to a MIME type', () {
      final json = ProofingPhotoInfo.fromImage(Uint8List.fromList([1, 2, 3]), ImageType.jpeg).toJson();
      expect(json['imageBase64'], base64Encode([1, 2, 3]));
      expect(json['mimeType'], 'image/jpeg');
      expect(ProofingPhotoInfo.fromImage(Uint8List(0), ImageType.jpeg2000).toJson()['mimeType'], 'image/jp2');
    });

    test('falls back to image/jpeg when the driving licence carries no photoImageType', () {
      final json = ProofingPhotoInfo.fromImage(Uint8List(0), null).toJson();
      expect(json['mimeType'], 'image/jpeg');
    });
  });

  group('ProofingPhotoInfo.fromSelfie', () {
    test('detects a PNG signature (the on-device engine\'s encoding)', () {
      final png = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 1, 2, 3]);
      final json = ProofingPhotoInfo.fromSelfie(png).toJson();
      expect(json['mimeType'], 'image/png');
      expect(json['imageBase64'], base64Encode(png));
    });

    test('falls back to image/jpeg for anything without a PNG signature', () {
      final jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3]);
      expect(ProofingPhotoInfo.fromSelfie(jpeg).toJson()['mimeType'], 'image/jpeg');
      expect(ProofingPhotoInfo.fromSelfie(Uint8List(0)).toJson()['mimeType'], 'image/jpeg');
    });
  });

  group('ProofingMrtdEvidence', () {
    test('toJson includes only the AA fields that are set', () {
      const evidence = ProofingMrtdEvidence(
        efSod: 'aabb',
        dataGroups: {'DG1': '1122', 'DG2': '3344'},
        documentType: 'icao',
        aaKeyDataGroup: 'DG15',
        nonce: '0011223344556677',
        aaSignature: 'ccdd',
      );
      expect(evidence.toJson(), {
        'efSod': 'aabb',
        'dataGroups': {'DG1': '1122', 'DG2': '3344'},
        'documentType': 'icao',
        'aaKeyDataGroup': 'DG15',
        'nonce': '0011223344556677',
        'aaSignature': 'ccdd',
      });
    });

    test('toJson omits AA fields entirely when unset, rather than sending nulls', () {
      const evidence = ProofingMrtdEvidence(efSod: 'aabb', dataGroups: {'DG1': '1122'}, documentType: 'icao');
      expect(evidence.toJson(), {
        'efSod': 'aabb',
        'dataGroups': {'DG1': '1122'},
        'documentType': 'icao',
      });
    });

    test('fromRawDocumentData reports AA attempted only when the key DG, nonce and signature are all present', () {
      final result = RawDocumentData(
        dataGroups: {'DG1': '1122', 'DG15': '5F0102'},
        efSod: 'aabb',
        nonce: Uint8List.fromList([0x01, 0x02]),
        aaSignature: Uint8List.fromList([0x03, 0x04]),
      );
      final evidence = ProofingMrtdEvidence.fromRawDocumentData(result, aaKeyDataGroup: 'DG15', documentType: 'icao');
      expect(evidence.efSod, 'aabb');
      expect(evidence.dataGroups, {'DG1': '1122', 'DG15': '5F0102'});
      expect(evidence.documentType, 'icao');
      expect(evidence.aaKeyDataGroup, 'DG15');
      expect(evidence.nonce, '0102');
      expect(evidence.aaSignature, '0304');
    });

    test('fromRawDocumentData reports AA not attempted when the chip has no AA key data group', () {
      final result = RawDocumentData(
        dataGroups: {'DG1': '1122'},
        efSod: 'aabb',
        nonce: Uint8List.fromList([0x01, 0x02]),
        aaSignature: Uint8List.fromList([0x03, 0x04]),
      );
      final evidence = ProofingMrtdEvidence.fromRawDocumentData(result, aaKeyDataGroup: 'DG15', documentType: 'icao');
      expect(evidence.aaKeyDataGroup, isNull);
      expect(evidence.nonce, isNull);
      expect(evidence.aaSignature, isNull);
    });

    test('fromRawDocumentData reports AA not attempted when no nonce/signature was captured', () {
      final result = RawDocumentData(dataGroups: {'DG1': '1122', 'DG13': '5F0102'}, efSod: 'aabb');
      final evidence = ProofingMrtdEvidence.fromRawDocumentData(
        result,
        aaKeyDataGroup: 'DG13',
        documentType: 'eu_driving_licence',
      );
      expect(evidence.documentType, 'eu_driving_licence');
      expect(evidence.aaKeyDataGroup, isNull);
      expect(evidence.nonce, isNull);
      expect(evidence.aaSignature, isNull);
    });
  });

  group('ProofingDeviceInfo.toJson', () {
    test('includes only the fields that are set', () {
      final json = const ProofingDeviceInfo(appVersion: '0.1.0+11', devicePlatform: 'ios').toJson();
      expect(json, {'appVersion': '0.1.0+11', 'devicePlatform': 'ios'});
    });
  });

  group('ProofingSessionClient', () {
    const ref = ProofingSessionRef(apiBase: 'https://proof.example.com', token: 'tok-1');

    test('fetchSession parses a successful response into a ProofingSessionInfo', () async {
      await http.runWithClient(
        () async {
          final info = await const ProofingSessionClient().fetchSession(ref);
          expect(info.id, 'sess-1');
          expect(info.relyingParty, 'Acme Corp');
          expect(info.requestedAttributes, ['dg1']);
        },
        () => MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.toString(), 'https://proof.example.com/api/v1/app/tok-1');
          return http.Response(
            json.encode({
              'id': 'sess-1',
              'relyingParty': 'Acme Corp',
              'requestedAttributes': ['dg1'],
              'expiresAt': '2030-01-01T00:00:00Z',
            }),
            200,
          );
        }),
      );
    });

    test('fetchSession parses an optional steps list when the response carries one', () async {
      await http.runWithClient(
        () async {
          final info = await const ProofingSessionClient().fetchSession(ref);
          expect(info.steps, ['document_capture', 'nfc_read', 'selfie', 'liveness', 'face_match']);
        },
        () => MockClient((request) async {
          return http.Response(
            json.encode({
              'id': 'sess-1',
              'relyingParty': 'Acme Corp',
              'requestedAttributes': ['dg1'],
              'expiresAt': '2030-01-01T00:00:00Z',
              'steps': ['document_capture', 'nfc_read', 'selfie', 'liveness', 'face_match'],
            }),
            200,
          );
        }),
      );
    });

    test('fetchSession leaves steps null when the response omits it', () async {
      await http.runWithClient(
        () async {
          final info = await const ProofingSessionClient().fetchSession(ref);
          expect(info.steps, isNull);
        },
        () => MockClient((request) async {
          return http.Response(
            json.encode({
              'id': 'sess-1',
              'relyingParty': 'Acme Corp',
              'requestedAttributes': ['dg1'],
              'expiresAt': '2030-01-01T00:00:00Z',
            }),
            200,
          );
        }),
      );
    });

    test('fetchSession parses referencePhoto when the response carries one', () async {
      await http.runWithClient(
        () async {
          final info = await const ProofingSessionClient().fetchSession(ref);
          expect(info.referencePhoto, isNotNull);
          expect(info.referencePhoto!.imageBase64, 'aGVsbG8=');
          expect(info.referencePhoto!.mimeType, 'image/jpeg');
        },
        () => MockClient((request) async {
          return http.Response(
            json.encode({
              'id': 'sess-1',
              'relyingParty': 'Acme Corp',
              'requestedAttributes': ['dg1'],
              'expiresAt': '2030-01-01T00:00:00Z',
              'steps': ['document_capture', 'selfie', 'face_match'],
              'referencePhoto': {'imageBase64': 'aGVsbG8=', 'mimeType': 'image/jpeg'},
            }),
            200,
          );
        }),
      );
    });

    test('fetchSession leaves referencePhoto null when the response omits it', () async {
      await http.runWithClient(
        () async {
          final info = await const ProofingSessionClient().fetchSession(ref);
          expect(info.referencePhoto, isNull);
        },
        () => MockClient((request) async {
          return http.Response(
            json.encode({
              'id': 'sess-1',
              'relyingParty': 'Acme Corp',
              'requestedAttributes': ['dg1'],
              'expiresAt': '2030-01-01T00:00:00Z',
            }),
            200,
          );
        }),
      );
    });

    test('fetchSession throws when the server responds with a non-200 status', () async {
      await http.runWithClient(() async {
        expect(() => const ProofingSessionClient().fetchSession(ref), throwsA(isA<Exception>()));
      }, () => MockClient((request) async => http.Response('not found', 404)));
    });

    test('fetchSession parses selfieLocation when the response carries one', () async {
      await http.runWithClient(
        () async {
          final info = await const ProofingSessionClient().fetchSession(ref);
          expect(info.selfieLocation, 'native');
        },
        () => MockClient((request) async {
          return http.Response(
            json.encode({
              'id': 'sess-1',
              'relyingParty': 'Acme Corp',
              'requestedAttributes': ['dg1'],
              'expiresAt': '2030-01-01T00:00:00Z',
              'selfieLocation': 'native',
            }),
            200,
          );
        }),
      );
    });

    test('fetchSession defaults selfieLocation to "browser" when the response omits it', () async {
      await http.runWithClient(
        () async {
          final info = await const ProofingSessionClient().fetchSession(ref);
          expect(info.selfieLocation, 'browser');
        },
        () => MockClient((request) async {
          return http.Response(
            json.encode({
              'id': 'sess-1',
              'relyingParty': 'Acme Corp',
              'requestedAttributes': ['dg1'],
              'expiresAt': '2030-01-01T00:00:00Z',
            }),
            200,
          );
        }),
      );
    });

    test('submitNfcStep posts to .../steps/nfc with mrtdEvidence always included, no status', () async {
      await http.runWithClient(
        () async {
          await const ProofingSessionClient().submitNfcStep(
            ref,
            requestedAttributes: const [],
            mrtdEvidence: const ProofingMrtdEvidence(efSod: 'aa', dataGroups: {'DG1': 'bb'}, documentType: 'icao'),
          );
        },
        () => MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.toString(), 'https://proof.example.com/api/v1/app/tok-1/steps/nfc');
          final body = json.decode(request.body) as Map<String, dynamic>;
          expect(body.containsKey('status'), isFalse);
          expect(body['mrtdEvidence'], isNotNull);
          return http.Response(
            json.encode({
              'status': 'in_progress',
              'completedSteps': ['document_capture', 'nfc_read'],
              'currentStep': 'face_verification',
            }),
            200,
          );
        }),
      );
    });

    test('submitDocumentPhotoStep posts front and back to .../steps/document_photo, leaving out a missing back '
        'and a bsnRegion nobody gave', () async {
      final bodies = <Map<String, dynamic>>[];
      await http.runWithClient(
        () async {
          const front = ProofingDocumentPhotoSide(
            photo: ProofingPhotoInfo(imageBase64: 'ZnJvbnQ=', mimeType: 'image/jpeg'),
          );
          const back = ProofingDocumentPhotoSide(
            photo: ProofingPhotoInfo(imageBase64: 'YmFjaw==', mimeType: 'image/jpeg'),
            bsnRegion: ProofingImageRegion(x: 0.1, y: 0.2, w: 0.3, h: 0.05),
          );
          final response = await const ProofingSessionClient().submitDocumentPhotoStep(ref, front: front, back: back);
          expect(response.readyToSubmit, isTrue);
          await const ProofingSessionClient().submitDocumentPhotoStep(ref, front: front);
        },
        () => MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.toString(), 'https://proof.example.com/api/v1/app/tok-1/steps/document_photo');
          expect(request.headers['Content-Type'], startsWith('application/json'));
          bodies.add(json.decode(request.body) as Map<String, dynamic>);
          return http.Response(
            json.encode({
              'status': 'in_progress',
              'completedSteps': ['document_photo'],
              'currentStep': '',
              'lifecycle': 'ACTIVE',
              'readyToSubmit': true,
            }),
            200,
          );
        }),
      );
      expect(bodies[0], {
        'front': {'image': 'ZnJvbnQ=', 'mimeType': 'image/jpeg'},
        'back': {
          'image': 'YmFjaw==',
          'mimeType': 'image/jpeg',
          'bsnRegion': {'x': 0.1, 'y': 0.2, 'w': 0.3, 'h': 0.05},
        },
      });
      // A passport: no back key at all.
      expect(bodies[1], {
        'front': {'image': 'ZnJvbnQ=', 'mimeType': 'image/jpeg'},
      });
    });

    test('submitDocumentPhotoStep throws when the server responds with a non-200 status', () async {
      await http.runWithClient(() async {
        expect(
          () => const ProofingSessionClient().submitDocumentPhotoStep(
            ref,
            front: const ProofingDocumentPhotoSide(
              photo: ProofingPhotoInfo(imageBase64: 'anBlZw==', mimeType: 'image/jpeg'),
            ),
          ),
          throwsA(isA<Exception>()),
        );
      }, () => MockClient((request) async => http.Response('invalid image', 400)));
    });

    test('submitNfcStep throws when the server responds with a non-200 status', () async {
      await http.runWithClient(() async {
        expect(
          () => const ProofingSessionClient().submitNfcStep(
            ref,
            requestedAttributes: const [],
            mrtdEvidence: const ProofingMrtdEvidence(efSod: 'aa', dataGroups: {'DG1': 'bb'}, documentType: 'icao'),
          ),
          throwsA(isA<Exception>()),
        );
      }, () => MockClient((request) async => http.Response('server error', 500)));
    });
  });

  group('nativeFaceVerificationRequested', () {
    test('null steps always means vcmrtd runs it, regardless of selfieLocation', () {
      expect(nativeFaceVerificationRequested(null, 'browser'), isTrue);
      expect(nativeFaceVerificationRequested(null, 'native'), isTrue);
    });

    test('steps with no face stage at all means neither client runs it', () {
      expect(nativeFaceVerificationRequested(['document_capture', 'nfc_read'], 'browser'), isFalse);
      expect(nativeFaceVerificationRequested(['document_capture', 'nfc_read'], 'native'), isFalse);
    });

    test('a face stage with selfieLocation "browser" defers to the browser hosted flow', () {
      expect(
        nativeFaceVerificationRequested(['document_capture', 'nfc_read', 'face_verification'], 'browser'),
        isFalse,
      );
      expect(nativeFaceVerificationRequested(['nfc_read', 'document_capture', 'selfie'], 'browser'), isFalse);
    });

    test('a face stage with selfieLocation "native" (or anything else) runs on-device', () {
      expect(nativeFaceVerificationRequested(['document_capture', 'nfc_read', 'face_verification'], 'native'), isTrue);
      expect(nativeFaceVerificationRequested(['selfie', 'face_match'], 'native'), isTrue);
    });
  });

  group('buildProofingNfcStepBody', () {
    final mrtdEvidence = const ProofingMrtdEvidence(efSod: 'aa', dataGroups: {'DG1': 'bb'}, documentType: 'icao');

    test('mrtdEvidence is always included, whatever requestedAttributes says', () {
      final body = buildProofingNfcStepBody(requestedAttributes: const [], mrtdEvidence: mrtdEvidence);
      expect(body['mrtdEvidence'], isNotNull);
      expect(body.containsKey('status'), isFalse);
      expect(body.containsKey('selfie'), isFalse);
      expect(body.containsKey('biometrics'), isFalse);
    });

    test('document and photo are still gated by requestedAttributes', () {
      final doc = ProofingDocumentInfo(type: 'P');
      final photo = const ProofingPhotoInfo(imageBase64: 'img', mimeType: 'image/jpeg');
      final body = buildProofingNfcStepBody(
        requestedAttributes: const ['dg1'],
        document: doc,
        photo: photo,
        mrtdEvidence: mrtdEvidence,
      );
      expect(body['document'], isNotNull);
      expect(body.containsKey('photo'), isFalse);
    });

    test('the photo is sent anyway when a face step follows - it is what that step compares against', () {
      final body = buildProofingNfcStepBody(
        requestedAttributes: const ['dg1'],
        photo: const ProofingPhotoInfo(imageBase64: 'img', mimeType: 'image/jpeg'),
        mrtdEvidence: mrtdEvidence,
        faceStepFollows: true,
      );
      expect(body['photo'], {'imageBase64': 'img', 'mimeType': 'image/jpeg'});
    });
  });
}

PassportMRZ _fakeMrz() {
  // A synthetic TD3 (passport) MRZ: two 44-char lines, 88 bytes total with
  // no separator — PassportMRZ picks the TD3 parser by length — with check
  // digits computed to match PassportMRZ.calculateCheckDigit so parsing
  // doesn't throw on a check-digit mismatch.
  const line1 = 'P<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<';
  const line2 = 'L898902C<3UTO9001055F3012316<<<<<<<<<<<<<<02';
  return PassportMRZ(Uint8List.fromList('$line1$line2'.codeUnits));
}

PassportData _fakePassportData({String? nameOfHolder, String? personalNumber, List<String>? placeOfBirth}) {
  return PassportData(
    mrz: _fakeMrz(),
    photoImageData: Uint8List(0),
    photoImageType: ImageType.jpeg,
    photoImageWidth: 0,
    photoImageHeight: 0,
    nameOfHolder: nameOfHolder,
    personalNumber: personalNumber,
    placeOfBirth: placeOfBirth,
  );
}

DrivingLicenceData _fakeDrivingLicenceData() {
  return DrivingLicenceData(
    issuingMemberState: 'NLD',
    holderSurname: 'Eriksson',
    holderOtherName: 'Anna Maria',
    dateOfBirth: '12081974',
    placeOfBirth: 'Utopia',
    dateOfIssue: '01022024',
    dateOfExpiry: '01022034',
    issuingAuthority: 'RDW',
    documentNumber: '1234567890',
    photoImageData: Uint8List(0),
    bapInputString: 'D1NLD11234567890ABCDEFGHIJKLM5',
    saiType: 'sai',
    aaPublicKey: null,
    categories: [DrivingLicenceCategory(category: 'B', dateOfIssue: '01022024', dateOfExpiry: '01022034')],
    photoImageType: ImageType.jpeg,
  );
}

void _timeoutTests() {
  const ref = ProofingSessionRef(apiBase: 'https://proof.example.com', token: 'tok-1');

  testWidgets('a request the server never answers fails after the timeout', (tester) async {
    Object? error;
    await http.runWithClient(() async {
      const ProofingSessionClient()
          .reportDeviceState(ref, active: true)
          .then<void>(
            (_) {},
            onError: (Object e) {
              error = e;
            },
          );
      await tester.pump(ProofingSessionClient.requestTimeout - const Duration(seconds: 1));
      expect(error, isNull);
      await tester.pump(const Duration(seconds: 2));
    }, () => MockClient((_) => Completer<http.Response>().future));
    expect(error, isA<Exception>());
    expect('$error', contains('did not respond in time'));
  });

  testWidgets('an upload gets the longer timeout', (tester) async {
    Object? error;
    await http.runWithClient(() async {
      const ProofingSessionClient()
          .submitSession(ref)
          .then<void>(
            (_) {},
            onError: (Object e) {
              error = e;
            },
          );
      await tester.pump(ProofingSessionClient.requestTimeout + const Duration(seconds: 1));
      expect(error, isNull);
      await tester.pump(ProofingSessionClient.uploadTimeout);
    }, () => MockClient((_) => Completer<http.Response>().future));
    expect('$error', contains('did not respond in time'));
  });

  testWidgets('a timed-out request is aborted, so it cannot still reach the server later', (tester) async {
    final client = _UnansweredClient();
    await http.runWithClient(() async {
      const ProofingSessionClient().reportDeviceState(ref, active: false).then<void>((_) {}, onError: (Object _) {});
      await tester.pump(const Duration(seconds: 1));
      expect(client.closed, isFalse);
      await tester.pump(ProofingSessionClient.requestTimeout);
    }, () => client);
    expect(client.closed, isTrue);
  });

  testWidgets('a claim gets the longer timeout, since its grant can only be used once', (tester) async {
    Object? error;
    await http.runWithClient(() async {
      const ProofingSessionClient()
          .claimHandover(
            ProofingSessionLink.parse('vcmrtd://verify?handover=h-1&api=https://proof.example.com')!
                as ProofingHandoverLink,
          )
          .then<void>(
            (_) {},
            onError: (Object e) {
              error = e;
            },
          );
      await tester.pump(ProofingSessionClient.requestTimeout + const Duration(seconds: 1));
      expect(error, isNull);
      await tester.pump(ProofingSessionClient.uploadTimeout);
    }, () => MockClient((_) => Completer<http.Response>().future));
    expect('$error', contains('did not respond in time'));
  });
}

/// Never answers; records whether it was closed (which aborts the request).
class _UnansweredClient extends http.BaseClient {
  var closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) => Completer<http.StreamedResponse>().future;

  @override
  void close() => closed = true;
}
