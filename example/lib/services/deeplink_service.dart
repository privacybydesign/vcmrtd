import 'dart:async';
import 'package:flutter/services.dart';

class DeepLinkData {
  final Uri uri;
  final String sessionId;
  final String nonce;

  DeepLinkData(this.uri, this.sessionId, this.nonce);

  @override
  String toString() =>
      'DeepLinkData(sessionId=$sessionId, nonce=$nonce, uri=$uri)';
}

class DeepLinkService {
  static const _channel = MethodChannel('deep_link_handler');
  static const _methodGetInitial = 'getInitialLink';
  static const _methodHandle = 'handleDeepLink';

  final _controller = StreamController<DeepLinkData>.broadcast();
  Stream<DeepLinkData> get stream => _controller.stream;

  Future<void> init() async {
    // 1) Handle initial link (app launched by deep link)
    try {
      final initial = await _channel.invokeMethod<String>(_methodGetInitial);
      if (initial != null) {
        final data = _parse(initial);
        if (data != null) _controller.add(data);
      }
    } catch (e) {
      // swallow or log
    }

    // 2) Handle subsequent links (while app is running)
    _channel.setMethodCallHandler((call) async {
      if (call.method == _methodHandle) {
        final url = call.arguments as String?;
        if (url != null) {
          final data = _parse(url);
          if (data != null) _controller.add(data);
        }
      }
    });
  }

  DeepLinkData? _parse(String url) {
    try {
      final uri = Uri.parse(url);

      // (Your Android plugin already restricts to this host/path)
      if (uri.scheme != 'https' ||
          uri.host != 'passport-issuer.staging.yivi.app' ||
          !uri.path.startsWith('/start-app')) {
        return null;
      }

      final sessionId = uri.queryParameters['sessionId'];
      final nonce = uri.queryParameters['nonce'];
      if (sessionId == null || sessionId.isEmpty) return null;
      if (nonce == null || nonce.isEmpty) return null;

      return DeepLinkData(uri, sessionId, nonce);
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    _controller.close();
  }
}
