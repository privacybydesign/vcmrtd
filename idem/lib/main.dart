// Created by Crt Vavros, copyright © 2022 ZeroPass. All rights reserved.
// MRTD Example App - Refactored with extracted widgets

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:vcmrtd/extensions.dart';
import 'package:idem/providers/proofing_session_provider.dart';
import 'package:idem/routing.dart';
import 'package:idem/services/proofing_deeplink_channel.dart';
import 'package:idem/services/proofing_session_client.dart';

void main() async {
  Logger.root.level = Level.ALL;
  Logger.root.logSensitiveData = true;
  Logger.root.onRecord.listen((record) {
    print('${record.loggerName} ${record.level.name}: ${record.time}: ${record.message}');
  });

  WidgetsFlutterBinding.ensureInitialized();
  runApp(ProviderScope(child: VcMrtdApp()));
}

class VcMrtdApp extends ConsumerStatefulWidget {
  @override
  ConsumerState<VcMrtdApp> createState() => _VcMrtdAppState();
}

class _VcMrtdAppState extends ConsumerState<VcMrtdApp> {
  late final GoRouter _router = createRouter();

  @override
  void initState() {
    super.initState();
    // A tapped vcmrtd:// link while the app is already running.
    ProofingDeepLinkChannel.listen(_openProofingLink);
    // A tapped vcmrtd:// link that cold-started the app.
    ProofingDeepLinkChannel.getInitialLink().then((link) {
      if (link != null) _openProofingLink(link);
    });
  }

  /// Resolves a vcmrtd:// deep link to its identity-proofing session and
  /// pushes the consent screen — the deep-link counterpart of
  /// _handleScannedQr in routing.dart, which does the same for a scanned QR.
  /// Silently gives up on an unrecognised or unreachable session: unlike the
  /// QR scanner, there's no screen here to show an error in.
  Future<void> _openProofingLink(String value) async {
    final sessionRef = ProofingSessionRef.parse(value);
    if (sessionRef == null) return;
    try {
      final info = await ref.read(proofingSessionClientProvider).fetchSession(sessionRef);
      if (info.requestedAttributes.isEmpty) return;
      _router.push(proofingConsentPath, extra: {'ref': sessionRef, 'info': info});
    } catch (_) {
      // best effort — nowhere to surface this outside the QR scanner flow
    }
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: _router,
      localizationsDelegates: const [
        DefaultMaterialLocalizations.delegate,
        DefaultCupertinoLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        brightness: Brightness.light,
        textTheme: TextTheme(bodyLarge: TextStyle(fontSize: 16.0, color: Colors.black87)),
        appBarTheme: AppBarTheme(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
      ),
    );
  }
}
