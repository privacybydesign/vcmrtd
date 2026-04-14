import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:twentyface_flutter/twentyface_flutter.dart';

import 'continuous_match_screen.dart';

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
  bool _referenceFaceDetected = false;
  bool _isDetectingFace = false;

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

  Future<void> _pickReferenceImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 90,
        preferredCameraDevice: CameraDevice.front,
      );

      if (pickedFile == null) {
        setState(() => _status = 'No image selected');
        return;
      }

      final bytes = await File(pickedFile.path).readAsBytes();
      setState(() {
        _referenceImage = bytes;
        _referenceFaceDetected = false;
        _isDetectingFace = true;
        _status = 'Detecting face in reference image...';
      });

      // Run face detection on the reference image
      final detections = await _service.detectFaces(bytes);
      final hasFace = detections.isNotEmpty;

      debugPrint('Reference image: ${bytes.length} bytes, '
          'source=${source.name}, detections=${detections.length}');
      if (detections.isNotEmpty) {
        final d = detections.first;
        debugPrint('  first detection: score=${d.score}, '
            'rect=${d.normalizedRect}, overallOk=${d.isOverallOk}');
      }

      setState(() {
        _referenceFaceDetected = hasFace;
        _isDetectingFace = false;
        _status = hasFace
            ? 'Face detected in reference image (${detections.length})'
            : 'No face detected in reference image';
      });
    } catch (e) {
      setState(() {
        _isDetectingFace = false;
        _status = 'Failed to load image: $e';
      });
    }
  }

  void _startContinuousMatch() {
    if (_referenceImage == null || !_referenceFaceDetected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Load a reference image with a detected face first')),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ContinuousMatchScreen(
          service: _service,
          referenceImage: _referenceImage!,
          referenceImageType: ImageType.jpeg,
          config: const FaceVerificationConfig(
            matchThreshold: _matchThreshold,
          ),
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
            if (_referenceImage != null) ...[
              _buildReferenceImageCard(),
              const SizedBox(height: 16),
            ],
            _buildActionsCard(),
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
          ],
        ),
      ),
    );
  }

  Widget _buildReferenceImageCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Reference Image',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                // Face detection badge
                if (_isDetectingFace)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _referenceFaceDetected
                          ? Colors.green[50]
                          : Colors.red[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _referenceFaceDetected
                            ? Colors.green
                            : Colors.red,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _referenceFaceDetected
                              ? Icons.face
                              : Icons.face_retouching_off,
                          size: 14,
                          color: _referenceFaceDetected
                              ? Colors.green[700]
                              : Colors.red[700],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _referenceFaceDetected ? 'Face found' : 'No face',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _referenceFaceDetected
                                ? Colors.green[700]
                                : Colors.red[700],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // Image preview
            Center(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 200),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _referenceFaceDetected
                        ? Colors.green.withValues(alpha: 0.5)
                        : Colors.red.withValues(alpha: 0.5),
                    width: 3,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: Image.memory(
                    _referenceImage!,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${(_referenceImage!.length / 1024).toStringAsFixed(0)} KB',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsCard() {
    final sdkReady = _service.isInitialized;
    final canMatch = sdkReady && _referenceImage != null && _referenceFaceDetected;

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

            // Initialize
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isInitializing || sdkReady ? null : _initialize,
                icon: _isInitializing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow),
                label: const Text('Initialize SDK'),
              ),
            ),

            const SizedBox(height: 12),

            // Reference image buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: sdkReady
                        ? () => _pickReferenceImage(ImageSource.gallery)
                        : null,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Pick Photo'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: sdkReady
                        ? () => _pickReferenceImage(ImageSource.camera)
                        : null,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Take Selfie'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Start matching
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: canMatch ? _startContinuousMatch : null,
                icon: const Icon(Icons.face),
                label: const Text('Start Continuous Matching'),
              ),
            ),

            if (sdkReady && _referenceImage != null && !_referenceFaceDetected && !_isDetectingFace)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'No face detected in reference image. Pick a different photo.',
                  style: TextStyle(color: Colors.red[700], fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
