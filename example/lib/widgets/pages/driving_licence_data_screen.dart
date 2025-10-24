import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';

import '../../models/mrtd_data.dart';

class DrivingLicenceDataScreen extends StatelessWidget {
  final MrtdData mrtdData;
  final VoidCallback onBackPressed;

  const DrivingLicenceDataScreen({
    super.key,
    required this.mrtdData,
    required this.onBackPressed,
  });

  @override
  Widget build(BuildContext context) {
    final edlData = mrtdData.dg1?.edlData;
    final imageData = mrtdData.dg6?.imageData;

    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: const Text('Driving Licence Data'),
        leading: PlatformIconButton(
          icon: Icon(PlatformIcons(context).back),
          onPressed: onBackPressed,
        ),
      ),
      body: SafeArea(
        child: edlData == null
            ? const Center(child: Text('No driving licence data available'))
            : ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Photo section
            if (imageData != null) ...[
              _buildPhotoSection(imageData),
              const SizedBox(height: 24),
            ],

            _buildSection('Personal Information', [
              _buildDataRow('Surname', edlData.holderSurname),
              _buildDataRow('Other Names', edlData.holderOtherName),
              _buildDataRow('Date of Birth', _formatDate(edlData.dateOfBirth)),
              _buildDataRow('Place of Birth', edlData.placeOfBirth),
            ]),
            const SizedBox(height: 24),
            _buildSection('Document Information', [
              _buildDataRow('Document Number', edlData.documentNumber),
              _buildDataRow('Issuing Member State', edlData.issuingMemberState),
              _buildDataRow('Issuing Authority', edlData.issuingAuthority),
              _buildDataRow('Date of Issue', _formatDate(edlData.dateOfIssue)),
              _buildDataRow('Date of Expiry', _formatDate(edlData.dateOfExpiry)),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoSection(Uint8List imageData) {
    return Center(
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: CupertinoColors.systemGrey4, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.memory(
            imageData,
            width: 200,
            height: 250,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: 200,
                height: 250,
                color: CupertinoColors.systemGrey6,
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        CupertinoIcons.photo,
                        size: 48,
                        color: CupertinoColors.systemGrey,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Unable to load photo',
                        style: TextStyle(color: CupertinoColors.systemGrey),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildDataRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: CupertinoColors.systemGrey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value ?? 'N/A',
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  String? _formatDate(String? date) {
    if (date == null || date.length != 8) return date;

    final day = date.substring(0, 2);
    final month = date.substring(2, 4);
    final year = date.substring(4, 8);

    return '$day/$month/$year';
  }
}