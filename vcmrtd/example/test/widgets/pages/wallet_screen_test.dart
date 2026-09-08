import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:vcmrtd/vcmrtd.dart';
import 'package:vcmrtdapp/providers/wallet_provider.dart';
import 'package:vcmrtdapp/widgets/pages/wallet_screen.dart';

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
  group('WalletScreen', () {
    testWidgets('shows an empty state with no cards', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(home: WalletScreen(onBackPressed: () {})),
        ),
      );
      await tester.pump();

      expect(find.text('Your wallet is empty'), findsOneWidget);
    });

    testWidgets('lists an added card and removes it on tap', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final card = WalletCard.fromDocument(_passportData(), DocumentType.passport);
      container.read(walletProvider.notifier).add(card);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: WalletScreen(onBackPressed: () {})),
        ),
      );
      await tester.pump();

      expect(find.text('ANNA MARIA ERIKSSON'), findsOneWidget);
      expect(find.textContaining('Passport'), findsOneWidget);

      await tester.tap(find.byTooltip('Remove'));
      await tester.pump();

      expect(container.read(walletProvider), isEmpty);
      expect(find.text('Your wallet is empty'), findsOneWidget);
    });

    testWidgets('back button calls onBackPressed', (tester) async {
      var pressed = false;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(home: WalletScreen(onBackPressed: () => pressed = true)),
        ),
      );
      await tester.pump();

      await tester.tap(find.byTooltip('Back'));
      expect(pressed, isTrue);
    });
  });
}
