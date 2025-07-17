// Created by Crt Vavros, copyright © 2022 ZeroPass. All rights reserved.
// MRTD data display widget with expandable panels

import 'package:expandable/expandable.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';

/// Widget to display MRTD data in expandable panels
class MrtdDataWidget extends StatelessWidget {
  final String header;
  final String collapsedText;
  final String dataText;

  const MrtdDataWidget({
    Key? key,
    required this.header,
    required this.collapsedText,
    required this.dataText,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ExpandablePanel(
      theme: const ExpandableThemeData(
        headerAlignment: ExpandablePanelHeaderAlignment.center,
        tapBodyToCollapse: true,
        hasIcon: true,
        iconColor: Colors.red,
      ),
      header: Text(header),
      collapsed: Text(
        collapsedText,
        softWrap: true,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      expanded: Container(
        padding: const EdgeInsets.all(18),
        color: const Color.fromARGB(255, 239, 239, 239),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PlatformTextButton(
              child: const Text('Copy'),
              onPressed: () => Clipboard.setData(ClipboardData(text: dataText)),
              padding: const EdgeInsets.all(8),
            ),
            SelectableText(
              dataText,
              textAlign: TextAlign.left,
            ),
          ],
        ),
      ),
    );
  }
}