import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vcmrtd/internal.dart';
import 'package:vcmrtd/vcmrtd.dart';
import 'package:vcmrtdapp/widgets/common/scanned_mrz.dart';

final passportReaderProvider = StateNotifierProvider.autoDispose.family<DocumentReader<PassportData>, DocumentReaderState, ScannedPassportMRZ>((
  ref, scannedPassportMRZ) {
  final nfc = NfcProvider();
  final accessKey = DBAKey(scannedPassportMRZ.documentNumber, scannedPassportMRZ.dateOfBirth, scannedPassportMRZ.dateOfExpiry);
  final dgReader = DataGroupReader(nfc, DF1.PassportAID, accessKey);
  final parser = PassportParser();
  final docReader = DocumentReader(parser, dgReader, nfc, DocumentType.passport);

  // when the widget is no longer used, we want to cancel the reader
  ref.onDispose(docReader.cancel);
  return docReader;
});

final passportUrlProvider = StateProvider((ref) => '');

final drivingLicenceReaderProvider =
    StateNotifierProvider.autoDispose.family<DocumentReader<DrivingLicenceData>, DocumentReaderState, ScannedDriverLicenseMRZ>((ref, scannedDriverLicenceMRZ) {
      final nfc = NfcProvider();
      final accessKey = CanKey(scannedDriverLicenceMRZ.documentNumber, DocumentType.driverLicense);
      final dgReader = DataGroupReader(nfc, DF1.DriverAID, accessKey);
      final parser = DrivingLicenceParser();
      final docReader = DocumentReader(parser, dgReader, nfc, DocumentType.driverLicense);

      ref.onDispose(docReader.cancel);

      return docReader;
    });
