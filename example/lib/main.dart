// Created by Crt Vavros, copyright © 2022 ZeroPass. All rights reserved.
// MRTD Example App - Refactored with extracted widgets

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:logging/logging.dart';
import 'package:vcmrtd/extensions.dart';
import 'package:vcmrtdapp/services/deeplink_service.dart';

import 'widgets/pages/app_navigation.dart';

final deepLinkService = DeepLinkService();

void main() async {
  Logger.root.level = Level.ALL;
  Logger.root.logSensitiveData = true;
  Logger.root.onRecord.listen((record) {
    print('${record.loggerName} ${record.level.name}: ${record.time}: ${record.message}');
  });
  WidgetsFlutterBinding.ensureInitialized();
  await deepLinkService.init();
  runApp(VcMrtdApp());
}

class VcMrtdApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return PlatformApp(
      localizationsDelegates: const [
        DefaultMaterialLocalizations.delegate,
        DefaultCupertinoLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      material: (_, __) => MaterialAppData(
        theme: ThemeData(
          primarySwatch: Colors.indigo,
          brightness: Brightness.light,
          textTheme: TextTheme(bodyLarge: TextStyle(fontSize: 16.0, color: Colors.black87)),
          appBarTheme: AppBarTheme(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
        ),
        // Optional:
        // darkTheme: ThemeData.dark(),
        // themeMode: ThemeMode.system,
      ),
      cupertino: (_, __) => CupertinoAppData(
        theme: CupertinoThemeData(
          primaryColor: CupertinoColors.activeBlue,
          barBackgroundColor: CupertinoColors.systemGrey6,
          textTheme: CupertinoTextThemeData(textStyle: TextStyle(fontSize: 16)),
        ),
      ),
      home: AppNavigation(deepLinkService: deepLinkService),
    );
  }
}
