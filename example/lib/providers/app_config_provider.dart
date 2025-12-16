import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for Face API URL configuration
final faceApiUrlProvider = StateProvider<String>(
  (ref) => 'https://faceapi.staging.yivi.app',
);

/// Provider for Passport Issuer URL configuration
final issuerUrlProvider = StateProvider<String>(
  (ref) => 'https://passport-issuer.staging.yivi.app',
);
