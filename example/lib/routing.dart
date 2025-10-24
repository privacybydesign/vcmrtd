import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vcmrtd/vcmrtd.dart';
import 'package:vcmrtdapp/widgets/pages/data_screen.dart';
import 'package:vcmrtdapp/widgets/pages/document_selection_screen.dart';
import 'package:vcmrtdapp/widgets/pages/manual_entry_screen.dart';
import 'package:vcmrtdapp/widgets/pages/nfc_reading_screen.dart';
import 'package:vcmrtdapp/widgets/pages/scanner_wrapper.dart';

extension CustomRouteExtensions on BuildContext {
  void pushNfcReadingScreen(NfcReadingRouteParams params) {
    final path = Uri(path: '/nfc_reading', queryParameters: params.toQueryParams());
    push(path.toString());
  }
}

GoRouter createRouter() {
  return GoRouter(
    initialLocation: '/select_doc_type',
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
              context.push('/result');
            },
          );
        },
      ),
      GoRoute(
        path: '/manual_entry',
        builder: (context, state) {
          return ManualEntryScreen(
            onBack: context.pop,
            onDataEntered: (String docNumber, DateTime dob, DateTime expiry) {
              context.pushNfcReadingScreen(
                NfcReadingRouteParams(docNumber: docNumber, dateOfBirth: dob, dateOfExpiry: expiry),
              );
            },
          );
        },
      ),
      GoRoute(
        path: '/result',
        builder: (context, state) {
          return DataScreen(
            onBackPressed: () => context.go('/select_doc_type'),
            mrtdData: MrtdData(),
            passportDataResult: PassportDataResult(dataGroups: {}, efSod: ''),
          );
        },
      ),
    ],
  );
}
