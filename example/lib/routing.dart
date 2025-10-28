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
            onPassportSelected: () {
              context.push('/mrz_reader');
            },
            onDrivingLicenceSelected: () {
              context.push('/mrz_reader');
            },
          );
        },
      ),
      GoRoute(
        path: '/mrz_reader',
        builder: (context, state) {
          return ScannerWrapper(
            onMrzScanned: (result) {
              context.pushNfcReadingScreen(
                NfcReadingRouteParams(
                  documentType: DocumentType.passport,
                  docNumber: result.documentNumber,
                  dateOfBirth: result.birthDate,
                  dateOfExpiry: result.expiryDate,
                ),
              );
            },
            onManualEntry: () {
              context.push('/manual_entry');
            },
            onCancel: context.pop,
            onBack: context.pop,
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
              context.go('/result', extra: {'result': result, 'data': data});
            },
          );
        },
      ),
      GoRoute(
        path: '/manual_entry',
        builder: (context, state) {
          final docType = DocumentType.passport;
          return ManualEntryScreen(
            documentType: docType,
            onBack: context.pop,
            onMrzEntered: (mrz) {},
            onDataEntered: (String docNumber, DateTime dob, DateTime expiry) {
              context.pushNfcReadingScreen(
                NfcReadingRouteParams(
                  docNumber: docNumber,
                  dateOfBirth: dob,
                  dateOfExpiry: expiry,
                  documentType: docType,
                ),
              );
            },
          );
        },
      ),
      GoRoute(
        path: '/result',
        builder: (context, state) {
          final s = state.extra as Map<String, dynamic>;
          final ty = s['type'] as DocumentType;

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
