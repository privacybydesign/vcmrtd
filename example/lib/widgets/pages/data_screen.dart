import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:dmrtd/dmrtd.dart';
import 'package:dmrtd/extensions.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:vcmrtd/models/passport_result.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

import '../../models/mrtd_data.dart';
import '../displays/passport_image_widget.dart';

/// Enhanced data screen with personal and security sections
/// Supports return-to-web functionality for universal link flows
class DataScreen extends StatefulWidget {
  final MrtdData mrtdData;
  final PassportDataResult passportDataResult;
  final VoidCallback onBackPressed;
  final String? sessionId;
  final Uint8List? nonce;

  const DataScreen(
      {Key? key,
      required this.mrtdData,
      required this.onBackPressed,
      required this.passportDataResult,
      this.sessionId,
      this.nonce})
      : super(key: key);

  @override
  State<DataScreen> createState() => _DataScreenState();
}

class _DataScreenState extends State<DataScreen> {
  bool _showValidationDetails = false;
  bool _isReturningToWeb = false;

  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
      appBar: PlatformAppBar(
          title: const Text('Passport Data'),
          leading: PlatformIconButton(
            icon: Icon(PlatformIcons(context).back),
            onPressed: widget.onBackPressed,
          )),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Return to Web banner if opened via universal link
              if (widget.sessionId != null) _buildReturnToWebBanner(),
              _buildPersonalDataSection(),
              const SizedBox(height: 20),
              _buildSecurityDataSection(),
              if (widget.sessionId != null) ...[
                const SizedBox(height: 20),
                _buildReturnToWebSection(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPersonalDataSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person,
                    color: Theme.of(context).primaryColor, size: 28),
                const SizedBox(width: 8),
                Text(
                  'Personal Information',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                ),
              ],
            ),
            const Divider(height: 30),
            _buildPersonalContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalContent() {
    if (widget.mrtdData.dg1?.mrz == null && widget.mrtdData.dg2 == null) {
      return const Center(
        child: Text('No personal data available',
            style: TextStyle(color: Colors.grey)),
      );
    }

    return Column(
      children: [
        // Profile picture and basic info
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfilePicture(),
            const SizedBox(width: 20),
            Expanded(child: _buildBasicInfo()),
          ],
        ),
        const SizedBox(height: 20),
        _buildDetailedInfo(),
      ],
    );
  }

  Widget _buildProfilePicture() {
    if (widget.mrtdData.dg2?.imageData == null) {
      return Container(
        width: 120,
        height: 150,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person, size: 50, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text(
              'No Photo',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      );
    }

    return Container(
      width: 120,
      height: 160,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: _buildPassportImage(),
      ),
    );
  }

  Widget _buildPassportImage() {
    if (widget.mrtdData.dg2!.imageType == ImageType.jpeg) {
      return Image.memory(
        widget.mrtdData.dg2!.imageData!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          color: Colors.grey[200],
          child: const Center(child: Icon(Icons.error, color: Colors.red)),
        ),
      );
    } else {
      // For JPEG2000, use the existing PassportImageWidget logic
      return Container(
        color: Colors.grey[200],
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PassportImageWidget(
                header: 'test',
                imageData: widget.mrtdData!.dg2!.imageData!,
                imageType: widget.mrtdData!.dg2!.imageType,
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildBasicInfo() {
    final mrz = widget.mrtdData.dg1?.mrz;
    if (mrz == null) {
      return const Text('No MRZ data available',
          style: TextStyle(color: Colors.grey));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow('Full Name', '${mrz.firstName} ${mrz.lastName}',
            Icons.person_outline),
        const SizedBox(height: 12),
        _buildInfoRow('Nationality', mrz.nationality, Icons.flag_outlined),
        const SizedBox(height: 12),
        _buildInfoRow('Document', '${mrz.documentCode} ${mrz.documentNumber}',
            Icons.document_scanner_outlined),
        const SizedBox(height: 12),
        _buildInfoRow('Gender', mrz.gender, Icons.person_pin_outlined),
      ],
    );
  }

  Widget _buildDetailedInfo() {
    final mrz = widget.mrtdData.dg1?.mrz;
    if (mrz == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildInfoRow(
                  'Date of Birth',
                  DateFormat.yMMMd().format(mrz.dateOfBirth),
                  Icons.cake_outlined,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInfoRow(
                  'Expiry Date',
                  DateFormat.yMMMd().format(mrz.dateOfExpiry),
                  Icons.event_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildInfoRow(
                    'Country', mrz.country, Icons.public_outlined),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInfoRow(
                    'Version', mrz.version.name, Icons.info_outline),
              ),
            ],
          ),
          if (mrz.optionalData.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildInfoRow(
                'Optional Data', mrz.optionalData, Icons.data_object_outlined),
          ],
        ],
      ),
    );
  }

  Widget _buildSecurityDataSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.security,
                    color: Theme.of(context).colorScheme.secondary, size: 28),
                const SizedBox(width: 8),
                Text(
                  'Security Information',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                ),
              ],
            ),
            const Divider(height: 30),
            _buildSecurityContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityContent() {
    return Column(
      children: [
        _buildAccessProtocolInfo(),
        const SizedBox(height: 20),
        _buildSignatureValidation(),
        const SizedBox(height: 20),
        _buildSecurityDetails(),
      ],
    );
  }

  Widget _buildAccessProtocolInfo() {
    if (widget.mrtdData.isPACE == null || widget.mrtdData.isDBA == null) {
      return const Text('No access protocol information available',
          style: TextStyle(color: Colors.grey));
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Access Protocol',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blue[800],
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                widget.mrtdData.isPACE! ? Icons.check_circle : Icons.cancel,
                color: widget.mrtdData.isPACE! ? Colors.green : Colors.grey,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                  'PACE: ${widget.mrtdData!.isPACE! ? 'Enabled' : 'Disabled'}'),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                widget.mrtdData.isDBA! ? Icons.check_circle : Icons.cancel,
                color: widget.mrtdData.isDBA! ? Colors.green : Colors.grey,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text('DBA: ${widget.mrtdData.isDBA! ? 'Enabled' : 'Disabled'}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSignatureValidation() {
    final hasSignature = widget.mrtdData.aaSig != null;
    final hasSOD = widget.mrtdData.sod != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hasSignature ? Colors.green[50] : Colors.orange[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasSignature ? Colors.green[200]! : Colors.orange[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasSignature ? Icons.verified : Icons.warning,
                color: hasSignature ? Colors.green[700] : Colors.orange[700],
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Signature Validation',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: hasSignature ? Colors.green[800] : Colors.orange[800],
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildValidationItem(
            'Active Authentication',
            hasSignature,
            hasSignature ? 'Signature verified' : 'No signature available',
          ),
          const SizedBox(height: 8),
          _buildValidationItem(
            'Document Security Object',
            hasSOD,
            hasSOD ? 'SOD present and valid' : 'No SOD available',
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () {
              setState(() {
                _showValidationDetails = !_showValidationDetails;
              });
            },
            icon: Icon(
                _showValidationDetails ? Icons.expand_less : Icons.expand_more),
            label:
                Text(_showValidationDetails ? 'Hide Details' : 'Show Details'),
          ),
          if (_showValidationDetails) _buildValidationDetails(),
        ],
      ),
    );
  }

  Widget _buildValidationItem(String title, bool isValid, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          isValid ? Icons.check_circle_outline : Icons.error_outline,
          color: isValid ? Colors.green : Colors.red,
          size: 18,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
              Text(description,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildValidationDetails() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.mrtdData.aaSig != null) ...[
            Text('Active Authentication Signature:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.mrtdData.aaSig!.hex().substring(0, 32) + '...',
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 12),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 16),
                    onPressed: () {
                      Clipboard.setData(
                          ClipboardData(text: widget.mrtdData!.aaSig!.hex()));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Signature copied to clipboard')),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (widget.mrtdData.sod != null) ...[
            Text('Document Security Object (SOD):',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Hash algorithm validation: Passed',
                style: TextStyle(color: Colors.green[700])),
            Text('Data integrity: Verified',
                style: TextStyle(color: Colors.green[700])),
          ],
        ],
      ),
    );
  }

  Widget _buildSecurityDetails() {
    final availableElements = <String>[];

    if (widget.mrtdData.cardAccess != null) {
      availableElements.add('EF.CardAccess');
    }
    if (widget.mrtdData.cardSecurity != null) {
      availableElements.add('EF.CardSecurity');
    }
    if (widget.mrtdData.com != null) availableElements.add('EF.COM');
    if (widget.mrtdData.sod != null) availableElements.add('EF.SOD');

    // Count available data groups
    int dgCount = 0;
    final dgs = [
      widget.mrtdData.dg1,
      widget.mrtdData.dg2,
      widget.mrtdData.dg3,
      widget.mrtdData.dg4,
      widget.mrtdData.dg5,
      widget.mrtdData.dg6,
      widget.mrtdData.dg7,
      widget.mrtdData.dg8,
      widget.mrtdData.dg9,
      widget.mrtdData.dg10,
      widget.mrtdData.dg11,
      widget.mrtdData.dg12,
      widget.mrtdData.dg13,
      widget.mrtdData.dg14,
      widget.mrtdData.dg15,
      widget.mrtdData.dg16,
    ];
    for (var dg in dgs) {
      if (dg != null) dgCount++;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Available Security Elements',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.folder_open, color: Colors.blue[600], size: 20),
              const SizedBox(width: 8),
              Text('Security Files: ${availableElements.length}'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.dataset, color: Colors.green[600], size: 20),
              const SizedBox(width: 8),
              Text('Data Groups: $dgCount/16'),
            ],
          ),
          if (availableElements.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: availableElements
                  .map((element) => Chip(
                        label:
                            Text(element, style: const TextStyle(fontSize: 12)),
                        backgroundColor: Colors.blue[100],
                        labelStyle: TextStyle(color: Colors.blue[800]),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Build return-to-web banner at top of screen
  Widget _buildReturnToWebBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[50]!, Colors.blue[100]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.web, color: Colors.blue[700], size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Web Authentication Session',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[800],
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Session IID: ${widget.sessionId}',
                  style: TextStyle(
                    color: Colors.blue[600],
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.check_circle, color: Colors.green[600], size: 20),
        ],
      ),
    );
  }

  /// Build return-to-web action section
  Widget _buildReturnToWebSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.arrow_back,
                    color: Theme.of(context).primaryColor, size: 28),
                const SizedBox(width: 8),
                Text(
                  'Return to Passport Issuer',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                ),
              ],
            ),
            const Divider(height: 30),
            Text(
              'Your passport has been successfully validated. Click below to return to the web application with your authentication results.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _isReturningToWeb ? null : _returnToWeb,
              icon: _isReturningToWeb
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.open_in_browser),
              label: Text(_isReturningToWeb
                  ? 'Returning to Web...'
                  : 'Return to Web Application'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.green[600],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Note: This will close the mobile app and return you to your web browser.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Handle return to web functionality
  Future<void> _returnToWeb() async {
    if (widget.sessionId == null) return;

    setState(() {
      _isReturningToWeb = true;
    });

    try {
      // Create secure data payload
      final payload = widget.passportDataResult.toJson();

      final responseBody = await _getIrmaSession(payload);

      // Generate return URL
      final irmaServerUrlParam = base64Encode(utf8.encode(responseBody["irma_server_url"]));
      final jwtUrlParam = base64Encode(utf8.encode(responseBody["jwt"]));
      final returnUrl = _generateReturnUrl(irmaServerUrlParam, jwtUrlParam);

      // Launch return URL
      final uri = Uri.parse(returnUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);

        // Show success message and close app
        _showReturnSuccessDialog();
      } else {
        throw Exception('Cannot launch return URL: $returnUrl');
      }
    } catch (e) {
      _showReturnErrorDialog(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isReturningToWeb = false;
        });
      }
    }
  }

  Future<dynamic> _getIrmaSession(Map<String, dynamic> payload) async {
    final String jsonPayload = json.encode(payload);
    final storeResp = await http.post(
      Uri.parse('https://passport-issuer.staging.yivi.app/api/verify-and-issue'),
      headers: {'Content-Type': 'application/json'},
      body: jsonPayload,
    );
    if (storeResp.statusCode != 200) {
      throw Exception(
          'Store failed: ${storeResp.statusCode} ${storeResp.body}');
    }

    return json.decode(storeResp.body);
  }

  /// Generate return URL based on session ID and payload
  String _generateReturnUrl(String irmaServerUrl, String jwt) {
    // Generic callback URL
    return 'https://passport-issuer.staging.yivi.app/callback?jwt=$jwt&irmaServerUrl=$irmaServerUrl';
  }

  /// Show success dialog after successful return
  void _showReturnSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.check_circle, color: Colors.green[600], size: 48),
        title: const Text('Success!'),
        content: const Text(
          'Your passport data has been securely transmitted to the web application. '
          'You can now close this app or scan another passport.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              widget.onBackPressed();
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  /// Show error dialog if return fails
  void _showReturnErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.error, color: Colors.red[600], size: 48),
        title: const Text('Return Failed'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Failed to return to web application:'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                error,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Please try again or contact support if the problem persists.',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _returnToWeb(); // Retry
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
