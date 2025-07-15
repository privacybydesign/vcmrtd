import 'package:logger/logger.dart';

// Define the logger instances
final Logger _logger = Logger(printer: PrettyPrinter());
final Logger _loggerNoStack = Logger(printer: PrettyPrinter(methodCount: 0));

extension LoggerExtension on String {
  void logInfo({bool noStack = true}) {
    if (noStack) {
      _loggerNoStack.i(this);
    } else {
      _logger.i(this);
    }
  }

  void logWarning({bool noStack = true}) {
    if (noStack) {
      _loggerNoStack.w(this);
    } else {
      _logger.w(this);
    }
  }

  void logError({bool noStack = true}) {
    if (noStack) {
      _loggerNoStack.e(this);
    } else {
      _logger.e(this);
    }
  }

  void logSuccess({bool noStack = true}) {
    if (noStack) {
      _loggerNoStack.d(this);
    } else {
      _logger.d(this);
    }
  }

  void logDebug({bool noStack = true}) {
    if (noStack) {
      _loggerNoStack.d(this);
    } else {
      _logger.d(this);
    }
  }
}
