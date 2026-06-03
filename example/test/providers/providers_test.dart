import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vcmrtdapp/providers/ocr_engine_provider.dart';
import 'package:vcmrtdapp/providers/passport_issuer_provider.dart';

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

  group('passportUrlProvider', () {
    test('returns yivi passport issuer URL', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final url = container.read(passportUrlProvider);
      expect(url, contains('yivi'));
      expect(url, startsWith('https://'));
    });
  });

  group('passportIssuerProvider', () {
    test('creates a DefaultPassportIssuer without throwing', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(() => container.read(passportIssuerProvider), returnsNormally);
    });
  });
}
