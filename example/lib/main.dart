// Created by Crt Vavros, copyright © 2022 ZeroPass. All rights reserved.
// MRTD Example App - Refactored with extracted widgets

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:vcmrtd/extensions.dart';
import 'package:vcmrtdapp/routing.dart';

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
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: createRouter(context, ref),
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
