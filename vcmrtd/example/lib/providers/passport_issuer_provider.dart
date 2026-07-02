import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vcmrtd/vcmrtd.dart';

final passportUrlProvider = Provider((ref) => 'https://passport-issuer.yivi.app');

/// Hosts the passport issuer is allowed to hand the app an `irma_server_url` for.
///
/// [DefaultPassportIssuer] posts the IRMA JWT — which carries the raw biometric
/// passport scan — to the server-supplied `irma_server_url`, and refuses any
/// host outside this allowlist. The Yivi IRMA server runs on a *different* host
/// than the passport issuer (`is.yivi.app` in production, `is.staging.yivi.app`
/// on staging), so those hosts must be listed explicitly; otherwise issuance
/// would be rejected by the URL validation.
final allowedIrmaHostsProvider = Provider<Set<String>>((ref) => const {'is.yivi.app', 'is.staging.yivi.app'});

final passportIssuerProvider = Provider(
  (ref) => DefaultPassportIssuer(
    hostName: ref.watch(passportUrlProvider),
    allowedIrmaHosts: ref.watch(allowedIrmaHostsProvider),
  ),
);
