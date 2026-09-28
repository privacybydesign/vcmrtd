import 'package:flutter/material.dart';
import 'package:idem/l10n/l10n.dart';
import 'package:intl/intl.dart';
import 'package:vcmrtd/vcmrtd.dart';
import 'package:idem/widgets/pages/data_screen_widgets/profile_picture.dart';

import 'info_row.dart';

class PersonalDataSection extends StatelessWidget {
  final PassportData passport;

  const PersonalDataSection({super.key, required this.passport});

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
                Icon(Icons.person, color: Theme.of(context).primaryColor, size: 28),
                const SizedBox(width: 8),
                Text(
                  context.l10n.docPersonalInformation,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
            const Divider(height: 30),
            _buildPersonalContent(context),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalContent(BuildContext context) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProfilePictureWidget(imageData: passport.photoImageData, imageType: passport.photoImageType),
            const SizedBox(width: 20),
            Expanded(child: _buildBasicInfo(context)),
          ],
        ),
        const SizedBox(height: 20),
        _buildDetailedInfo(context),
      ],
    );
  }

  Widget _buildBasicInfo(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InfoRow(label: context.l10n.docFullName, value: passport.displayName, iconData: Icons.person_outline),
        const SizedBox(height: 12),
        InfoRow(label: context.l10n.docNationality, value: passport.mrz.nationality, iconData: Icons.flag_outlined),
        const SizedBox(height: 12),
        InfoRow(
          label: context.l10n.docDocument,
          value: '${passport.mrz.documentCode} ${passport.mrz.documentNumber}',
          iconData: Icons.document_scanner_outlined,
        ),
        const SizedBox(height: 12),
        InfoRow(label: context.l10n.docGender, value: passport.mrz.gender, iconData: Icons.person_pin_outlined),
      ],
    );
  }

  Widget _buildDetailedInfo(BuildContext context) {
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
                  label: context.l10n.docDateOfBirth,
                  value: DateFormat.yMMMd().format(passport.mrz.dateOfBirth),
                  iconData: Icons.cake_outlined,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: InfoRow(
                  label: context.l10n.docExpiryDate,
                  value: DateFormat.yMMMd().format(passport.mrz.dateOfExpiry),
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
                  label: context.l10n.docCountry,
                  value: passport.mrz.country,
                  iconData: Icons.public_outlined,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: InfoRow(
                  label: context.l10n.docVersion,
                  value: passport.mrz.version.name,
                  iconData: Icons.info_outline,
                ),
              ),
            ],
          ),
          if (passport.mrz.optionalData.isNotEmpty) ...[
            const SizedBox(height: 12),
            InfoRow(
              label: context.l10n.docOptionalData,
              value: passport.mrz.optionalData,
              iconData: Icons.data_object_outlined,
            ),
          ],
        ],
      ),
    );
  }
}
