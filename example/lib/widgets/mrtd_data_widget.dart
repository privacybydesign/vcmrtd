import 'package:expandable/expandable.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';

class MrtdDataWidget extends StatelessWidget {
  final String header;
  final String collapsedText;
  final String dataText;

  const MrtdDataWidget({
    super.key,
    required this.header,
    required this.collapsedText,
    required this.dataText,
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
              padding: const EdgeInsets.all(8),
              onPressed: () => Clipboard.setData(ClipboardData(text: dataText)),
              child: const Text('Copy'),
            ),
            SelectableText(dataText, textAlign: TextAlign.left),
          ],
        ),
      ),
    );
  }
}
