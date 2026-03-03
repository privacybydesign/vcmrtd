import 'package:flutter_riverpod/flutter_riverpod.dart';

enum OcrEngine {
  googleMlKit,
  tesseract4android,
}

class OcrEngineNotifier extends Notifier<OcrEngine> {
  @override
  OcrEngine build() => OcrEngine.googleMlKit;

  void set(OcrEngine engine) => state = engine;
}

final ocrEngineProvider = NotifierProvider<OcrEngineNotifier, OcrEngine>(
  OcrEngineNotifier.new,
);
