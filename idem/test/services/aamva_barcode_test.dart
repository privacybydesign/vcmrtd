import 'package:flutter_test/flutter_test.dart';
import 'package:idem/services/aamva_barcode.dart';
import 'package:vcmrtd/vcmrtd.dart';

const _usLicence =
    '@\n\x1e\rANSI 636014090102DL00410278ZC03190024DLDAQD1234562\nDCSERIKSSON\nDACANNA\n'
    'DBB08121974\nDBA08122030\nDAJCA\n';

void main() {
  test('reads a United States licence: its number, its MMDDCCYY dates and its surname', () {
    expect(readAamvaBarcode(_usLicence), (
      type: DocumentType.drivingLicence,
      documentNumber: 'D1234562',
      dateOfBirth: DateTime(1974, 8, 12),
      dateOfExpiry: DateTime(2030, 8, 12),
      personalNumber: null,
      licenceData: null,
      surname: 'ERIKSSON',
    ));
  });

  test('reads a Canadian identity card: its CCYYMMDD dates', () {
    final card = readAamvaBarcode('@\n\x1e\rANSI 636012090001ID00310222IDDAQ123456789\nDBB19740812\nDBA20300812\n');

    expect(card?.type, DocumentType.identityCard);
    expect(card?.dateOfBirth, DateTime(1974, 8, 12));
  });

  test('is null for a barcode that is not AAMVA', () {
    expect(readAamvaBarcode('https://example.org/ticket/12345'), isNull);
  });
}
