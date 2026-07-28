import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mrz_capture/mrz_capture.dart';

class OcrEngineNotifier extends Notifier<OcrEngine> {
  @override
  OcrEngine build() => OcrEngine.googleMlKit;

  void set(OcrEngine engine) => state = engine;
}

final ocrEngineProvider = NotifierProvider<OcrEngineNotifier, OcrEngine>(OcrEngineNotifier.new);
