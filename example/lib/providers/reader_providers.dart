import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vcmrtd/internal.dart';
import 'package:vcmrtd/vcmrtd.dart';
import 'package:vcmrtdapp/widgets/common/scanned_mrz.dart';

final passportReaderProvider = NotifierProvider.autoDispose
    .family<DocumentReader<PassportData>, DocumentReaderState, ScannedPassportMRZ>((scannedPassportMRZ) {
      final nfc = NfcProvider();

      final bacAccessKey = DBAKey(
        scannedPassportMRZ.documentNumber,
        scannedPassportMRZ.dateOfBirth,
        scannedPassportMRZ.dateOfExpiry,
      );

      final paceAccessKey = DBAKey(
        scannedPassportMRZ.documentNumber,
        scannedPassportMRZ.dateOfBirth,
        scannedPassportMRZ.dateOfExpiry,
        paceMode: true,
      );

      final dgReader = DataGroupReader(nfc, DF1.PassportAID, bacAccessKey: bacAccessKey, paceAccessKey: paceAccessKey);
      final parser = PassportParser();
      final docReader = DocumentReader(
        documentParser: parser,
        dataGroupReader: dgReader,
        nfc: nfc,
        config: DocumentReaderConfig(
          readIfAvailable: {
            DataGroups.dg1,
            DataGroups.dg2,
            DataGroups.dg5,
            DataGroups.dg6,
            DataGroups.dg7,
            DataGroups.dg8,
            DataGroups.dg9,
            DataGroups.dg10,
            DataGroups.dg11,
            DataGroups.dg12,
            DataGroups.dg13,
            DataGroups.dg14,
            DataGroups.dg15,
            DataGroups.dg16,
          },
        ),
      );

      return docReader;
    });

final drivingLicenceReaderProvider = NotifierProvider.autoDispose
    .family<DocumentReader<DrivingLicenceData>, DocumentReaderState, ScannedDriverLicenseMRZ>((
      scannedDriverLicenceMRZ,
    ) {
      final nfc = NfcProvider();
      final AccessKey accessKey;
      final bool enableBac;
      if (scannedDriverLicenceMRZ.version == '1') {
        accessKey = BapKey(
          '${scannedDriverLicenceMRZ.configuration}${scannedDriverLicenceMRZ.countryCode}${scannedDriverLicenceMRZ.version}${scannedDriverLicenceMRZ.documentNumber}${scannedDriverLicenceMRZ.randomData}',
        );
        enableBac = true;
      } else {
        accessKey = CanKey(scannedDriverLicenceMRZ.documentNumber, scannedDriverLicenceMRZ.documentType);
        enableBac = false;
      }

      final dgReader = DataGroupReader(
        nfc,
        DF1.DriverAID,
        paceAccessKey: accessKey,
        bacAccessKey: enableBac ? accessKey : null,
      );

      final parser = DrivingLicenceParser(failDg1CategoriesGracefully: false);
      final docReader = DocumentReader(
        documentParser: parser,
        dataGroupReader: dgReader,
        nfc: nfc,
        config: DocumentReaderConfig(
          // Skipping DG5 due to bad signature image quality
          readIfAvailable: {DataGroups.dg1, DataGroups.dg6, DataGroups.dg11, DataGroups.dg12, DataGroups.dg13},
        ),
      );

      return docReader;
    });
