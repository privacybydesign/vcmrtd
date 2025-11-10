import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vcmrtd/internal.dart';
import 'package:vcmrtd/vcmrtd.dart';
import 'package:vcmrtdapp/widgets/common/scanned_mrz.dart';

final passportReaderProvider = StateNotifierProvider.autoDispose
    .family<DocumentReader<PassportData>, DocumentReaderState, ScannedPassportMRZ>((ref, scannedPassportMRZ) {
      final nfc = NfcProvider();
      final accessKey = DBAKey(
        scannedPassportMRZ.documentNumber,
        scannedPassportMRZ.dateOfBirth,
        scannedPassportMRZ.dateOfExpiry,
      );
      final dgReader = DataGroupReader(nfc, DF1.PassportAID, accessKey);
      final parser = PassportParser();
      final docReader = DocumentReader(
        parser: parser,
        dgReader: dgReader,
        nfc: nfc,
        config: DocumentReaderConfig(readIfAvailable: {DataGroups.dg1, DataGroups.dg2, DataGroups.dg15}),
      );

      ref.onDispose(docReader.cancel);
      return docReader;
    });

final passportUrlProvider = StateProvider((ref) => '');

final drivingLicenceReaderProvider = StateNotifierProvider.autoDispose
    .family<DocumentReader<DrivingLicenceData>, DocumentReaderState, ScannedDriverLicenseMRZ>((
      ref,
      scannedDriverLicenceMRZ,
    ) {
      final nfc = NfcProvider();
      final accessKey = CanKey(scannedDriverLicenceMRZ.documentNumber, DocumentType.driverLicense);
      final dgReader = DataGroupReader(nfc, DF1.DriverAID, accessKey);
      final parser = DrivingLicenceParser();
      final docReader = DocumentReader(
        parser: parser,
        dgReader: dgReader,
        nfc: nfc,
        config: DocumentReaderConfig(readIfAvailable: {}),
      );

      ref.onDispose(docReader.cancel);
      return docReader;
    });
