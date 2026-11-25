import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mrz_capture/mrz_capture.dart';
import 'package:idem/providers/ocr_engine_provider.dart';

void main() {
  group('OcrEngineNotifier', () {
    test('defaults to googleMlKit', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(ocrEngineProvider), OcrEngine.googleMlKit);
    });

    test('set changes state to the given engine', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(ocrEngineProvider.notifier).set(OcrEngine.tesseract4android);
      expect(container.read(ocrEngineProvider), OcrEngine.tesseract4android);
    });

    test('set back to googleMlKit after switching', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(ocrEngineProvider.notifier).set(OcrEngine.tesseract4android);
      container.read(ocrEngineProvider.notifier).set(OcrEngine.googleMlKit);
      expect(container.read(ocrEngineProvider), OcrEngine.googleMlKit);
    });
  });
}
