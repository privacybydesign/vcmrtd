import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vcmrtd/internal.dart';
import 'package:vcmrtd/vcmrtd.dart';

final passportReaderProvider = StateNotifierProvider.autoDispose<DocumentReader<PassportData>, DocumentReaderState>((ref) {
  final nfc = NfcProvider();
  final reader = DataGroupReader(nfc, DF1.PassportAID);
  final parser = PassportParser();
  final r = DocumentReader(parser,reader,nfc);

  // when the widget is no longer used, we want to cancel the reader
  ref.onDispose(r.cancel);
  return r;
});

final passportUrlProvider = StateProvider((ref) => '');
