import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vcmrtd/vcmrtd.dart';
import 'package:vcmrtdapp/widgets/common/scanned_mrz.dart';
import 'package:vcmrtdapp/widgets/pages/scan_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  // The camera plugin queries availableCameras() on init. Return an empty list
  // so MRZCameraView.initState short-circuits before touching a real device.
  const cameraChannel = MethodChannel('plugins.flutter.io/camera');

  setUp(() {
    messenger.setMockMethodCallHandler(cameraChannel, (call) async {
      if (call.method == 'availableCameras') return <Map<String, dynamic>>[];
      return null;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(cameraChannel, null);
  });

  testWidgets('ScannerPage builds the MRZ scanner scaffold for a passport', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ScannerPage(documentType: DocumentType.passport, onSuccess: (_) {}),
        ),
      ),
    );
    await tester.pump();

    // No camera available -> empty placeholder container inside a Scaffold.
    expect(find.byType(ScannerPage), findsOneWidget);
    expect(find.byType(Scaffold), findsWidgets);
  });

  testWidgets('ScannerPage builds for a driving licence document type', (tester) async {
    ScannedMRZ? received;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ScannerPage(documentType: DocumentType.drivingLicence, onSuccess: (mrz) => received = mrz),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(ScannerPage), findsOneWidget);
    // Without a camera frame, onSuccess is never invoked.
    expect(received, isNull);
  });
}
