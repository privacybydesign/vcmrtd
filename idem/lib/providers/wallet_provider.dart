import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vcmrtd/vcmrtd.dart';

/// A compact summary of a scanned document, shown in the in-app "wallet".
///
/// This is example-app-only state: it lives purely in memory in
/// [WalletNotifier], so it is gone the moment the app restarts. There is no
/// real wallet or issuance backend behind it.
class WalletCard {
  final String id;
  final DocumentType documentType;
  final String holderName;
  final String? documentNumber;
  final Uint8List photoImageData;
  final ImageType? photoImageType;
  final DateTime addedAt;

  static int _idCounter = 0;

  WalletCard({
    required this.id,
    required this.documentType,
    required this.holderName,
    required this.documentNumber,
    required this.photoImageData,
    required this.photoImageType,
    required this.addedAt,
  });

  factory WalletCard.fromDocument(DocumentData document, DocumentType documentType) {
    String holderName;
    String? documentNumber;
    Uint8List photo;
    ImageType? photoType;
    switch (documentType) {
      case DocumentType.passport:
      case DocumentType.identityCard:
        final passport = document as PassportData;
        holderName = passport.displayName;
        documentNumber = passport.mrz.documentNumber;
        photo = passport.photoImageData;
        photoType = passport.photoImageType;
      case DocumentType.drivingLicence:
        final licence = document as DrivingLicenceData;
        holderName = '${licence.holderOtherName} ${licence.holderSurname}'.trim();
        documentNumber = licence.documentNumber;
        photo = licence.photoImageData;
        photoType = licence.photoImageType;
    }
    return WalletCard(
      id: '${DateTime.now().microsecondsSinceEpoch}-${_idCounter++}',
      documentType: documentType,
      holderName: holderName,
      documentNumber: documentNumber,
      photoImageData: photo,
      photoImageType: photoType,
      addedAt: DateTime.now(),
    );
  }
}

class WalletNotifier extends Notifier<List<WalletCard>> {
  @override
  List<WalletCard> build() => [];

  void add(WalletCard card) => state = [...state, card];

  void remove(String id) => state = state.where((c) => c.id != id).toList();
}

final walletProvider = NotifierProvider<WalletNotifier, List<WalletCard>>(WalletNotifier.new);
