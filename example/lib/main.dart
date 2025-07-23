// Created by Crt Vavros, copyright © 2022 ZeroPass. All rights reserved.
// MRTD Example App - Refactored with extracted widgets

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:logging/logging.dart';
import 'package:dmrtd/extensions.dart';

import 'widgets/widgets.dart';
import 'widgets/pages/app_navigation.dart';

void main() {
  Logger.root.level = Level.ALL;
  Logger.root.logSensitiveData = true;
  Logger.root.onRecord.listen((record) {
    print(
        '${record.loggerName} ${record.level.name}: ${record.time}: ${record.message}');
  });
  runApp(MrtdEgApp());
}

class MrtdEgApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return PlatformApp(
      localizationsDelegates: const [
        DefaultMaterialLocalizations.delegate,
        DefaultCupertinoLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      material: (_, __) => MaterialAppData(),
      cupertino: (_, __) => CupertinoAppData(),
      home: AppNavigation(), // Changed to new navigation flow
    );
  }
}