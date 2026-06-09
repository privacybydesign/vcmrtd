import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vcmrtd/vcmrtd.dart';
import 'package:vcmrtdapp/routing.dart';
import 'package:vcmrtdapp/widgets/common/scanned_mrz.dart';
import 'package:vcmrtdapp/widgets/pages/scanner_wrapper.dart';

class _FakeScanner extends StatelessWidget {
  const _FakeScanner({required this.documentType, required this.onSuccess});

  final DocumentType documentType;
  final ValueChanged<ScannedMRZ> onSuccess;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ElevatedButton(
        onPressed: () => onSuccess(_scannedPassport(documentType)),
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
}) {
  return MaterialApp(
    home: ScannerWrapper(
      documentType: documentType,
      onMrzScanned: onMrzScanned ?? (_) {},
      onManualEntry: onManualEntry ?? () {},
      onCancel: () {},
      onBack: onBack ?? () {},
      scannerBuilder: ({required documentType, required onSuccess}) {
        return _FakeScanner(documentType: documentType, onSuccess: onSuccess);
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
    testWidgets('renders document-specific title and manual entry copy', (tester) async {
      await tester.pumpWidget(_buildWrapper(documentType: DocumentType.drivingLicence));

      expect(find.text('Scan ${DocumentType.drivingLicence.displayName}'), findsOneWidget);
      expect(find.text('Position the ${DocumentType.drivingLicence.displayName}'), findsOneWidget);
      expect(find.text('Enter ${DocumentType.drivingLicence.displayName} details manually'), findsOneWidget);
      expect(find.text('fake scanner ${DocumentType.drivingLicence.name}'), findsOneWidget);
    });

    testWidgets('invokes back and manual-entry callbacks', (tester) async {
      var backCount = 0;
      var manualCount = 0;
      await tester.pumpWidget(_buildWrapper(onBack: () => backCount++, onManualEntry: () => manualCount++));

      await tester.tap(find.byType(IconButton));
      await tester.pump();
      await tester.tap(find.text('Enter ${DocumentType.passport.displayName} details manually'));
      await tester.pump();

      expect(backCount, 1);
      expect(manualCount, 1);
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
          navigatorObservers: [routeObserver],
          home: ScannerWrapper(
            documentType: DocumentType.passport,
            onMrzScanned: scanned.add,
            onManualEntry: () {},
            onCancel: () {},
            onBack: () {},
            scannerBuilder: ({required documentType, required onSuccess}) {
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
