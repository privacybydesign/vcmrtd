// Created by Crt Vavros, copyright © 2022 ZeroPass. All rights reserved.
// Access protocol display widget for MRTD

import 'package:expandable/expandable.dart';
import 'package:flutter/material.dart';

/// Widget to display MRTD access protocol information
class AccessProtocolWidget extends StatelessWidget {
  final String header;
  final String collapsedText;
  final bool isPACE;
  final bool isDBA;

  const AccessProtocolWidget({
    super.key,
    required this.header,
    required this.collapsedText,
    required this.isPACE,
    required this.isDBA,
  });

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
      collapsed: Text(collapsedText, softWrap: true, maxLines: 2, overflow: TextOverflow.ellipsis),
      expanded: Container(
        padding: const EdgeInsets.all(18),
        color: const Color.fromARGB(255, 239, 239, 239),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Access protocol: ${isPACE ? "PACE" : "BAC"}'),
            const SizedBox(height: 8.0),
            Text('Access key type: ${isDBA ? "DBA" : "CAN"}'),
          ],
        ),
      ),
    );
  }
}
