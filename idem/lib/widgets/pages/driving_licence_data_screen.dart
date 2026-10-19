import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:intl/intl.dart';
import 'package:idem/utils/document_dates.dart';
import 'package:vcmrtd/vcmrtd.dart';
import 'package:idem/l10n/l10n.dart';
import 'package:idem/services/flow_step_plan.dart';
import 'package:idem/widgets/pages/data_screen_widgets/submit_to_proofing_session.dart';
import 'package:idem/widgets/displays/passport_image_widget.dart';
import 'package:idem/widgets/guided/guided_widgets.dart';

import '../../widgets/pages/data_screen_widgets/document_data_view.dart';
import '../../widgets/pages/data_screen_widgets/guided_document_data_view.dart';

class DrivingLicenceDataScreen extends StatelessWidget {
  final DrivingLicenceData drivingLicence;
  final RawDocumentData drivingLicenceDataResult;
  final VoidCallback onBackPressed;

  /// Set when every step was already sent to the session as it completed -
  /// see [DocumentDataView.submittedTo].
  final String? submittedTo;
  final PendingStep pendingStep;

  /// Submits the session; set for [PendingStep.share].
  final Future<bool> Function()? onShare;

  /// Step badge numbers — default to vcmrtd's fixed 4-step sequence (this
  /// screen is always the last, step 4, there) so any caller not passing
  /// these explicitly keeps today's behaviour; routing.dart passes a
  /// session's actual FlowStepPlan values when a QR/deep-link flow governs
  /// the numbering.
  final int stepNumber;
  final int totalSteps;

  const DrivingLicenceDataScreen({
    super.key,
    required this.drivingLicence,
    required this.drivingLicenceDataResult,
    required this.onBackPressed,
    this.submittedTo,
    this.pendingStep = PendingStep.none,
    this.onShare,
    this.stepNumber = FlowStepPlan.defaultResultStep,
    this.totalSteps = FlowStepPlan.defaultTotalSteps,
  });

  @override
  Widget build(BuildContext context) {
    if (context.guided != null) return _buildGuided(context);
    final l10n = context.l10n;
    final licence = drivingLicence;
    return DocumentDataView(
      title: l10n.docDrivingLicenceDataTitle,
      document: licence,
      rawDocument: drivingLicenceDataResult,
      documentType: DocumentType.drivingLicence,
      submittedTo: submittedTo,
      pendingStep: pendingStep,
      onBackPressed: onBackPressed,
      onShare: onShare,
      stepNumber: stepNumber,
      totalSteps: totalSteps,
      children: [
        _buildPhotoSection(context, licence.photoImageData, licence.photoImageType),
        const SizedBox(height: 24),
        _buildSection(l10n.docPersonalInformation, [
          _buildDataRow(l10n.docSurname, licence.holderSurname),
          _buildDataRow(l10n.docOtherNames, licence.holderOtherName),
          _buildDataRow(l10n.docDateOfBirth, _formatDate(licence.dateOfBirth)),
          _buildDataRow(l10n.docPlaceOfBirth, licence.placeOfBirth),
        ]),
        const SizedBox(height: 24),
        _buildSection(l10n.docDocumentInformation, [
          _buildDataRow(l10n.docDocumentNumber, licence.documentNumber),
          _buildDataRow(l10n.docIssuingMemberState, licence.issuingMemberState),
          _buildDataRow(l10n.docIssuingAuthority, licence.issuingAuthority),
          _buildDataRow(l10n.docDateOfIssue, _formatDate(licence.dateOfIssue)),
          _buildDataRow(l10n.docDateOfExpiry, _formatDate(licence.dateOfExpiry)),
        ]),
        if (licence.categories.isNotEmpty) ...[
          const SizedBox(height: 24),
          _buildSection(l10n.docCategories, [
            for (final category in licence.categories) _buildCategoryCard(context, category),
          ]),
        ],
      ],
    );
  }

  Widget _buildGuided(BuildContext context) {
    final g = context.guided!;
    final l10n = context.l10n;
    final licence = drivingLicence;
    final name = '${licence.holderOtherName} ${licence.holderSurname}'.trim();
    // The same "15 Apr 2034" as the passport and ID card results.
    final format = DateFormat(documentDatePattern, l10n.localeName);
    String date(String value) {
      final parsed = parseDrivingLicenceDate(value);
      return parsed == null ? value : format.format(parsed);
    }

    return GuidedDocumentDataView(
      document: licence,
      rawDocument: drivingLicenceDataResult,
      documentType: DocumentType.drivingLicence,
      submittedTo: submittedTo,
      pendingStep: pendingStep,
      onBackPressed: onBackPressed,
      onShare: onShare,
      readTitle: l10n.dataViewDrivingLicenceRead,
      photoImageData: licence.photoImageData,
      // Like the classic screen: anything not JPEG2000 is decoded as a plain image.
      photoImageType: licence.photoImageType ?? ImageType.jpeg,
      holderName: name.isEmpty ? l10n.idDocumentDrivingLicence : name,
      subtitle: l10n.dataViewSubtitle(DocumentType.drivingLicence.name, licence.issuingMemberState),
      details: [
        GuidedDetail(l10n.dataViewDateOfBirth, date(licence.dateOfBirth)),
        GuidedDetail(l10n.dataViewPlaceOfBirth, licence.placeOfBirth),
        GuidedDetail(l10n.dataViewDocumentNumber, licence.documentNumber, mono: true),
        GuidedDetail(l10n.dataViewIssuedBy, licence.issuingAuthority),
        GuidedDetail(l10n.dataViewValidUntil, date(licence.dateOfExpiry)),
      ],
      extra: [
        if (licence.categories.isNotEmpty) ...[
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: GuidedHeading(
              l10n.docCategories,
              style: g.heading(15, weight: FontWeight.w600, color: g.slate),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final category in licence.categories)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: g.border),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(category.category, style: g.heading(15)),
                      Text(
                        l10n.dataViewCategoryUntil(date(category.dateOfExpiry)),
                        style: TextStyle(fontSize: 12, color: g.bodyText),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  /// The licence photo; a JPEG2000 one (which Image.memory can't decode)
  /// is converted first.
  Widget _buildPhotoSection(BuildContext context, Uint8List imageData, ImageType? imageType) {
    return Center(
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: CupertinoColors.systemGrey4, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: imageType == ImageType.jpeg2000
              ? SizedBox(
                  width: 200,
                  height: 250,
                  child: PassportImageWidget(imageData: imageData, imageType: imageType),
                )
              : Image.memory(
                  imageData,
                  width: 200,
                  height: 250,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 200,
                      height: 250,
                      color: CupertinoColors.systemGrey6,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(CupertinoIcons.photo, size: 48, color: CupertinoColors.systemGrey),
                            const SizedBox(height: 8),
                            Text(
                              context.l10n.docUnableToLoadPhoto,
                              style: const TextStyle(color: CupertinoColors.systemGrey),
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
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildCategoryCard(BuildContext context, DrivingLicenceCategory category) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CupertinoColors.systemGrey4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                context.l10n.docCategory,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: CupertinoColors.systemGrey),
              ),
              const SizedBox(width: 8),
              Text(
                category.category,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: CupertinoColors.systemGrey),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildDataRow(context.l10n.docCategoryDateOfIssue, category.dateOfIssue),
          _buildDataRow(context.l10n.docCategoryDateOfExpiry, category.dateOfExpiry),
        ],
      ),
    );
  }

  Widget _buildDataRow(String label, String value) {
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
          Expanded(child: Text(value, style: const TextStyle(fontSize: 16))),
        ],
      ),
    );
  }

  /// DDMMYYYY as DD/MM/YYYY; anything else as it is.
  String _formatDate(String date) {
    if (date.length != 8) return date;
    final day = date.substring(0, 2);
    final month = date.substring(2, 4);
    final year = date.substring(4, 8);
    return '$day/$month/$year';
  }
}
