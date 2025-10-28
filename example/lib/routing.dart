import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vcmrtd/vcmrtd.dart';
import 'package:vcmrtdapp/widgets/pages/document_selection_screen.dart';
import 'package:vcmrtdapp/widgets/pages/driving_licence_data_screen.dart';
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
            onMrzScanned: (result) {
              context.pushNfcReadingScreen(
                NfcReadingRouteParams(
                  documentType: params.documentType,
                  docNumber: result.documentNumber,
                  dateOfBirth: result.birthDate,
                  dateOfExpiry: result.expiryDate,
                ),
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
            onMrzEntered: (mrz) {},
            onDataEntered: (String docNumber, DateTime dob, DateTime expiry) {
              context.pushNfcReadingScreen(
                NfcReadingRouteParams(
                  docNumber: docNumber,
                  dateOfBirth: dob,
                  dateOfExpiry: expiry,
                  documentType: params.documentType,
                ),
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
            onSuccess: (result, data) {
              context.go('/result', extra: {'result': result, 'data': data, 'document_type': params.documentType});
            },
          );
        },
      ),
      GoRoute(
        path: '/result',
        builder: (context, state) {
          final s = state.extra as Map<String, dynamic>;
          final ty = s['document_type'] as DocumentType;

          return switch (ty) {
            DocumentType.passport => PassportDataScreen(
              mrtdData: s['data'] as MrtdData,
              passportDataResult: s['result'] as PassportDataResult,
              onBackPressed: () => context.go('/select_doc_type'),
            ),
            DocumentType.driverLicense => DrivingLicenceDataScreen(
              mrtdData: s['data'] as MrtdData,
              onBackPressed: () => context.go('/select_doc_type'),
            ),
          };
        },
      ),
    ],
  );
}
