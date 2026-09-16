import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vcmrtd/vcmrtd.dart';
import 'package:vcmrtdapp/services/proofing_session_client.dart';

void main() {
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

  group('ProofingBiometricsInfo.toJson', () {
    test('includes only the fields that are set', () {
      final json = const ProofingBiometricsInfo(
        faceMatchScore: 0.82,
        faceVerified: true,
        livenessResult: 'passed',
        engine: 'on_device',
      ).toJson();
      expect(json, {'faceMatchScore': 0.82, 'faceVerified': true, 'livenessResult': 'passed', 'engine': 'on_device'});
    });

    test('omits the Iris-only-null faceMatchScore when the Iris SDK ran', () {
      final json = const ProofingBiometricsInfo(faceVerified: true, livenessResult: 'passed', engine: 'iris').toJson();
      expect(json.containsKey('faceMatchScore'), isFalse);
      expect(json['engine'], 'iris');
    });
  });

  group('ProofingDeviceInfo.toJson', () {
    test('includes only the fields that are set', () {
      final json = const ProofingDeviceInfo(appVersion: '0.1.0+11', devicePlatform: 'ios').toJson();
      expect(json, {'appVersion': '0.1.0+11', 'devicePlatform': 'ios'});
    });
  });

  group('buildProofingResultBody', () {
    ProofingDocumentInfo document() => ProofingDocumentInfo.fromPassportData(
      _fakePassportData(personalNumber: 'ABC123', placeOfBirth: ['Stockholm', 'SWE']),
    );
    ProofingPhotoInfo photo() => ProofingPhotoInfo.fromImage(Uint8List.fromList([1, 2, 3]), ImageType.jpeg);
    ProofingPhotoInfo selfie() => ProofingPhotoInfo.fromSelfie(Uint8List.fromList([4, 5, 6]));
    const mrtdEvidence = ProofingMrtdEvidence(efSod: 'aabb', dataGroups: {'DG1': '1122'}, documentType: 'icao');
    const biometrics = ProofingBiometricsInfo(faceVerified: true, livenessResult: 'passed');
    const device = ProofingDeviceInfo(appVersion: '0.1.0+11', devicePlatform: 'ios');

    test('an empty requestedAttributes list is unrestricted — everything provided is sent', () {
      final body = buildProofingResultBody(
        status: 'approved',
        requestedAttributes: const [],
        document: document(),
        photo: photo(),
        selfie: selfie(),
        mrtdEvidence: mrtdEvidence,
        biometrics: biometrics,
        device: device,
      );
      expect(body.keys.toSet(), {'status', 'document', 'photo', 'selfie', 'mrtdEvidence', 'biometrics', 'device'});
      expect((body['document'] as Map)['personalNumber'], 'ABC123');
    });

    test('"dg1" alone includes the document but drops the dg11 extras, photo and selfie', () {
      final body = buildProofingResultBody(
        status: 'approved',
        requestedAttributes: const ['dg1'],
        document: document(),
        photo: photo(),
        selfie: selfie(),
        mrtdEvidence: mrtdEvidence,
        biometrics: biometrics,
        device: device,
      );
      expect(body.containsKey('document'), isTrue);
      expect((body['document'] as Map).containsKey('personalNumber'), isFalse);
      expect((body['document'] as Map).containsKey('placeOfBirth'), isFalse);
      expect(body.containsKey('photo'), isFalse);
      expect(body.containsKey('selfie'), isFalse);
      expect(body.containsKey('mrtdEvidence'), isFalse);
      expect(body.containsKey('biometrics'), isFalse);
      // device is operational metadata, never gated.
      expect(body.containsKey('device'), isTrue);
    });

    test('"selfie" gates the selfie independently of "dg2"/"face_image" (the document photo)', () {
      final body = buildProofingResultBody(
        status: 'approved',
        requestedAttributes: const ['selfie'],
        photo: photo(),
        selfie: selfie(),
      );
      expect(body.containsKey('photo'), isFalse);
      expect(body.containsKey('selfie'), isTrue);
    });

    test('"dg1" plus "dg11" includes the dg11 extras too', () {
      final body = buildProofingResultBody(
        status: 'approved',
        requestedAttributes: const ['dg1', 'dg11'],
        document: document(),
      );
      expect((body['document'] as Map)['personalNumber'], 'ABC123');
      expect((body['document'] as Map)['placeOfBirth'], 'Stockholm, SWE');
    });

    test('"face_image" is an alias for "dg2" for the photo', () {
      final body = buildProofingResultBody(
        status: 'approved',
        requestedAttributes: const ['face_image'],
        photo: photo(),
      );
      expect(body.containsKey('photo'), isTrue);
      expect(body.containsKey('document'), isFalse);
    });

    test('"chip_checks" gates mrtdEvidence alone', () {
      final body = buildProofingResultBody(
        status: 'approved',
        requestedAttributes: const ['chip_checks'],
        mrtdEvidence: mrtdEvidence,
        biometrics: biometrics,
      );
      expect(body.containsKey('mrtdEvidence'), isTrue);
      expect(body.containsKey('biometrics'), isFalse);
    });

    test('"biometrics" gates biometrics alone', () {
      final body = buildProofingResultBody(
        status: 'approved',
        requestedAttributes: const ['biometrics'],
        mrtdEvidence: mrtdEvidence,
        biometrics: biometrics,
      );
      expect(body.containsKey('biometrics'), isTrue);
      expect(body.containsKey('mrtdEvidence'), isFalse);
    });

    test('an attribute nothing was requested for is never sent, even when provided', () {
      final body = buildProofingResultBody(
        status: 'approved',
        requestedAttributes: const ['biometrics'],
        photo: photo(),
      );
      expect(body.containsKey('photo'), isFalse);
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
          expect(request.url.toString(), 'https://proof.example.com/api/proofing/app/tok-1');
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

    test('submitResult posts the built body and succeeds on a 200 response', () async {
      await http.runWithClient(
        () async {
          await const ProofingSessionClient().submitResult(ref, status: 'approved', requestedAttributes: const []);
        },
        () => MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.toString(), 'https://proof.example.com/api/proofing/app/tok-1/result');
          expect(request.headers['Content-Type'], 'application/json');
          final body = json.decode(request.body) as Map<String, dynamic>;
          expect(body['status'], 'approved');
          return http.Response('', 200);
        }),
      );
    });

    test('submitResult throws when the server responds with a non-200 status', () async {
      await http.runWithClient(() async {
        expect(
          () => const ProofingSessionClient().submitResult(ref, status: 'approved', requestedAttributes: const []),
          throwsA(isA<Exception>()),
        );
      }, () => MockClient((request) async => http.Response('server error', 500)));
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
