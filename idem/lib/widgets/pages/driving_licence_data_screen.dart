import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:intl/intl.dart';
import 'package:idem/utils/document_dates.dart';
import 'package:vcmrtd/vcmrtd.dart';
import 'package:idem/l10n/l10n.dart';
import 'package:idem/services/flow_step_plan.dart';
import 'package:idem/widgets/pages/data_screen_widgets/submit_to_proofing_session.dart';
import 'package:idem/widgets/guided/guided_widgets.dart';

import '../../widgets/pages/data_screen_widgets/guided_document_data_view.dart';

class DrivingLicenceDataScreen extends StatelessWidget {
  final DrivingLicenceData drivingLicence;
  final RawDocumentData drivingLicenceDataResult;
  final VoidCallback onBackPressed;

  /// Set when every step was already sent to the session as it completed -
  /// see [GuidedDocumentDataView.submittedTo].
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
  Widget build(BuildContext context) => _buildGuided(context);

  Widget _buildGuided(BuildContext context) {
    final g = context.guided;
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
      // Anything not JPEG2000 is decoded as a plain image.
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
}
