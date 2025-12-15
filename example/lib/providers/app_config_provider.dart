import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for Face API URL configuration
final faceApiUrlProvider = StateProvider<String>(
  (ref) => 'https://unpremature-lona-leadenly.ngrok-free.dev',
);

/// Provider for Passport Issuer URL configuration
final issuerUrlProvider = StateProvider<String>(
  (ref) => 'https://passport-issuer.staging.yivi.app',
);
