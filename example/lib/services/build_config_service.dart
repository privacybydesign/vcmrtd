import 'dart:io';
import 'package:flutter/services.dart';

class BuildConfigService {
  static const MethodChannel _channel = MethodChannel('build_config');

  /// Returns true if MLKit scanner is available (playstore build)
  /// Returns false for FDroid builds where MLKit is excluded
  static Future<bool> isScannerAvailable() async {
    // iOS always has scanner available (no FDroid on iOS)
    if (Platform.isIOS) {
      return true;
    }

    // Android: check build flavor
    if (Platform.isAndroid) {
      try {
        final String? flavor = await _channel.invokeMethod('getFlavor');
        // Scanner is available for playstore builds, not for fdroid
        return flavor == 'playstore';
      } catch (e) {
        // If method channel fails, assume scanner is available (safer default)
        print('Error getting build flavor: $e');
        return true;
      }
    }

    // Default for other platforms
    return false;
  }
}
