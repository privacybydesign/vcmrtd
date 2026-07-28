import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vcmrtd/vcmrtd.dart';
import 'package:mrz_capture/mrz_capture.dart';

// Helper to build an MRZScannerState for testing the parsing logic.
// We wrap in a real widget tree because the state does the parsing.
MRZScannerState _buildState(WidgetTester tester) {
  return tester.state<MRZScannerState>(find.byType(MRZScanner));
}

Widget _scaffold({
  required DocumentType documentType,
  MrzScannedCallback? onSuccess,
  bool showOverlay = true,
  OcrEngine engine = OcrEngine.googleMlKit,
  CameraLensDirection initialDirection = CameraLensDirection.back,
  Future<List<String>?> Function(OcrFrame frame)? googleMlKitOcrForTesting,
}) {
  return MaterialApp(
    home: Scaffold(
      body: MRZScanner(
        documentType: documentType,
        engine: engine,
        initialDirection: initialDirection,
        showOverlay: showOverlay,
        initializeCamera: false,
        googleMlKitOcrForTesting: googleMlKitOcrForTesting,
        onSuccess: onSuccess ?? (result, lines) {},
      ),
    ),
  );
}

OcrFrame _frame() {
  return OcrFrame(
    bytes: Uint8List.fromList([1, 2, 3, 4]),
    width: 2,
    height: 2,
    bytesPerRow: 2,
    rotation: 90,
    roiLeft: 0.1,
    roiTop: 0.2,
    roiWidth: 0.7,
    roiHeight: 0.3,
    isNv21: true,
  );
}

const _passportLine1 = 'P<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<';
const _passportLine2 = 'L898902C36UTO7408122F1204159ZE184226B<<<<<10';
const _idLine1 = 'I<UTOD231458907<<<<<<<<<<<<<<<';
const _idLine2 = '7408122F1204159UTO<<<<<<<<<<<6';
const _idLine3 = 'ERIKSSON<<ANNA<MARIA<<<<<<<<<<';
const _driverLine = 'D1NLD11234567890ABCDEFGHIJKLM5';
const _tesseractChannel = MethodChannel('tesseract_ocr');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_tesseractChannel, null);
  });

  group('MRZScanner widget wiring', () {
    testWidgets('builds a camera view with scanner settings and selected OCR engine', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MRZScanner(
            documentType: DocumentType.identityCard,
            engine: OcrEngine.googleMlKit,
            initialDirection: CameraLensDirection.front,
            showOverlay: false,
            initializeCamera: false,
            onSuccess: (result, lines) {},
          ),
        ),
      );
      await tester.pump();

      final view = tester.widget<MRZCameraView>(find.byType(MRZCameraView));
      expect(view.showOverlay, isFalse);
      expect(view.initialDirection, CameraLensDirection.front);
      expect(view.initializeCamera, isFalse);
    });

    testWidgets('didPopNext re-enables processing after a successful scan', (tester) async {
      await tester.pumpWidget(_scaffold(documentType: DocumentType.passport));
      await tester.pump();
      final state = _buildState(tester);

      expect(state.debugTryParseAndNotify([_passportLine1, _passportLine2]), isTrue);
      expect(state.debugCanProcess, isFalse);

      state.didPopNext();

      expect(state.debugCanProcess, isTrue);
      expect(state.debugIsBusy, isFalse);
    });
  });

  group('MRZScannerState._parseScannedText', () {
    testWidgets('returns null for empty lines', (tester) async {
      await tester.pumpWidget(_scaffold(documentType: DocumentType.passport));
      await tester.pump();
      final state = _buildState(tester);
      expect(state.debugParseScannedText([]), isNull);
    });

    testWidgets('returns null for invalid passport MRZ lines', (tester) async {
      await tester.pumpWidget(_scaffold(documentType: DocumentType.passport));
      await tester.pump();
      final state = _buildState(tester);
      expect(state.debugParseScannedText(['INVALID_LINE']), isNull);
    });

    testWidgets('returns non-null for valid passport MRZ lines', (tester) async {
      await tester.pumpWidget(_scaffold(documentType: DocumentType.passport));
      await tester.pump();
      final state = _buildState(tester);
      final result = state.debugParseScannedText([_passportLine1, _passportLine2]);
      expect(result, isNotNull);
    });

    testWidgets('returns non-null for valid identity card MRZ lines', (tester) async {
      await tester.pumpWidget(_scaffold(documentType: DocumentType.identityCard));
      await tester.pump();
      final state = _buildState(tester);

      final result = state.debugParseScannedText([_idLine1, _idLine2, _idLine3]);

      expect(result, isNotNull);
    });

    testWidgets('returns non-null for valid driving licence MRZ line', (tester) async {
      await tester.pumpWidget(_scaffold(documentType: DocumentType.drivingLicence));
      await tester.pump();
      final state = _buildState(tester);

      final result = state.debugParseScannedText([_driverLine]);

      expect(result, isNotNull);
    });

    testWidgets('returns null for wrong document type lines', (tester) async {
      await tester.pumpWidget(_scaffold(documentType: DocumentType.passport));
      await tester.pump();
      final state = _buildState(tester);
      // These are garbage lines for a passport parser.
      expect(state.debugParseScannedText(['AAAAAA', 'BBBBBB']), isNull);
    });
  });

  group('MRZScannerState._tryParseAndNotify', () {
    testWidgets('returns false for invalid lines', (tester) async {
      await tester.pumpWidget(_scaffold(documentType: DocumentType.passport));
      await tester.pump();
      final state = _buildState(tester);
      expect(state.debugTryParseAndNotify(['NOT_VALID']), isFalse);
      expect(state.debugCanProcess, isTrue);
    });

    testWidgets('returns true and calls onSuccess for valid passport lines', (tester) async {
      ScannedMRZ? captured;
      List<String>? capturedLines;
      await tester.pumpWidget(
        _scaffold(
          documentType: DocumentType.passport,
          onSuccess: (result, lines) {
            captured = result;
            capturedLines = lines;
          },
        ),
      );
      await tester.pump();
      final state = _buildState(tester);
      final ok = state.debugTryParseAndNotify([_passportLine1, _passportLine2]);
      expect(ok, isTrue);
      expect(captured, isNotNull);
      expect(capturedLines, [_passportLine1, _passportLine2]);
      expect(state.debugCanProcess, isFalse);
    });

    testWidgets('uses strict correction fallback before notifying success', (tester) async {
      List<String>? capturedLines;
      await tester.pumpWidget(
        _scaffold(documentType: DocumentType.passport, onSuccess: (_, lines) => capturedLines = lines),
      );
      await tester.pump();
      final state = _buildState(tester);
      const ocrLine1 = _passportLine1;
      const ocrLine2 = 'L898902C3GUTO7408122F1204159ZE184226B<<<<<10';

      final ok = state.debugTryParseAndNotify([ocrLine1, ocrLine2]);

      expect(ok, isTrue);
      expect(capturedLines, isNotNull);
      expect(capturedLines, [_passportLine1, _passportLine2]);
    });

    testWidgets('does not notify twice after a successful parse disables processing', (tester) async {
      var count = 0;
      await tester.pumpWidget(_scaffold(documentType: DocumentType.passport, onSuccess: (result, lines) => count++));
      await tester.pump();
      final state = _buildState(tester);

      expect(state.debugTryParseAndNotify([_passportLine1, _passportLine2]), isTrue);
      await state.debugProcessTesseractFrame(_frame());

      expect(count, 1);
      expect(state.debugCanProcess, isFalse);
    });
  });

  group('MRZScannerState._processFrame', () {
    testWidgets('does nothing when processing has already been disabled', (tester) async {
      var called = false;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_tesseractChannel, (
        _,
      ) async {
        called = true;
        return '$_passportLine1\n$_passportLine2';
      });

      await tester.pumpWidget(_scaffold(documentType: DocumentType.passport, onSuccess: (unused1, unused2) {}));
      await tester.pump();

      final state = _buildState(tester);

      expect(state.debugTryParseAndNotify([_passportLine1, _passportLine2]), isTrue);
      expect(state.debugCanProcess, isFalse);

      await state.debugProcessFrame(_frame(), OcrEngine.tesseract4android);

      expect(called, isFalse);
      expect(state.debugCanProcess, isFalse);
      expect(state.debugIsBusy, isFalse);
    });

    testWidgets('google ML Kit path uses injected OCR lines and clears busy flag', (tester) async {
      List<String>? capturedLines;
      await tester.pumpWidget(
        _scaffold(
          documentType: DocumentType.passport,
          onSuccess: (_, lines) => capturedLines = lines,
          googleMlKitOcrForTesting: (_) async => <String>[_passportLine1, _passportLine2],
        ),
      );
      await tester.pump();
      final state = _buildState(tester);

      await state.debugProcessFrame(_frame(), OcrEngine.googleMlKit);

      expect(capturedLines, <String>[_passportLine1, _passportLine2]);
      expect(state.debugCanProcess, isFalse);
      expect(state.debugIsBusy, isFalse);
    });

    // _scaffold passes no routeObserver, so didPopNext never fires here. Without
    // resumeScanning() this scanner would stay dead after the first hit.
    testWidgets('resumeScanning re-arms the frame path with no route observer', (tester) async {
      var hits = 0;
      await tester.pumpWidget(
        _scaffold(
          documentType: DocumentType.passport,
          onSuccess: (_, unused) => hits++,
          googleMlKitOcrForTesting: (_) async => <String>[_passportLine1, _passportLine2],
        ),
      );
      await tester.pump();
      final state = _buildState(tester);

      await state.debugProcessFrame(_frame(), OcrEngine.googleMlKit);
      expect(hits, 1);
      expect(state.debugCanProcess, isFalse);

      await state.debugProcessFrame(_frame(), OcrEngine.googleMlKit);
      expect(hits, 1, reason: 'a second read must not be reported before the scanner is re-armed');

      state.resumeScanning();

      expect(state.debugCanProcess, isTrue);
      expect(state.debugIsBusy, isFalse);

      await state.debugProcessFrame(_frame(), OcrEngine.googleMlKit);
      expect(hits, 2);
    });
  });

  group('MRZScannerState._processTesseractFrame', () {
    testWidgets('sends frame metadata to channel and parses valid OCR text', (tester) async {
      MethodCall? capturedCall;
      ScannedMRZ? capturedResult;
      List<String>? capturedLines;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_tesseractChannel, (
        call,
      ) async {
        capturedCall = call;
        return '$_passportLine1\r\n\r\n$_passportLine2';
      });
      await tester.pumpWidget(
        _scaffold(
          documentType: DocumentType.passport,
          onSuccess: (result, lines) {
            capturedResult = result;
            capturedLines = lines;
          },
        ),
      );
      await tester.pump();
      final state = _buildState(tester);

      await state.debugProcessTesseractFrame(_frame());

      expect(capturedCall, isNotNull);
      expect(capturedCall!.method, 'processImage');
      final args = Map<Object?, Object?>.from(capturedCall!.arguments as Map);
      expect(args['bytes'], orderedEquals([1, 2, 3, 4]));
      expect(args['width'], 2);
      expect(args['height'], 2);
      expect(args['stride'], 2);
      expect(args['rotation'], 90);
      expect(args['lang'], 'ocrb');
      expect(args['roiLeft'], 0.1);
      expect(args['roiTop'], 0.2);
      expect(args['roiWidth'], 0.7);
      expect(args['roiHeight'], 0.3);
      expect(capturedResult, isNotNull);
      expect(capturedLines, [_passportLine1, _passportLine2]);
      expect(state.debugCanProcess, isFalse);
    });

    testWidgets('normalizes lowercase and spaced OCR text from channel', (tester) async {
      List<String>? capturedLines;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        _tesseractChannel,
        (_) async => '${_passportLine1.toLowerCase()}\n${_passportLine2.replaceAll('<', ' < ')}',
      );
      await tester.pumpWidget(
        _scaffold(documentType: DocumentType.passport, onSuccess: (_, lines) => capturedLines = lines),
      );
      await tester.pump();

      await _buildState(tester).debugProcessTesseractFrame(_frame());

      expect(capturedLines, [_passportLine1, _passportLine2]);
    });

    testWidgets('ignores empty OCR text', (tester) async {
      var called = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        _tesseractChannel,
        (_) async => '  \n  ',
      );
      await tester.pumpWidget(
        _scaffold(documentType: DocumentType.passport, onSuccess: (result, lines) => called = true),
      );
      await tester.pump();

      await _buildState(tester).debugProcessTesseractFrame(_frame());

      expect(called, isFalse);
    });

    testWidgets('ignores invalid OCR text after normalization', (tester) async {
      var called = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        _tesseractChannel,
        (_) async => 'invalid\ntext',
      );
      await tester.pumpWidget(
        _scaffold(documentType: DocumentType.passport, onSuccess: (result, lines) => called = true),
      );
      await tester.pump();

      await _buildState(tester).debugProcessTesseractFrame(_frame());

      expect(called, isFalse);
    });

    testWidgets('swallows channel exceptions and leaves processing enabled', (tester) async {
      var called = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        _tesseractChannel,
        (_) async => throw PlatformException(code: 'ocr-failed'),
      );
      await tester.pumpWidget(
        _scaffold(documentType: DocumentType.passport, onSuccess: (result, lines) => called = true),
      );
      await tester.pump();
      final state = _buildState(tester);

      await state.debugProcessTesseractFrame(_frame());

      expect(called, isFalse);
      expect(state.debugCanProcess, isTrue);
    });
  });
  group('MRZScannerState result mapping', () {
    testWidgets('a passport scan reports a ScannedPassportMRZ', (tester) async {
      ScannedMRZ? captured;
      await tester.pumpWidget(_scaffold(documentType: DocumentType.passport, onSuccess: (mrz, _) => captured = mrz));
      await tester.pump();

      expect(_buildState(tester).debugTryParseAndNotify([_passportLine1, _passportLine2]), isTrue);

      final passport = captured as ScannedPassportMRZ;
      expect(passport.documentType, DocumentType.passport);
      expect(passport.documentNumber, 'L898902C3');
      expect(passport.countryCode, 'UTO');
      expect(passport.dateOfBirth, DateTime(1974, 8, 12));
      expect(passport.dateOfExpiry, DateTime(2012, 4, 15));
    });

    testWidgets('an identity card scan reports a ScannedPassportMRZ carrying the card type', (tester) async {
      ScannedMRZ? captured;
      await tester.pumpWidget(
        _scaffold(documentType: DocumentType.identityCard, onSuccess: (mrz, _) => captured = mrz),
      );
      await tester.pump();

      expect(_buildState(tester).debugTryParseAndNotify([_idLine1, _idLine2, _idLine3]), isTrue);

      final card = captured as ScannedPassportMRZ;
      expect(card.documentType, DocumentType.identityCard);
      expect(card.documentNumber, 'D23145890');
    });

    testWidgets('a driving licence scan reports a ScannedDriverLicenseMRZ', (tester) async {
      ScannedMRZ? captured;
      await tester.pumpWidget(
        _scaffold(documentType: DocumentType.drivingLicence, onSuccess: (mrz, _) => captured = mrz),
      );
      await tester.pump();

      expect(_buildState(tester).debugTryParseAndNotify([_driverLine]), isTrue);

      final licence = captured as ScannedDriverLicenseMRZ;
      expect(licence.documentType, DocumentType.drivingLicence);
      expect(licence.countryCode, 'NLD');
    });
  });

  group('MRZScanner engine selection', () {
    testWidgets('the camera view feeds frames into the engine the caller passed', (tester) async {
      OcrFrame? seenFrame;
      List<String>? capturedLines;
      await tester.pumpWidget(
        _scaffold(
          documentType: DocumentType.passport,
          engine: OcrEngine.googleMlKit,
          onSuccess: (_, lines) => capturedLines = lines,
          googleMlKitOcrForTesting: (frame) async {
            seenFrame = frame;
            return <String>[_passportLine1, _passportLine2];
          },
        ),
      );
      await tester.pump();

      // Deliver a frame the way MRZCameraView does, rather than calling the
      // processing entry point directly, so the wiring is covered too.
      await tester.widget<MRZCameraView>(find.byType(MRZCameraView)).onImage(_frame());

      expect(seenFrame, isNotNull);
      expect(capturedLines, <String>[_passportLine1, _passportLine2]);
    });

    testWidgets('rebuilding with another engine hands the new engine to the next frame', (tester) async {
      await tester.pumpWidget(_scaffold(documentType: DocumentType.passport, engine: OcrEngine.googleMlKit));
      await tester.pump();
      expect(tester.widget<MRZScanner>(find.byType(MRZScanner)).engine, OcrEngine.googleMlKit);

      await tester.pumpWidget(_scaffold(documentType: DocumentType.passport, engine: OcrEngine.tesseract4android));
      await tester.pump();

      expect(tester.widget<MRZScanner>(find.byType(MRZScanner)).engine, OcrEngine.tesseract4android);
      expect(_buildState(tester).debugCanProcess, isTrue);
    });
  });
}
