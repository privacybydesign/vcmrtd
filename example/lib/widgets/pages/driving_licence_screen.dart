import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';

class DrivingLicenceScreen extends StatelessWidget {
  final VoidCallback onBack;

  const DrivingLicenceScreen({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: const Text('Driving Licence'),
        leading: PlatformIconButton(icon: Icon(PlatformIcons(context).back), onPressed: onBack),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Electronic Driver\'s Licence (eDL) readout',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                      ),
                      SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Card(
                  elevation: 0,
                  color: const Color(0xFFF5F5F5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Text(
                        'Implementation here',
                        style: TextStyle(fontSize: 16, color: Color(0xFF616161)),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
