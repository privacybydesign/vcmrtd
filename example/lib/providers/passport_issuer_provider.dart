import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vcmrtd/vcmrtd.dart';

final passportIssuerProvider = Provider(
  (ref) => DefaultPassportIssuer(hostName: 'https://passport-issuer.staging.yivi.app'),
);
