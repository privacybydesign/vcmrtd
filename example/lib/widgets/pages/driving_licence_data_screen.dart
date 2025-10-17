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
    final licenseNumber = dg1.driverLicenceNumber ?? '-';
    final country = dg1.driverLicenceCountry ?? '-';
    final generation = dg1.driverLicenceGeneration?.toString() ?? '-';

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
              Text('License Number: $licenseNumber'),
              Text('Country: $country'),
              Text('Generation: $generation'),
            ],
          ),
        ),
      ),
    );
  }
}
