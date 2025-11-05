import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vcmrtd/internal.dart';
import 'package:vcmrtd/vcmrtd.dart';

final passportReaderProvider = StateNotifierProvider.autoDispose<DocumentReader<PassportData>, DocumentReaderState>((
  ref,
) {
  final nfc = NfcProvider();
  final dgReader = DataGroupReader(nfc, DF1.PassportAID);
  final parser = PassportParser();
  final docReader = DocumentReader(parser, dgReader, nfc);

  // when the widget is no longer used, we want to cancel the reader
  ref.onDispose(docReader.cancel);
  return docReader;
});

final passportUrlProvider = StateProvider((ref) => '');

final drivingLicenceReaderProvider =
    StateNotifierProvider.autoDispose<DocumentReader<DrivingLicenceData>, DocumentReaderState>((ref) {
      final nfc = NfcProvider();
      final dgReader = DataGroupReader(nfc, DF1.DriverAID);
      final parser = DrivingLicenceParser();
      final docReader = DocumentReader(parser, dgReader, nfc);

      ref.onDispose(docReader.cancel);

      return docReader;
    });
