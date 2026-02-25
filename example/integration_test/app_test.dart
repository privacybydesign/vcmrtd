import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:mrz_parser/mrz_parser.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vcmrtdapp/helpers/mrz_helper.dart';

/// Integration test for PRADO document MRZ scanning.
///
/// Run with: flutter test integration_test/app_test.dart -d <device_id>
///
/// This test loads passport and ID card images from bundled assets
/// and verifies MRZ parsing works correctly using Google ML Kit.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late TextRecognizer textRecognizer;
  late Directory tempDir;

  setUpAll(() async {
    textRecognizer = TextRecognizer();
  });

  tearDownAll(() {
    textRecognizer.close();
  });

  /// Copy asset to temp file for ML Kit processing
  Future<File> copyAssetToTemp(String assetPath, String fileName) async {
    final byteData = await rootBundle.load(assetPath);
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsBytes(byteData.buffer.asUint8List());
    return file;
  }

  /// Process an image file and extract MRZ lines using ML Kit
  Future<MrzScanResult> scanImage(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final recognizedText = await textRecognizer.processImage(inputImage);

      String fullText = recognizedText.text;
      String trimmedText = fullText.replaceAll(' ', '');
      List<String> allText = trimmedText.split('\n');

      List<String> ableToScanText = [];
      for (var line in allText) {
        final processed = MRZHelper.testTextLine(line);
        if (processed.isNotEmpty) {
          ableToScanText.add(processed);
        }
      }

      final mrzLines = MRZHelper.getFinalListToParse([...ableToScanText]);

      if (mrzLines == null || mrzLines.isEmpty) {
        return MrzScanResult(
          fileName: imageFile.path.split('/').last,
          success: false,
          rawText: fullText,
        );
      }

      return MrzScanResult(
        fileName: imageFile.path.split('/').last,
        success: true,
        mrzLines: mrzLines,
        rawText: fullText,
      );
    } catch (e) {
      return MrzScanResult(
        fileName: imageFile.path.split('/').last,
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Try to parse MRZ lines for passport
  MrzParseResult? tryParsePassportMrz(List<String> lines) {
    try {
      final result = PassportMrzParser().parse(lines);
      return MrzParseResult(
        success: true,
        surnames: result.surnames,
        givenNames: result.givenNames,
        documentNumber: result.documentNumber,
        nationality: result.nationalityCountryCode,
        birthDate: result.birthDate.toString(),
        expiryDate: result.expiryDate.toString(),
      );
    } catch (e) {
      return MrzParseResult(success: false, error: e.toString());
    }
  }

  /// Try to parse MRZ lines for ID card
  MrzParseResult? tryParseIdCardMrz(List<String> lines) {
    try {
      final result = IdCardMrzParser().parse(lines);
      return MrzParseResult(
        success: true,
        surnames: result.surnames,
        givenNames: result.givenNames,
        documentNumber: result.documentNumber,
        nationality: result.nationalityCountryCode,
        birthDate: result.birthDate.toString(),
        expiryDate: result.expiryDate.toString(),
      );
    } catch (e) {
      return MrzParseResult(success: false, error: e.toString());
    }
  }

  testWidgets('PRADO MRZ Integration Test', (tester) async {
    // Initialize Flutter binding for ML Kit and get temp directory
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    await tester.pumpAndSettle();

    tempDir = await getTemporaryDirectory();

    print('\n${'=' * 70}');
    print('PRADO MRZ INTEGRATION TEST');
    print('Temp directory: ${tempDir.path}');
    print('${'=' * 70}\n');

    // Test passport images
    final passportAssets = [
      'assets/test_images/passport/AUT-AO-01001_40337.jpg',
      'assets/test_images/passport/AUT-AO-02001_132811.jpg',
      'assets/test_images/passport/AUT-AO-02002_240610.jpg',
      'assets/test_images/passport/AUT-AO-03001_367107.jpg',
      'assets/test_images/passport/DEU-AO-01001_59680.jpg',
      'assets/test_images/passport/DEU-AO-01002_59704.jpg',
      'assets/test_images/passport/DEU-AO-01003_59752.jpg',
      'assets/test_images/passport/DEU-AO-01004_224308.jpg',
      'assets/test_images/passport/DEU-AO-01005_224400.jpg',
      'assets/test_images/passport/DEU-AO-01006_224435.jpg',
      'assets/test_images/passport/DEU-AO-01007_100191.jpg',
      'assets/test_images/passport/DEU-AO-02002_341755.jpg',
      'assets/test_images/passport/DEU-AO-04001_350185.jpg',
      'assets/test_images/passport/DEU-AO-04004_371436.jpg',
      'assets/test_images/passport/NLD-AO-01001_40381.jpg',
      'assets/test_images/passport/NLD-AO-02001_53664.jpg',
    ];

    final idcardAssets = [
      'assets/test_images/idcard/AUT-BO-02001_40133.jpg',
      'assets/test_images/idcard/AUT-BO-02002_40150.jpg',
      'assets/test_images/idcard/AUT-BO-02003_242186.jpg',
      'assets/test_images/idcard/AUT-BO-03001_341655.jpg',
      'assets/test_images/idcard/BEL-BO-03003_143221.jpg',
      'assets/test_images/idcard/BEL-BO-04001_82281.jpg',
      'assets/test_images/idcard/BEL-BO-04002_84042.jpg',
      'assets/test_images/idcard/BEL-BO-04003_97655.jpg',
      'assets/test_images/idcard/BEL-BO-05001_82298.jpg',
      'assets/test_images/idcard/BEL-BO-05002_84224.jpg',
      'assets/test_images/idcard/BEL-BO-05003_84316.jpg',
      'assets/test_images/idcard/BEL-BO-06001_80174.jpg',
      'assets/test_images/idcard/BEL-BO-06002_83504.jpg',
      'assets/test_images/idcard/BEL-BO-08001_249681.jpg',
      'assets/test_images/idcard/BEL-BO-10001_320584.jpg',
      'assets/test_images/idcard/BEL-BO-10003_374574.jpg',
      'assets/test_images/idcard/BEL-BO-11001_348184.jpg',
      'assets/test_images/idcard/BEL-BO-11004_354957.jpg',
      'assets/test_images/idcard/BEL-BO-11005_374579.jpg',
      'assets/test_images/idcard/DEU-BO-01002_62992.jpg',
      'assets/test_images/idcard/DEU-BO-01003_224376.jpg',
      'assets/test_images/idcard/DEU-BO-02001_166167.jpg',
      'assets/test_images/idcard/DEU-BO-02004_344552.jpg',
    ];

    int passportSuccess = 0;
    int passportTotal = passportAssets.length;
    int idcardSuccess = 0;
    int idcardTotal = idcardAssets.length;

    print('Testing ${passportAssets.length} passport images...\n');

    // Test passport images
    for (final assetPath in passportAssets) {
      final fileName = assetPath.split('/').last;
      try {
        final file = await copyAssetToTemp(assetPath, fileName);
        final scanResult = await scanImage(file);

        if (scanResult.success && scanResult.mrzLines != null) {
          final parseResult = tryParsePassportMrz(scanResult.mrzLines!);
          if (parseResult != null && parseResult.success) {
            passportSuccess++;
            print('OK passport/$fileName');
            print('   ${parseResult.surnames}, ${parseResult.givenNames}');
            print('   Doc: ${parseResult.documentNumber}');
          } else {
            print('-- passport/$fileName - MRZ found but parse failed');
            print('   MRZ Lines: ${scanResult.mrzLines}');
            if (parseResult?.error != null) {
              print('   Error: ${parseResult!.error}');
            }
          }
        } else {
          print('-- passport/$fileName - No MRZ detected');
          if (scanResult.rawText != null && scanResult.rawText!.isNotEmpty) {
            print('   OCR Text: ${scanResult.rawText!.replaceAll('\n', ' | ')}');
          }
        }
      } catch (e) {
        print('!! passport/$fileName - Error: $e');
      }
    }

    print('\nTesting ${idcardAssets.length} ID card images...\n');

    // Test ID card images
    for (final assetPath in idcardAssets) {
      final fileName = assetPath.split('/').last;
      try {
        final file = await copyAssetToTemp(assetPath, fileName);
        final scanResult = await scanImage(file);

        if (scanResult.success && scanResult.mrzLines != null) {
          final parseResult = tryParseIdCardMrz(scanResult.mrzLines!);
          if (parseResult != null && parseResult.success) {
            idcardSuccess++;
            print('OK idcard/$fileName');
            print('   ${parseResult.surnames}, ${parseResult.givenNames}');
            print('   Doc: ${parseResult.documentNumber}');
          } else {
            print('-- idcard/$fileName - MRZ found but parse failed');
            print('   MRZ Lines: ${scanResult.mrzLines}');
            if (parseResult?.error != null) {
              print('   Error: ${parseResult!.error}');
            }
          }
        } else {
          print('-- idcard/$fileName - No MRZ detected');
          if (scanResult.rawText != null && scanResult.rawText!.isNotEmpty) {
            print('   OCR Text: ${scanResult.rawText!.replaceAll('\n', ' | ')}');
          }
        }
      } catch (e) {
        print('!! idcard/$fileName - Error: $e');
      }
    }

    // Print summary
    print('\n${'=' * 70}');
    print('SUMMARY');
    print('${'=' * 70}');
    print('${'Document'.padRight(15)} ${'Success'.padRight(15)} ${'Total'.padRight(10)} ${'Rate'.padRight(10)}');
    print('-' * 70);

    final passportRate = passportTotal > 0
        ? (passportSuccess / passportTotal * 100).toStringAsFixed(1)
        : '0';
    final idcardRate = idcardTotal > 0
        ? (idcardSuccess / idcardTotal * 100).toStringAsFixed(1)
        : '0';

    print('${'Passport'.padRight(15)} ${'$passportSuccess'.padRight(15)} ${'$passportTotal'.padRight(10)} ${'$passportRate%'.padRight(10)}');
    print('${'ID Card'.padRight(15)} ${'$idcardSuccess'.padRight(15)} ${'$idcardTotal'.padRight(10)} ${'$idcardRate%'.padRight(10)}');
    print('-' * 70);

    final totalSuccess = passportSuccess + idcardSuccess;
    final totalTotal = passportTotal + idcardTotal;
    final totalRate = totalTotal > 0
        ? (totalSuccess / totalTotal * 100).toStringAsFixed(1)
        : '0';
    print('${'TOTAL'.padRight(15)} ${'$totalSuccess'.padRight(15)} ${'$totalTotal'.padRight(10)} ${'$totalRate%'.padRight(10)}');
    print('${'=' * 70}\n');

    // At least some images should be parseable
    expect(totalSuccess, greaterThan(0),
        reason: 'At least some documents should be successfully parsed');
  });
}

/// Result of scanning an image for MRZ
class MrzScanResult {
  final String fileName;
  final bool success;
  final List<String>? mrzLines;
  final String? rawText;
  final String? error;

  MrzScanResult({
    required this.fileName,
    required this.success,
    this.mrzLines,
    this.rawText,
    this.error,
  });
}

/// Result of parsing MRZ lines
class MrzParseResult {
  final bool success;
  final String? surnames;
  final String? givenNames;
  final String? documentNumber;
  final String? nationality;
  final String? birthDate;
  final String? expiryDate;
  final String? error;

  MrzParseResult({
    required this.success,
    this.surnames,
    this.givenNames,
    this.documentNumber,
    this.nationality,
    this.birthDate,
    this.expiryDate,
    this.error,
  });
}
