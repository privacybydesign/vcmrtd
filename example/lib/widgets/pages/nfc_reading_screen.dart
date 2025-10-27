import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vcmrtd/vcmrtd.dart';
import 'package:flutter/material.dart';
import 'package:vcmrtdapp/providers/active_authenticiation_provider.dart';
import 'package:vcmrtdapp/providers/passport_issuer_provider.dart';
import 'package:vcmrtdapp/providers/passport_reader_provider.dart';
import 'package:vcmrtdapp/widgets/common/animated_nfc_status_widget.dart';
import 'package:vcmrtdapp/widgets/pages/nfc_guidance_screen.dart';

class NfcReadingRouteParams {
  final String docNumber;
  final DateTime dateOfBirth;
  final DateTime dateOfExpiry;
  final String? countryCode;

  NfcReadingRouteParams({
    required this.docNumber,
    required this.dateOfBirth,
    required this.dateOfExpiry,
    this.countryCode,
  });

  Map<String, String> toQueryParams() {
    return {
      'doc_number': docNumber,
      'date_of_birth': dateOfBirth.toIso8601String(),
      'date_of_expiry': dateOfExpiry.toIso8601String(),
      if (countryCode != null) 'country_code': countryCode!,
    };
  }

  static NfcReadingRouteParams fromQueryParams(Map<String, String> params) {
    return NfcReadingRouteParams(
      docNumber: params['doc_number']!,
      dateOfBirth: DateTime.parse(params['date_of_birth']!),
      dateOfExpiry: DateTime.parse(params['date_of_expiry']!),
      countryCode: params['country_code'],
    );
  }
}

class NfcReadingScreen extends ConsumerStatefulWidget {
  const NfcReadingScreen({required this.params, required this.onCancel, required this.onSuccess, super.key});

  final NfcReadingRouteParams params;

  final Function() onCancel;
  final Function(PassportDataResult, MrtdData) onSuccess;

  @override
  ConsumerState<NfcReadingScreen> createState() => _NfcReadingScreenState();
}

class _NfcReadingScreenState extends ConsumerState<NfcReadingScreen> {
  @override
  Widget build(BuildContext context) {
    final passportState = ref.watch(passportReaderProvider);

    if (passportState case PassportReaderSuccess(result: final result, mrtdData: final mrtdData)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onSuccess(result, mrtdData));
    }

    if (passportState is PassportReaderPending) {
      return NfcGuidanceScreen(onStartReading: startReading, onBack: context.pop);
    }

    return Scaffold(
      appBar: AppBar(title: Text('Scan passport')),
      body: Center(
        child: AnimatedNFCStatusWidget(
          state: _mapState(passportState),
          message: '',
          progress: progressForState(passportState),
          onRetry: retry,
          onCancel: cancel,
        ),
      ),
    );
  }

  NFCReadingState _mapState(PassportReaderState state) {
    return switch (state) {
      PassportReaderPending() => NFCReadingState.idle,
      PassportReaderCancelled() => NFCReadingState.error,
      PassportReaderCancelling() => NFCReadingState.cancelling,
      PassportReaderFailed() => NFCReadingState.error,
      PassportReaderConnecting() => NFCReadingState.connecting,
      PassportReaderReadingCardAccess() => NFCReadingState.authenticating,
      PassportReaderAuthenticating() => NFCReadingState.authenticating,
      PassportReaderReadingPassportData() => NFCReadingState.reading,
      PassportReaderSecurityVerification() => NFCReadingState.authenticating,
      PassportReaderSuccess() => NFCReadingState.success,
      _ => throw Exception('unexpected state: $state'),
    };
  }

  Future<void> cancel() async {
    await ref.read(passportReaderProvider.notifier).cancel();
  }

  Future<void> retry() async {
    ref.read(passportReaderProvider.notifier).reset();
    startReading();
  }

  Future<void> startReading() async {
    try {
      NonceAndSessionId? nonceAndSessionId;

      if (ref.read(activeAuthenticationProvider)) {
        nonceAndSessionId = await ref.read(passportIssuerProvider).startSessionAtPassportIssuer();
      }

      await ref
          .read(passportReaderProvider.notifier)
          .readWithMRZ(
            iosNfcMessages: _getTranslatedIosNfcMessages(),
            documentNumber: widget.params.docNumber,
            birthDate: widget.params.dateOfBirth,
            expiryDate: widget.params.dateOfExpiry,
            countryCode: widget.params.countryCode,
            activeAuthenticationParams: nonceAndSessionId,
          );
    } catch (e) {
      debugPrint('failed to read passport: $e');
    }
  }

  IosNfcMessages _getTranslatedIosNfcMessages() {
    String progressFormatter(double progress) {
      const numStages = 10;
      final prog = (progress * numStages).toInt();
      return '🟢' * prog + '⚪️' * (numStages - prog);
    }

    return IosNfcMessages(
      progressFormatter: progressFormatter,
      holdNearPhotoPage: 'Hold your phone close to photo',
      cancelling: 'Cancelling...',
      cancelled: 'Cancelled',
      connecting: 'Connecting...',
      readingCardAccess: 'Reading EF.CardAccess',
      authenticating: 'Authenticating',
      readingPassportData: 'Reading passport data',
      cancelledByUser: 'Session cancelled by user',
      performingSecurityVerification: 'Performing security verification...',
      completedSuccessfully: 'Success!',
      timeoutWaitingForTag: 'Waiting for tag...',
      failedToInitiateSession: 'Failed to initiate session',
      tagLostTryAgain: 'Tag lost, try again.',
    );
  }
}
