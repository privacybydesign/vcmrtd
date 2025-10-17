import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:vcmrtd/vcmrtd.dart';
import 'package:vcmrtdapp/widgets/pages/data_screen_widgets/profile_picture.dart';

import 'info_row.dart';

class PersonalDataSection extends StatelessWidget {
  final MRZ mrz;
  final EfDG2 dg2;

  const PersonalDataSection({
    Key? key,
    required this.mrz,
    required this.dg2,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
    return Column(
      children: [
        // Profile picture and basic info
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProfilePictureWidget(
                imageData: dg2.imageData, imageType: dg2.imageType),
            const SizedBox(width: 20),
            Expanded(child: _buildBasicInfo()),
          ],
        ),
        const SizedBox(height: 20),
        _buildDetailedInfo(),
      ],
    );
  }

  Widget _buildBasicInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InfoRow(
            label: 'Full Name',
            value: '${mrz.firstName} ${mrz.lastName}',
            iconData: Icons.person_outline),
        const SizedBox(height: 12),
        InfoRow(
            label: 'Nationality',
            value: mrz.nationality,
            iconData: Icons.flag_outlined),
        const SizedBox(height: 12),
        InfoRow(
            label: 'Document',
            value: '${mrz.documentCode} ${mrz.documentNumber}',
            iconData: Icons.document_scanner_outlined),
        const SizedBox(height: 12),
        InfoRow(
            label: 'Gender',
            value: mrz.gender,
            iconData: Icons.person_pin_outlined),
      ],
    );
  }

  Widget _buildDetailedInfo() {
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
                child: InfoRow(
                  label: 'Date of Birth',
                  value: DateFormat.yMMMd().format(mrz.dateOfBirth),
                  iconData: Icons.cake_outlined,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: InfoRow(
                  label: 'Expiry Date',
                  value: DateFormat.yMMMd().format(mrz.dateOfExpiry),
                  iconData: Icons.event_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: InfoRow(
                    label: 'Country',
                    value: mrz.country,
                    iconData: Icons.public_outlined),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: InfoRow(
                    label: 'Version',
                    value: mrz.version.name,
                    iconData: Icons.info_outline),
              ),
            ],
          ),
          if (mrz.optionalData.isNotEmpty) ...[
            const SizedBox(height: 12),
            InfoRow(
                label: 'Optional Data',
                value: mrz.optionalData,
                iconData: Icons.data_object_outlined),
          ],
        ],
      ),
    );
  }
}
