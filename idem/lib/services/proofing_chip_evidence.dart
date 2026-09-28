import 'dart:io' show Platform;

import 'package:package_info_plus/package_info_plus.dart';
import 'package:vcmrtd/vcmrtd.dart';

import 'proofing_session_client.dart';

/// What a chip read contributes to an identity-proofing session, built the
/// same way for the nfc_read step submission (routing.dart's /nfc_reading)
/// and the flow-less single-shot result (the document data screens) - only
/// the document type decides how.
class ProofingChipEvidence {
  final ProofingDocumentInfo document;
  final ProofingPhotoInfo photo;
  final ProofingMrtdEvidence mrtdEvidence;

  const ProofingChipEvidence({required this.document, required this.photo, required this.mrtdEvidence});

  factory ProofingChipEvidence.from(DocumentData document, RawDocumentData raw, DocumentType documentType) =>
      switch (documentType) {
        DocumentType.passport || DocumentType.identityCard => ProofingChipEvidence(
          document: ProofingDocumentInfo.fromPassportData(document as PassportData),
          photo: ProofingPhotoInfo.fromImage(document.photoImageData, document.photoImageType),
          mrtdEvidence: ProofingMrtdEvidence.fromRawDocumentData(raw, aaKeyDataGroup: 'DG15', documentType: 'icao'),
        ),
        DocumentType.drivingLicence => ProofingChipEvidence(
          document: ProofingDocumentInfo.fromDrivingLicenceData(document as DrivingLicenceData),
          photo: ProofingPhotoInfo.fromImage(document.photoImageData, document.photoImageType),
          mrtdEvidence: ProofingMrtdEvidence.fromRawDocumentData(
            raw,
            aaKeyDataGroup: 'DG13',
            documentType: 'eu_driving_licence',
          ),
        ),
      };
}

/// This app's build and platform, sent along with a submission.
Future<ProofingDeviceInfo> currentProofingDeviceInfo() async {
  final packageInfo = await PackageInfo.fromPlatform();
  return ProofingDeviceInfo(
    appVersion: '${packageInfo.version}+${packageInfo.buildNumber}',
    devicePlatform: Platform.operatingSystem,
  );
}
