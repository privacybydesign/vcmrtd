import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:twentyface_flutter/twentyface_flutter.dart';

// License key injected at build time via --dart-define=TWENTYFACE_LICENSE=xxx
const _license = String.fromEnvironment('TWENTYFACE_LICENSE');

// License server credentials (from 20face SDK)
const _licenseUsername = 'yivi';
const _licensePassword = '185c6316-2d25-472a-90bd-e54b6a3d141b';
const _licenseServerUrl = 'https://license.20face.nl';

void main() {
  runApp(const TwentyfaceExampleApp());
}

class TwentyfaceExampleApp extends StatelessWidget {
  const TwentyfaceExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '20face Flutter Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _service = FaceVerificationService();
  String _status = 'Not initialized';
  String? _version;
  bool _isInitializing = false;
  Uint8List? _referenceImage;
  FaceComparisonResult? _lastResult;

  // Configuration for face verification - adjust threshold as needed
  static const _matchThreshold = 0.7; // Distance threshold (lower = stricter)

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  Future<String?> _fetchLicense() async {
    try {
      // Get hardware ID from the SDK
      setState(() => _status = 'Getting hardware ID...');
      final hardwareId = await TwentyfacePlugin.getHardwareId();
      if (hardwareId.isEmpty) {
        throw Exception('Failed to get hardware ID');
      }

      // Authenticate with license server
      setState(() => _status = 'Authenticating with license server...');
      final authResponse = await http.post(
        Uri.parse('$_licenseServerUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': _licenseUsername,
          'password': _licensePassword,
        }),
      );

      if (authResponse.statusCode != 200) {
        throw Exception('Authentication failed: ${authResponse.body}');
      }

      final authData = jsonDecode(authResponse.body);
      final accessToken = authData['access_token'] as String;

      // Request license
      setState(() => _status = 'Requesting license...');
      final licenseResponse = await http.post(
        Uri.parse('$_licenseServerUrl/licenses/license'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'hardware_id': hardwareId,
          'lifespan_days': 30,
        }),
      );

      if (licenseResponse.statusCode != 200) {
        throw Exception('License request failed: ${licenseResponse.body}');
      }

      final licenseData = jsonDecode(licenseResponse.body);
      return licenseData['license_key'] as String?;
    } catch (e) {
      debugPrint('License fetch error: $e');
      return null;
    }
  }

  Future<void> _initialize() async {
    setState(() {
      _isInitializing = true;
      _status = 'Initializing...';
    });

    try {
      String license = _license;

      // If no license provided via build arg, fetch from server
      if (license.isEmpty) {
        setState(() => _status = 'No license provided, fetching from server...');
        final fetchedLicense = await _fetchLicense();
        if (fetchedLicense == null || fetchedLicense.isEmpty) {
          setState(() {
            _status = 'Failed to fetch license. You can also build with --dart-define=TWENTYFACE_LICENSE=xxx';
            _isInitializing = false;
          });
          return;
        }
        license = fetchedLicense;
      }

      setState(() => _status = 'Initializing SDK...');
      await _service.initialize(license);
      final version = await _service.getVersion();

      setState(() {
        _status = 'Initialized successfully';
        _version = version;
        _isInitializing = false;
      });
    } catch (e) {
      setState(() {
        _status = 'Initialization failed: $e';
        _isInitializing = false;
      });
    }
  }

  Future<void> _pickReferenceImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 90,
      );

      if (pickedFile == null) {
        setState(() => _status = 'No image selected');
        return;
      }

      final bytes = await File(pickedFile.path).readAsBytes();
      setState(() {
        _referenceImage = bytes;
        _status = 'Reference image loaded (${_referenceImage!.length} bytes)';
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to load image: $e';
      });
    }
  }

  void _startVerification() {
    if (_referenceImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Load a reference image first')),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FaceVerificationScreen(
          referenceImage: _referenceImage!,
          referenceImageType: ImageType.jpeg,
          service: _service,
          config: const FaceVerificationConfig(
            matchThreshold: _matchThreshold,
          ),
          onResult: (result) {
            setState(() {
              _lastResult = result;
              _status = result.match
                  ? 'Verification successful!'
                  : 'Verification failed';
            });
          },
          onCancel: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('20face Flutter Demo'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildStatusCard(),
            const SizedBox(height: 16),
            _buildActionsCard(),
            const SizedBox(height: 16),
            if (_lastResult != null) _buildResultCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _service.isInitialized ? Icons.check_circle : Icons.info,
                  color: _service.isInitialized ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  'SDK Status',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(_status),
            if (_version != null) ...[
              const SizedBox(height: 4),
              Text('Version: $_version', style: TextStyle(color: Colors.grey[600])),
            ],
            if (_referenceImage != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.image, size: 16, color: Colors.green),
                  const SizedBox(width: 4),
                  Text(
                    'Reference image: ${_referenceImage!.length} bytes',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Actions',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: _isInitializing || _service.isInitialized
                      ? null
                      : _initialize,
                  icon: _isInitializing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_arrow),
                  label: const Text('Initialize SDK'),
                ),
                ElevatedButton.icon(
                  onPressed: _service.isInitialized ? _pickReferenceImage : null,
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Pick Reference Image'),
                ),
                ElevatedButton.icon(
                  onPressed: _service.isInitialized && _referenceImage != null
                      ? _startVerification
                      : null,
                  icon: const Icon(Icons.face),
                  label: const Text('Start Verification'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    final result = _lastResult!;
    final similarity = result.similarityPercentage ?? 0.0;
    final distance = result.recognitionDistance;

    // Calculate threshold as similarity percentage for comparison
    // Distance threshold 0.7 = similarity 65%
    final thresholdSimilarity = ((2.0 - _matchThreshold) / 2.0 * 100).clamp(0.0, 100.0);

    // Determine match quality
    String qualityLabel;
    Color qualityColor;
    if (distance < 0) {
      qualityLabel = 'Error';
      qualityColor = Colors.grey;
    } else if (distance <= 0.4) {
      qualityLabel = 'Excellent Match';
      qualityColor = Colors.green[700]!;
    } else if (distance <= 0.6) {
      qualityLabel = 'Good Match';
      qualityColor = Colors.green;
    } else if (distance <= _matchThreshold) {
      qualityLabel = 'Marginal Match';
      qualityColor = Colors.orange;
    } else if (distance <= _matchThreshold + 0.1) {
      qualityLabel = 'Close - No Match';
      qualityColor = Colors.orange[700]!;
    } else {
      qualityLabel = 'No Match';
      qualityColor = Colors.red;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with match status
            Row(
              children: [
                Icon(
                  result.match ? Icons.check_circle : Icons.cancel,
                  color: result.match ? Colors.green : Colors.red,
                  size: 28,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result.match ? 'MATCH' : 'NO MATCH',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: result.match ? Colors.green[700] : Colors.red[700],
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(
                        qualityLabel,
                        style: TextStyle(
                          color: qualityColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Similarity score with visual bar
            Text(
              'Similarity Score',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      // Background bar
                      Container(
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      // Similarity fill
                      FractionallySizedBox(
                        widthFactor: (similarity / 100).clamp(0.0, 1.0),
                        child: Container(
                          height: 24,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: similarity >= thresholdSimilarity
                                  ? [Colors.green[300]!, Colors.green[600]!]
                                  : [Colors.red[300]!, Colors.red[600]!],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      // Threshold marker
                      Positioned(
                        left: (thresholdSimilarity / 100) * MediaQuery.of(context).size.width * 0.75,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          width: 3,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${similarity.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: similarity >= thresholdSimilarity ? Colors.green[700] : Colors.red[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Threshold: ${thresholdSimilarity.toStringAsFixed(0)}% (distance ≤ $_matchThreshold)',
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),

            const SizedBox(height: 16),

            // Distance detail
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  _buildDetailRow('Recognition Distance', distance.toStringAsFixed(4),
                    subtitle: 'Range: 0.0 (identical) to 2.0 (different)'),
                  const Divider(height: 16),
                  _buildDetailRow('Match Threshold', _matchThreshold.toStringAsFixed(2),
                    subtitle: 'Distance must be below this'),
                  const Divider(height: 16),
                  _buildDetailRow(
                    'Margin',
                    '${(distance - _matchThreshold).abs().toStringAsFixed(3)} ${distance <= _matchThreshold ? "under" : "over"}',
                    isPositive: distance <= _matchThreshold,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Status checks
            Text(
              'Verification Checks',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            _buildCheckRow('Face Match', result.match),
            _buildCheckRow('Liveness Check', result.passedLivenessCheck),
            _buildCheckRow('Live Image Quality', result.statusImage1.isOverallOk),
            _buildCheckRow('Reference Image Quality', result.statusImage2.isOverallOk),

            // Error details
            if (!result.statusImage1.isOverallOk) ...[
              const SizedBox(height: 8),
              _buildErrorBox('Live image issues', result.statusImage1.errorMessages),
            ],
            if (!result.statusImage2.isOverallOk) ...[
              const SizedBox(height: 8),
              _buildErrorBox('Reference image issues', result.statusImage2.errorMessages),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {String? subtitle, bool? isPositive}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: Colors.grey[700], fontSize: 13)),
            if (subtitle != null)
              Text(subtitle, style: TextStyle(color: Colors.grey[500], fontSize: 10)),
          ],
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: isPositive == null ? null : (isPositive ? Colors.green[700] : Colors.red[700]),
          ),
        ),
      ],
    );
  }

  Widget _buildCheckRow(String label, bool passed) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            passed ? Icons.check_circle : Icons.cancel,
            size: 18,
            color: passed ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 8),
          Text(label),
          const Spacer(),
          Text(
            passed ? 'PASS' : 'FAIL',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: passed ? Colors.green[700] : Colors.red[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBox(String title, List<String> errors) {
    if (errors.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.orange[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.orange[800])),
          const SizedBox(height: 4),
          ...errors.map((e) => Text('• $e', style: TextStyle(fontSize: 11, color: Colors.orange[700]))),
        ],
      ),
    );
  }

}
