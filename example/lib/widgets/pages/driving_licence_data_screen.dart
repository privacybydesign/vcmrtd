import 'package:flutter/cupertino.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';

import '../../models/mrtd_data.dart';

class DrivingLicenceDataScreen extends StatelessWidget {
  final MrtdData mrtdData;
  final VoidCallback onBackPressed;

  const DrivingLicenceDataScreen({
    Key? key,
    required this.mrtdData,
    required this.onBackPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final dg1 = mrtdData.dg1!;


    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: const Text('Driving Licence Data'),
        leading: PlatformIconButton(
          icon: Icon(PlatformIcons(context).back),
          onPressed: onBackPressed,
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('DG1 : $dg1'),
            ],
          ),
        ),
      ),
    );
  }
}
