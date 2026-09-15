import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:vcmrtd/vcmrtd.dart';
import 'package:vcmrtdapp/providers/wallet_provider.dart';
import 'package:vcmrtdapp/widgets/pages/wallet_widgets.dart';

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

void main() {
  group('WalletEmptyState', () {
    testWidgets('shows the empty state copy', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: WalletEmptyState()));
      await tester.pump();

      expect(find.text('Your wallet is empty'), findsOneWidget);
    });
  });

  group('WalletList', () {
    testWidgets('lists cards, most recently added first', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final card = WalletCard.fromDocument(_passportData(), DocumentType.passport);
      container.read(walletProvider.notifier).add(card);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: WalletList(cards: container.read(walletProvider))),
        ),
      );
      await tester.pump();

      expect(find.text('ANNA MARIA ERIKSSON'), findsOneWidget);
      expect(find.textContaining('Passport'), findsOneWidget);
    });

    testWidgets('tapping a card opens its details, and remove takes it out of the wallet', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final card = WalletCard.fromDocument(_passportData(), DocumentType.passport);
      container.read(walletProvider.notifier).add(card);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: WalletList(cards: container.read(walletProvider))),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('ANNA MARIA ERIKSSON'));
      await tester.pumpAndSettle();

      expect(find.text('Document number'), findsOneWidget);

      await tester.tap(find.text('Remove from wallet'));
      await tester.pumpAndSettle();

      expect(container.read(walletProvider), isEmpty);
    });
  });
}
