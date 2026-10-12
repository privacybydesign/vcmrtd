import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vcmrtd/vcmrtd.dart';
import 'package:idem/l10n/l10n.dart';
import 'package:idem/routing.dart';
import 'package:mrz_capture/mrz_capture.dart';
import 'package:idem/widgets/pages/scanner_wrapper.dart';

class _FakeScanner extends StatelessWidget {
  const _FakeScanner({required this.documentType, required this.onSuccess, this.picture});

  final DocumentType documentType;
  final MrzScannedWithPicture onSuccess;

  /// What the scanner reports it photographed.
  final DocumentPicture? picture;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ElevatedButton(
        onPressed: () => onSuccess(_scannedPassport(documentType), picture),
        child: Text('fake scanner ${documentType.name}'),
      ),
    );
  }
}

ScannedPassportMRZ _scannedPassport(DocumentType documentType) {
  return ScannedPassportMRZ(
    documentNumber: 'L898902C3',
    countryCode: 'UTO',
    dateOfBirth: DateTime(1990, 6, 8),
    dateOfExpiry: DateTime(2030, 12, 31),
    documentType: documentType,
  );
}

Widget _buildWrapper({
  DocumentType documentType = DocumentType.passport,
  ValueChanged<ScannedMRZ>? onMrzScanned,
  VoidCallback? onManualEntry,
  VoidCallback? onBack,
  MrzScanPicture scanPicture = MrzScanPicture.none,
  void Function(MrzScanPicture scanPicture)? onBuildScanner,
  DocumentPicture? picture,
  ValueChanged<DocumentPicture?>? onPicture,
}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: ScannerWrapper(
      documentType: documentType,
      onMrzScanned: (mrz, [scannedPicture]) {
        onMrzScanned?.call(mrz);
        onPicture?.call(scannedPicture);
      },
      onManualEntry: onManualEntry ?? () {},
      onBack: onBack ?? () {},
      scanPicture: scanPicture,
      scannerBuilder: ({required documentType, required scanPicture, required onSuccess}) {
        onBuildScanner?.call(scanPicture);
        return _FakeScanner(documentType: documentType, onSuccess: onSuccess, picture: picture);
      },
    ),
  );
}

void main() {
  group('MrzReaderRouteParams', () {
    test('toQueryParams and fromQueryParams roundtrip for passport', () {
      final params = MrzReaderRouteParams(documentType: DocumentType.passport);
      final map = params.toQueryParams();
      final recovered = MrzReaderRouteParams.fromQueryParams(map);
      expect(recovered.documentType, DocumentType.passport);
    });

    test('toQueryParams and fromQueryParams roundtrip for driving licence', () {
      final params = MrzReaderRouteParams(documentType: DocumentType.drivingLicence);
      final map = params.toQueryParams();
      final recovered = MrzReaderRouteParams.fromQueryParams(map);
      expect(recovered.documentType, DocumentType.drivingLicence);
    });

    test('toQueryParams and fromQueryParams roundtrip for identity card', () {
      final params = MrzReaderRouteParams(documentType: DocumentType.identityCard);
      final map = params.toQueryParams();
      final recovered = MrzReaderRouteParams.fromQueryParams(map);
      expect(recovered.documentType, DocumentType.identityCard);
    });

    test('toQueryParams produces a document_type key', () {
      final params = MrzReaderRouteParams(documentType: DocumentType.passport);
      expect(params.toQueryParams(), contains('document_type'));
    });
  });

  group('ScannerWrapper', () {
    testWidgets('renders the step badge and document-specific manual entry copy', (tester) async {
      await tester.pumpWidget(_buildWrapper(documentType: DocumentType.drivingLicence));

      expect(find.text('1 of 4 · Scan driving licence'), findsOneWidget);
      expect(find.text('Position the driving licence'), findsOneWidget);
      expect(find.text('Enter driving licence details manually'), findsOneWidget);
      expect(find.text('fake scanner ${DocumentType.drivingLicence.name}'), findsOneWidget);
    });

    testWidgets('invokes back and manual-entry callbacks', (tester) async {
      var backCount = 0;
      var manualCount = 0;
      await tester.pumpWidget(_buildWrapper(onBack: () => backCount++, onManualEntry: () => manualCount++));

      await tester.tap(find.byType(IconButton));
      await tester.pump();
      await tester.tap(find.text('Enter passport details manually'));
      await tester.pump();

      expect(backCount, 1);
      expect(manualCount, 1);
    });

    testWidgets('asks the scanner for no picture by default, and says to align the MRZ', (tester) async {
      final asked = <MrzScanPicture>[];
      await tester.pumpWidget(_buildWrapper(onBuildScanner: asked.add));

      expect(asked.last, MrzScanPicture.none);
      expect(find.textContaining('Align the Machine Readable Zone'), findsOneWidget);
    });

    testWidgets('a capture asks the scanner for a picture, says the side is photographed too, and forwards the '
        'picture with the scan', (tester) async {
      final asked = <MrzScanPicture>[];
      final pictures = <DocumentPicture?>[];
      final picture = DocumentPicture(
        jpeg: Uint8List.fromList([1, 2, 3]),
        frame: const Rect.fromLTRB(0, 0, 1, 1),
        previewAspectRatio: 9 / 16,
      );
      await tester.pumpWidget(
        _buildWrapper(
          scanPicture: MrzScanPicture.capture,
          onBuildScanner: asked.add,
          picture: picture,
          onPicture: pictures.add,
        ),
      );

      expect(asked.last, MrzScanPicture.capture);
      expect(find.textContaining('this side is photographed too'), findsOneWidget);

      await tester.tap(find.text('fake scanner ${DocumentType.passport.name}'));
      await tester.pump();
      expect(pictures.single, same(picture));
    });

    testWidgets('forwards the first scan result and ignores duplicate success events', (tester) async {
      final scanned = <ScannedMRZ>[];
      await tester.pumpWidget(_buildWrapper(documentType: DocumentType.identityCard, onMrzScanned: scanned.add));

      await tester.tap(find.text('fake scanner ${DocumentType.identityCard.name}'));
      await tester.pump();
      await tester.tap(find.text('fake scanner ${DocumentType.identityCard.name}'));
      await tester.pump();

      expect(scanned, hasLength(1));
      expect(scanned.single.documentType, DocumentType.identityCard);
      expect(scanned.single.documentNumber, 'L898902C3');
    });

    testWidgets('allows another scan after returning from a pushed route', (tester) async {
      final scanned = <ScannedMRZ>[];
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          navigatorObservers: [routeObserver],
          home: ScannerWrapper(
            documentType: DocumentType.passport,
            onMrzScanned: (mrz, [_]) => scanned.add(mrz),
            onManualEntry: () {},
            onBack: () {},
            scannerBuilder: ({required documentType, required scanPicture, required onSuccess}) {
              return _FakeScanner(documentType: documentType, onSuccess: onSuccess);
            },
          ),
        ),
      );

      await tester.tap(find.text('fake scanner ${DocumentType.passport.name}'));
      await tester.pump();
      await tester.tap(find.text('fake scanner ${DocumentType.passport.name}'));
      await tester.pump();
      expect(scanned, hasLength(1));

      final pushFuture = Navigator.of(
        tester.element(find.byType(ScannerWrapper)),
      ).push<void>(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('details'))));
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.text('details'))).pop();
      await tester.pumpAndSettle();
      await pushFuture;

      await tester.tap(find.text('fake scanner ${DocumentType.passport.name}'));
      await tester.pump();

      expect(scanned, hasLength(2));
    });
  });
}
