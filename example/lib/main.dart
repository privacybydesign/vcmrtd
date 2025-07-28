// Created by Crt Vavros, copyright © 2022 ZeroPass. All rights reserved.
// MRTD Example App - Refactored with extracted widgets

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:logging/logging.dart';
import 'package:dmrtd/extensions.dart';

import 'widgets/pages/app_navigation.dart';
import 'models/authentication_context.dart';
import 'services/universal_link_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  Logger.root.level = Level.ALL;
  Logger.root.logSensitiveData = true;
  Logger.root.onRecord.listen((record) {
    print(
        '${record.loggerName} ${record.level.name}: ${record.time}: ${record.message}');
  });
  
  // Initialize universal link handler
  final linkHandler = UniversalLinkHandler();
  await linkHandler.initialize();
  
  runApp(MrtdEgApp(linkHandler: linkHandler));
}

class MrtdEgApp extends StatefulWidget {
  final UniversalLinkHandler linkHandler;

  const MrtdEgApp({Key? key, required this.linkHandler}) : super(key: key);

  @override
  State<MrtdEgApp> createState() => _MrtdEgAppState();
}

class _MrtdEgAppState extends State<MrtdEgApp> {
  AuthenticationContext? _initialAuthContext;

  @override
  void initState() {
    super.initState();
    
    // Check if we have an initial authentication context
    _initialAuthContext = widget.linkHandler.currentAuthContext;
    
    // Listen for authentication context changes
    widget.linkHandler.authContextStream.listen((authContext) {
      if (mounted) {
        // Handle incoming universal links while app is running
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => AppNavigation(initialAuthContext: authContext),
          ),
        );
      }
    });
  }

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
          textTheme: const TextTheme(
            bodyLarge: TextStyle(fontSize: 16.0, color: Colors.black87),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.indigo,
            foregroundColor: Colors.white,
          ),
        ),
        // Optional:
        // darkTheme: ThemeData.dark(),
        // themeMode: ThemeMode.system,
      ),
      cupertino: (_, __) => CupertinoAppData(
        theme: const CupertinoThemeData(
          primaryColor: CupertinoColors.activeBlue,
          barBackgroundColor: CupertinoColors.systemGrey6,
          textTheme: CupertinoTextThemeData(
            textStyle: TextStyle(fontSize: 16),
          ),
        ),
      ),
      home: AppNavigation(initialAuthContext: _initialAuthContext),
    );
  }
}
