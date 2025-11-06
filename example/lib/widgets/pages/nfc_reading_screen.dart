import 'package:vcmrtd/vcmrtd.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:vcmrtdapp/providers/active_authenticiation_provider.dart';
import 'package:vcmrtdapp/providers/passport_issuer_provider.dart';
import 'package:vcmrtdapp/widgets/common/animated_nfc_status_widget.dart';
import 'package:vcmrtdapp/widgets/pages/nfc_guidance_screen.dart';

import '../../providers/reader_providers.dart';
import '../common/scanned_mrz.dart';

class NfcReadingRouteParams {
  final ScannedMRZ scannedMRZ;
  final DocumentType documentType;

  NfcReadingRouteParams({required this.scannedMRZ, required this.documentType});

  Map<String, String> toQueryParams() {
    final baseParams = {
      'doc_number': scannedMRZ.documentNumber,
      'country_code': scannedMRZ.countryCode,
      'document_type': switch (documentType) {
        DocumentType.passport => 'passport',
        DocumentType.driverLicense => 'drivers_license',
      },
    };
    if (scannedMRZ is ScannedPassportMRZ) {
      final passport = scannedMRZ as ScannedPassportMRZ;
      baseParams['date_of_birth'] = passport.dateOfBirth.toIso8601String();
      baseParams['date_of_expiry'] = passport.dateOfExpiry.toIso8601String();
    }
    return baseParams;
  }

  static NfcReadingRouteParams fromQueryParams(Map<String, String> params) {
    final docType = params['document_type']!;
    final documentType = switch (docType) {
      'passport' => DocumentType.passport,
      'drivers_license' => DocumentType.driverLicense,
      _ => throw Exception('unexpected document type: $docType'),
    };

    final scannedMRZ = switch (documentType) {
      DocumentType.passport => ScannedPassportMRZ(
        documentNumber: params['doc_number']!,
        countryCode: params['country_code']!,
        dateOfBirth: DateTime.parse(params['date_of_birth']!),
        dateOfExpiry: DateTime.parse(params['date_of_expiry']!),
      ),
      DocumentType.driverLicense => ScannedDriverLicenseMRZ(
        documentNumber: params['doc_number']!,
        countryCode: params['country_code']!,
      ),
    };

    return NfcReadingRouteParams(scannedMRZ: scannedMRZ, documentType: documentType);
  }
}

class NfcReadingScreen extends ConsumerStatefulWidget {
  const NfcReadingScreen({required this.params, required this.onCancel, required this.onSuccess, super.key});

  final NfcReadingRouteParams params;

  final Function() onCancel;
  final Function(DocumentData, PassportDataResult) onSuccess;

  @override
  ConsumerState<NfcReadingScreen> createState() => _NfcReadingScreenState();
}

class _NfcReadingScreenState extends ConsumerState<NfcReadingScreen> {
  late ScannedMRZ scannedMRZ;
  @override
  Widget build(BuildContext context) {
    scannedMRZ = widget.params.scannedMRZ;

    final readerProvider = widget.params.documentType == DocumentType.passport
        ? passportReaderProvider
        : drivingLicenceReaderProvider;

    final state = ref.watch(readerProvider(scannedMRZ));

    if (state is DocumentReaderPending) {
      return NfcGuidanceScreen(onStartReading: startReading, onBack: context.pop);
    }

    final title = widget.params.documentType == DocumentType.passport ? 'Scan passport' : 'Scan driving license';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: AnimatedNFCStatusWidget(
          state: _mapState(state),
          message: '',
          progress: progressForState(state),
          onRetry: retry,
          onCancel: cancel,
        ),
      ),
    );
  }

  NFCReadingState _mapState(DocumentReaderState state) {
    return switch (state) {
      DocumentReaderPending() => NFCReadingState.idle,
      DocumentReaderCancelled() => NFCReadingState.error,
      DocumentReaderCancelling() => NFCReadingState.cancelling,
      DocumentReaderFailed() => NFCReadingState.error,
      DocumentReaderConnecting() => NFCReadingState.connecting,
      DocumentReaderReadingCardAccess() => NFCReadingState.authenticating,
      DocumentReaderAuthenticating() => NFCReadingState.authenticating,
      DocumentReaderReadingDataGroup() ||
      DocumentReaderReadingSOD() ||
      DocumentReaderReadingCOM() => NFCReadingState.reading,
      DocumentReaderActiveAuthentication() => NFCReadingState.authenticating,
      DocumentReaderSuccess() => NFCReadingState.success,
      _ => throw Exception('unexpected state: $state'),
    };
  }

  Future<void> cancel() async {
    final readerProvider = widget.params.documentType == DocumentType.passport
        ? passportReaderProvider
        : drivingLicenceReaderProvider;

    await ref.read(readerProvider(scannedMRZ).notifier).cancel();
  }

  Future<void> retry() async {
    final readerProvider = widget.params.documentType == DocumentType.passport
        ? passportReaderProvider
        : drivingLicenceReaderProvider;

    ref.read(readerProvider(scannedMRZ).notifier).reset();
    startReading();
  }

  Future<void> startReading() async {
    try {
      final readerProvider = widget.params.documentType == DocumentType.passport
          ? passportReaderProvider
          : drivingLicenceReaderProvider;

      NonceAndSessionId? nonceAndSessionId;

      if (ref.read(activeAuthenticationProvider)) {
        nonceAndSessionId = await ref.read(passportIssuerProvider).startSessionAtPassportIssuer();
      }
      final result = await ref
          .read(readerProvider(scannedMRZ).notifier)
          .readDocument(
            iosNfcMessages: _createIosNfcMessageMapper(),
            countryCode: widget.params.scannedMRZ.countryCode,
            activeAuthenticationParams: nonceAndSessionId,
          );
      if (result != null) {
        final (document, passportDataResult) = result;
        widget.onSuccess(document, passportDataResult);
      }
    } catch (e) {
      debugPrint('failed to read document: $e');
    }
  }

  IosNfcMessageMapper _createIosNfcMessageMapper() {
    String progressFormatter(double progress) {
      const numStages = 10;
      final prog = (progress * numStages).toInt();
      return '🟢' * prog + '⚪️' * (numStages - prog);
    }

    final docName = widget.params.documentType == DocumentType.passport ? 'passport' : 'driving license';

    return (state) {
      final progress = progressFormatter(progressForState(state));

      final message = switch (state) {
        DocumentReaderPending() => 'Hold your phone close to $docName',
        DocumentReaderCancelled() => 'Session cancelled by user',
        DocumentReaderCancelling() => 'Cancelling...',
        DocumentReaderFailed() => 'Tag lost, try again.',
        DocumentReaderConnecting() => 'Connecting...',
        DocumentReaderReadingCOM() => 'Reading Ef.COM',
        DocumentReaderReadingCardAccess() => 'Reading Ef.CardAccess',
        DocumentReaderAuthenticating() => 'Authenticating',
        DocumentReaderReadingDataGroup() => 'Reading $docName data',
        DocumentReaderReadingSOD() => 'Reading Ef.SOD',
        DocumentReaderActiveAuthentication() => 'Performing security verification...',
        DocumentReaderSuccess() => 'Success!',
        _ => '',
      };

      return '$progress\n$message';
    };
  }
}
