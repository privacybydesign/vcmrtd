import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idem/l10n/l10n.dart';
import 'package:image/image.dart' as img;
import 'package:vcmrtd/vcmrtd.dart';
import 'package:idem/widgets/pages/nfc_guidance_screen.dart';
import 'package:idem/widgets/pages/data_screen_widgets/profile_picture.dart';

void main() {
  group('NfcGuidanceScreen', () {
    testWidgets('renders scaffold for passport document type', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: NfcGuidanceScreen(onStartReading: () {}, onBack: () {}, documentType: DocumentType.passport),
        ),
      );
      await tester.pump();
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('renders scaffold for driving licence document type', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: NfcGuidanceScreen(onStartReading: () {}, onBack: () {}, documentType: DocumentType.drivingLicence),
        ),
      );
      await tester.pump();
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('onBack callback fires when back button tapped', (tester) async {
      var called = false;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: NfcGuidanceScreen(
            onStartReading: () {},
            onBack: () => called = true,
            documentType: DocumentType.passport,
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byType(IconButton).first);
      expect(called, isTrue);
    });
  });

  group('ProfilePictureWidget', () {
    testWidgets('renders JPEG photo data with Image.memory', (tester) async {
      final image = img.Image(width: 2, height: 2);
      final jpeg = Uint8List.fromList(img.encodeJpg(image));

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ProfilePictureWidget(imageData: jpeg, imageType: ImageType.jpeg),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(Image), findsOneWidget);
      expect(find.byIcon(Icons.person), findsNothing);
      expect(find.text('No Photo'), findsNothing);
    });
  });
}
