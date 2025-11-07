import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vcmrtd/vcmrtd.dart';

class DrivingLicenceDataScreen extends ConsumerStatefulWidget {
  final DrivingLicenceData drivingLicence;
  final VoidCallback onBackPressed;

  const DrivingLicenceDataScreen({super.key, required this.drivingLicence, required this.onBackPressed});

  @override
  ConsumerState<DrivingLicenceDataScreen> createState() => _DrivingLicenceDataScreenState();
}

class _DrivingLicenceDataScreenState extends ConsumerState<DrivingLicenceDataScreen> {
  @override
  Widget build(BuildContext context) {
    final imageData = widget.drivingLicence.photoImageData;

    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: const Text('Driving Licence Data'),
        leading: PlatformIconButton(icon: Icon(PlatformIcons(context).back), onPressed: widget.onBackPressed),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Photo section
            ...[_buildPhotoSection(imageData), const SizedBox(height: 24)],

            _buildSection('Personal Information', [
              _buildDataRow('Surname', widget.drivingLicence.holderSurname),
              _buildDataRow('Other Names', widget.drivingLicence.holderOtherName),
              _buildDataRow('Date of Birth', _formatDate(widget.drivingLicence.dateOfBirth)),
              _buildDataRow('Place of Birth', widget.drivingLicence.placeOfBirth),
            ]),
            const SizedBox(height: 24),
            _buildSection('Document Information', [
              _buildDataRow('Document Number', widget.drivingLicence.documentNumber),
              _buildDataRow('Issuing Member State', widget.drivingLicence.issuingMemberState),
              _buildDataRow('Issuing Authority', widget.drivingLicence.issuingAuthority),
              _buildDataRow('Date of Issue', _formatDate(widget.drivingLicence.dateOfIssue)),
              _buildDataRow('Date of Expiry', _formatDate(widget.drivingLicence.dateOfExpiry)),
            ]),
          ],
        ),
      ),
    );
  }
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
                    Icon(CupertinoIcons.photo, size: 48, color: CupertinoColors.systemGrey),
                    SizedBox(height: 8),
                    Text('Unable to load photo', style: TextStyle(color: CupertinoColors.systemGrey)),
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
      Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
            style: const TextStyle(fontWeight: FontWeight.w600, color: CupertinoColors.systemGrey),
          ),
        ),
        Expanded(child: Text(value ?? 'N/A', style: const TextStyle(fontSize: 16))),
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
