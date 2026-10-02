import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vcmrtd/vcmrtd.dart';
import 'package:mrz_capture/mrz_capture.dart';

Widget _screen(DocumentType documentType, Locale locale) => MaterialApp(
  locale: locale,
  supportedLocales: MrzCaptureLocalizations.supportedLocales,
  localizationsDelegates: const [
    MrzCaptureLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: ManualEntryScreen(documentType: documentType, onBack: () {}, onManualEntryComplete: (_) {}),
);

void main() {
  testWidgets('renders in Dutch when the host app is in Dutch', (tester) async {
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_screen(DocumentType.passport, const Locale('nl')));
    await tester.pump();

    expect(find.text('1 of 4 · Paspoortgegevens invoeren'), findsOneWidget);
    expect(find.text('Geboortedatum'), findsOneWidget);
    expect(find.text('Vul je paspoortgegevens in'), findsOneWidget);
    expect(find.text('Door naar het uitlezen via NFC'), findsOneWidget);
  });

  testWidgets('shows help for the document type being entered', (tester) async {
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_screen(DocumentType.identityCard, const Locale('en')));
    await tester.pump();
    expect(find.textContaining('Identity Card Number: On the front of the card'), findsOneWidget);
    expect(find.textContaining('Passport Number'), findsNothing);

    await tester.pumpWidget(_screen(DocumentType.drivingLicence, const Locale('en')));
    await tester.pump();
    // The prefixes the validator accepts.
    expect(find.textContaining('"D1", "D2", or "DL"'), findsOneWidget);
  });

  testWidgets('falls back to English without the delegate', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ManualEntryScreen(documentType: DocumentType.passport, onBack: () {}, onManualEntryComplete: (_) {}),
      ),
    );
    await tester.pump();
    expect(find.text('Date of Birth'), findsOneWidget);
  });
}
