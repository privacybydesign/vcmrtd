import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vcmrtd/vcmrtd.dart';

final passportUrlProvider = Provider((ref) => 'https://passport-issuer.staging.yivi.app');

final passportIssuerProvider = Provider((ref) => DefaultPassportIssuer(hostName: ref.watch(passportUrlProvider)));
