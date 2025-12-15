import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vcmrtdapp/providers/app_config_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _faceApiController;
  late TextEditingController _issuerUrlController;

  @override
  void initState() {
    super.initState();
    _faceApiController = TextEditingController();
    _issuerUrlController = TextEditingController();
  }

  @override
  void dispose() {
    _faceApiController.dispose();
    _issuerUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final faceApiUrl = ref.watch(faceApiUrlProvider);
    final issuerUrl = ref.watch(issuerUrlProvider);

    // Update controllers when providers change
    if (_faceApiController.text != faceApiUrl) {
      _faceApiController.text = faceApiUrl;
    }
    if (_issuerUrlController.text != issuerUrl) {
      _issuerUrlController.text = issuerUrl;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildSection(
            title: 'Face API Configuration',
            child: _buildUrlField(
              controller: _faceApiController,
              label: 'Face API URL',
              hint: 'https://your-face-api.example.com',
              currentValue: faceApiUrl,
              onSave: (value) {
                if (value.isNotEmpty) {
                  ref.read(faceApiUrlProvider.notifier).state = value;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Face API URL updated')),
                  );
                }
              },
            ),
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: 'Issuer Configuration',
            child: _buildUrlField(
              controller: _issuerUrlController,
              label: 'Issuer URL',
              hint: 'https://your-issuer.example.com',
              currentValue: issuerUrl,
              onSave: (value) {
                if (value.isNotEmpty) {
                  ref.read(issuerUrlProvider.notifier).state = value;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Issuer URL updated')),
                  );
                }
              },
            ),
          ),
          const SizedBox(height: 24),
          _buildInfoCard(),
        ],
      ),
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  Widget _buildUrlField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required String currentValue,
    required void Function(String) onSave,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: label,
                hintText: hint,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.link),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: () {
                    controller.text = currentValue;
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reset'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    onSave(controller.text.trim());
                  },
                  icon: const Icon(Icons.save),
                  label: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text(
                  'Information',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Face API URL: Configuration for face verification API endpoint. '
              'Currently the app uses the on-device Regula Face SDK. '
              'This setting is available for future remote API integration.\n\n'
              'Issuer URL: The backend server URL for passport/document verification and IRMA credential issuance. '
              'Used for all document verification and credential issuance operations.',
              style: TextStyle(color: Colors.blue.shade900),
            ),
          ],
        ),
      ),
    );
  }
}
