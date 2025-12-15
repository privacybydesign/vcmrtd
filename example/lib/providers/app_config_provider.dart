import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for Face API URL configuration
final faceApiUrlProvider = StateProvider<String>(
  (ref) => 'http://192.168.2.8:41101',
);

/// Provider for Passport Issuer URL configuration
final issuerUrlProvider = StateProvider<String>(
  (ref) => 'http://192.168.2.8:8080',
);
