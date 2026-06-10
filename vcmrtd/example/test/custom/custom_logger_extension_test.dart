import 'package:flutter_test/flutter_test.dart';
import 'package:vcmrtdapp/custom/custom_logger_extension.dart';

void main() {
  group('LoggerExtension', () {
    // These are fire-and-forget logging calls; the assertion is that they
    // execute every branch without throwing.
    test('logInfo runs with and without stack', () {
      expect(() => 'info'.logInfo(), returnsNormally);
      expect(() => 'info'.logInfo(noStack: false), returnsNormally);
    });

    test('logWarning runs with and without stack', () {
      expect(() => 'warn'.logWarning(), returnsNormally);
      expect(() => 'warn'.logWarning(noStack: false), returnsNormally);
    });

    test('logError runs with and without stack', () {
      expect(() => 'error'.logError(), returnsNormally);
      expect(() => 'error'.logError(noStack: false), returnsNormally);
    });

    test('logSuccess runs with and without stack', () {
      expect(() => 'success'.logSuccess(), returnsNormally);
      expect(() => 'success'.logSuccess(noStack: false), returnsNormally);
    });

    test('logDebug runs with and without stack', () {
      expect(() => 'debug'.logDebug(), returnsNormally);
      expect(() => 'debug'.logDebug(noStack: false), returnsNormally);
    });
  });
}
