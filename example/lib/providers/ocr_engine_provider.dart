import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which OCR engine to use for MRZ scanning.
///
/// [tesseract4android] is only available on Android.
/// On iOS the only valid engine is [googleMlKit].
enum OcrEngine { googleMlKit, tesseract4android }

/// All engines supported on the current platform.
/// Drive the dropdown from this — only show what is actually available.
final availableEnginesProvider = Provider<List<OcrEngine>>((ref) {
  if (Platform.isAndroid) {
    return const [OcrEngine.googleMlKit, OcrEngine.tesseract4android];
  }
  return const [OcrEngine.googleMlKit];
});

class OcrEngineNotifier extends Notifier<OcrEngine> {
  @override
  OcrEngine build() => OcrEngine.googleMlKit;

  void set(OcrEngine engine) {
    // Single guard: reject anything not available on this platform.
    if (!ref.read(availableEnginesProvider).contains(engine)) return;
    state = engine;
  }
}

final ocrEngineProvider = NotifierProvider<OcrEngineNotifier, OcrEngine>(
  OcrEngineNotifier.new,
);