import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:vcmrtd/vcmrtd.dart';
import 'package:vcmrtdapp/providers/wallet_provider.dart';

Uint8List _jpeg() => Uint8List.fromList(img.encodeJpg(img.Image(width: 2, height: 2)));

PassportData _passportData() {
  final mrz = PassportMRZ(
    Uint8List.fromList(
      'P<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<L898902C36UTO7408122F1204159ZE184226B<<<<<10'.codeUnits,
    ),
  );
  return PassportData(
    mrz: mrz,
    photoImageData: _jpeg(),
    photoImageType: ImageType.jpeg,
    photoImageWidth: 2,
    photoImageHeight: 2,
  );
}

DrivingLicenceData _drivingLicenceData() {
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
    photoImageData: _jpeg(),
    bapInputString: 'D1NLD11234567890ABCDEFGHIJKLM5',
    saiType: 'sai',
    aaPublicKey: null,
    categories: const [],
  );
}

void main() {
  group('WalletCard.fromDocument', () {
    test('extracts holder name and document number from a passport', () {
      final card = WalletCard.fromDocument(_passportData(), DocumentType.passport);
      expect(card.documentType, DocumentType.passport);
      expect(card.holderName, 'ANNA MARIA ERIKSSON');
      expect(card.documentNumber, 'L898902C3');
    });

    test('joins holder names and reads document number from a driving licence', () {
      final card = WalletCard.fromDocument(_drivingLicenceData(), DocumentType.drivingLicence);
      expect(card.documentType, DocumentType.drivingLicence);
      expect(card.holderName, 'Anna Maria Eriksson');
      expect(card.documentNumber, '1234567890');
    });
  });

  group('WalletNotifier', () {
    test('starts empty', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(walletProvider), isEmpty);
    });

    test('add appends a card', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final card = WalletCard.fromDocument(_passportData(), DocumentType.passport);
      container.read(walletProvider.notifier).add(card);
      expect(container.read(walletProvider), [card]);
    });

    test('remove drops the card with the matching id', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final card1 = WalletCard.fromDocument(_passportData(), DocumentType.passport);
      final card2 = WalletCard.fromDocument(_drivingLicenceData(), DocumentType.drivingLicence);
      final notifier = container.read(walletProvider.notifier)
        ..add(card1)
        ..add(card2);
      notifier.remove(card1.id);
      expect(container.read(walletProvider), [card2]);
    });
  });
}
