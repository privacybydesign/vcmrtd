import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vcmrtd/vcmrtd.dart';
import 'package:vcmrtdapp/widgets/pages/document_selection_screen.dart';
import 'package:vcmrtdapp/widgets/pages/driving_licence_data_screen.dart';
import 'package:vcmrtdapp/widgets/pages/facetec_capture_screen.dart';
import 'package:vcmrtdapp/widgets/pages/manual_entry_screen.dart';
import 'package:vcmrtdapp/widgets/pages/nfc_reading_screen.dart';
import 'package:vcmrtdapp/widgets/pages/passport_data_screen.dart';
import 'package:vcmrtdapp/widgets/pages/scanner_wrapper.dart';

extension CustomRouteExtensions on BuildContext {
  void pushNfcReadingScreen(NfcReadingRouteParams params) {
    final path = Uri(path: '/nfc_reading', queryParameters: params.toQueryParams());
    push(path.toString());
  }

  void pushMrzReaderScreen(MrzReaderRouteParams params) {
    final path = Uri(path: '/mrz_reader', queryParameters: params.toQueryParams());
    push(path.toString());
  }

  void pushManualEntryScreen(ManualEntryRouteParams params) {
    final path = Uri(path: '/manual_entry', queryParameters: params.toQueryParams());
    push(path.toString());
  }
}

final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

GoRouter createRouter() {
  return GoRouter(
    initialLocation: '/select_doc_type',
    observers: [routeObserver],
    routes: [
      GoRoute(
        path: '/select_doc_type',
        builder: (context, state) {
          return DocumentTypeSelectionScreen(
            onDocumentTypeSelected: (docType) {
              context.pushMrzReaderScreen(MrzReaderRouteParams(documentType: docType));
            },
          );
        },
      ),
      GoRoute(
        path: '/mrz_reader',
        builder: (context, state) {
          final params = MrzReaderRouteParams.fromQueryParams(state.uri.queryParameters);
          return ScannerWrapper(
            documentType: params.documentType,
            onMrzScanned: (result) {
              context.pushNfcReadingScreen(
                NfcReadingRouteParams(scannedMRZ: result, documentType: params.documentType),
              );
            },
            onManualEntry: () {
              context.pushManualEntryScreen(ManualEntryRouteParams(documentType: params.documentType));
            },
            onCancel: context.pop,
            onBack: context.pop,
          );
        },
      ),
      GoRoute(
        path: '/manual_entry',
        builder: (context, state) {
          final params = ManualEntryRouteParams.fromQueryParams(state.uri.queryParameters);
          return ManualEntryScreen(
            documentType: params.documentType,
            onBack: context.pop,
            onManualEntryComplete: (scannedMrz) {
              context.pushNfcReadingScreen(
                NfcReadingRouteParams(scannedMRZ: scannedMrz, documentType: params.documentType),
              );
            },
          );
        },
      ),
      GoRoute(
        path: '/nfc_reading',
        builder: (context, state) {
          final params = NfcReadingRouteParams.fromQueryParams(state.uri.queryParameters);
          return NfcReadingScreen(
            params: params,
            onCancel: context.pop,
            onSuccess: (document, result) {
              // Extract document photo for face verification
              final documentImage = switch (document) {
                PassportData passport => passport.photoImageData,
                DrivingLicenceData licence => licence.photoImageData,
                _ => null,
              };

              // Navigate to FaceTec verification
              context.go(
                '/facetec_verification',
                extra: {
                  'document': document,
                  'result': result,
                  'document_type': params.documentType,
                  'documentImage': documentImage,
                },
              );
            },
          );
        },
      ),
      GoRoute(
        path: '/facetec_verification',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          final documentImage = extra['documentImage'];

          return FaceTecCaptureScreen(
            documentImage: documentImage != null
                ? (documentImage is Uint8List
                    ? documentImage
                    : Uint8List.fromList(documentImage as List<int>))
                : null,
            onVerificationSuccess: (matchScore) {
              // Face verification succeeded, navigate to result
              context.go(
                '/result',
                extra: {
                  'document': extra['document'],
                  'result': extra['result'],
                  'document_type': extra['document_type'],
                  'faceMatchScore': matchScore,
                },
              );
            },
            onBack: () => context.go('/select_doc_type'),
            onSkip: () {
              // Allow skipping face verification
              context.go(
                '/result',
                extra: {
                  'document': extra['document'],
                  'result': extra['result'],
                  'document_type': extra['document_type'],
                },
              );
            },
          );
        },
      ),
      GoRoute(
        path: '/result',
        builder: (context, state) {
          final s = state.extra as Map<String, dynamic>;
          final ty = s['document_type'] as DocumentType;
          final result = s['result'] as RawDocumentData;

          return switch (ty) {
            DocumentType.passport || DocumentType.identityCard => PassportDataScreen(
              passport: s['document'] as PassportData,
              passportDataResult: result,
              onBackPressed: () => context.go('/select_doc_type'),
            ),
            DocumentType.drivingLicence => DrivingLicenceDataScreen(
              drivingLicence: s['document'] as DrivingLicenceData,
              drivingLicenceDataResult: result,
              onBackPressed: () => context.go('/select_doc_type'),
            ),
          };
        },
      ),
    ],
  );
}
