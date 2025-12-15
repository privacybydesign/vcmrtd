import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vcmrtd/vcmrtd.dart';
import 'app_config_provider.dart';

final passportIssuerProvider = Provider((ref) => DefaultPassportIssuer(hostName: ref.watch(issuerUrlProvider)));
