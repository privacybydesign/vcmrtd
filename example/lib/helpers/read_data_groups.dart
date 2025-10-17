import 'dart:typed_data';

import 'package:logging/logging.dart';
import 'package:vcmrtd/extensions.dart';
import 'package:vcmrtd/vcmrtd.dart';
import 'package:vcmrtdapp/helpers/document_type_extract.dart';
import 'package:vcmrtdapp/models/data_group_config.dart';
import 'package:vcmrtdapp/models/mrtd_data.dart';
import 'package:vcmrtdapp/models/passport_result.dart';
import 'package:vcmrtdapp/widgets/common/animated_nfc_status_widget.dart';

typedef StatusUpdater = void Function({
  String? message,
  NFCReadingState? state,
  double? progress,
});

Future<DataResult> readDataGroups({
  required Document document,
  required MrtdData mrtdData,
  required DocumentType documentType,
  required NfcProvider nfcProvider,
  required Logger log,
  required StatusUpdater updateStatus,
  String? sessionId,
  Uint8List? nonce,
}) async {
  updateStatus(
    message: "Reading ${documentType.displayNameLowerCase} data...",
    state: NFCReadingState.reading,
    progress: 0.1,
  );

  try {
    final reader = DocumentReader.from(document);

    // Read EF.COM first to discover available data groups.
    nfcProvider.setIosAlertMessage("Reading EF.COM ...");
    mrtdData.com = await reader.readEfCOM();

    final dataGroupConfigs = [
      DataGroupConfig(
        tag: EfDG1.TAG,
        name: "DG1",
        progressIncrement: 0.1,
        readFunction: (r) async {
          final dg = await r.readEfDG1();
          mrtdData.dg1 = dg;
          return dg;
        },
      ),
      DataGroupConfig(
        tag: EfDG2.TAG,
        name: "DG2",
        progressIncrement: 0.1,
        readFunction: (r) async {
          final dg = await r.readEfDG2();
          mrtdData.dg2 = dg;
          return dg;
        },
      ),
      DataGroupConfig(
        tag: EfDG5.TAG,
        name: "DG5",
        progressIncrement: 0.1,
        readFunction: (r) async {
          final dg = await r.readEfDG5();
          mrtdData.dg5 = dg;
          return dg;
        },
      ),
      DataGroupConfig(
        tag: EfDG6.TAG,
        name: "DG6",
        progressIncrement: 0.05,
        readFunction: (r) async {
          final dg = await r.readEfDG6();
          mrtdData.dg6 = dg;
          return dg;
        },
      ),
      DataGroupConfig(
        tag: EfDG7.TAG,
        name: "DG7",
        progressIncrement: 0.05,
        readFunction: (r) async {
          final dg = await r.readEfDG7();
          mrtdData.dg7 = dg;
          return dg;
        },
      ),
      DataGroupConfig(
        tag: EfDG8.TAG,
        name: "DG8",
        progressIncrement: 0.05,
        readFunction: (r) async {
          final dg = await r.readEfDG8();
          mrtdData.dg8 = dg;
          return dg;
        },
      ),
      DataGroupConfig(
        tag: EfDG9.TAG,
        name: "DG9",
        progressIncrement: 0.05,
        readFunction: (r) async {
          final dg = await r.readEfDG9();
          mrtdData.dg9 = dg;
          return dg;
        },
      ),
      DataGroupConfig(
        tag: EfDG10.TAG,
        name: "DG10",
        progressIncrement: 0.05,
        readFunction: (r) async {
          final dg = await r.readEfDG10();
          mrtdData.dg10 = dg;
          return dg;
        },
      ),
      DataGroupConfig(
        tag: EfDG11.TAG,
        name: "DG11",
        progressIncrement: 0.05,
        readFunction: (r) async {
          final dg = await r.readEfDG11();
          mrtdData.dg11 = dg;
          return dg;
        },
      ),
      DataGroupConfig(
        tag: EfDG12.TAG,
        name: "DG12",
        progressIncrement: 0.05,
        readFunction: (r) async {
          final dg = await r.readEfDG12();
          mrtdData.dg12 = dg;
          return dg;
        },
      ),
      DataGroupConfig(
        tag: EfDG13.TAG,
        name: "DG13",
        progressIncrement: 0.05,
        readFunction: (r) async {
          final dg = await r.readEfDG13();
          mrtdData.dg13 = dg;
          return dg;
        },
      ),
      DataGroupConfig(
        tag: EfDG14.TAG,
        name: "DG14",
        progressIncrement: 0.05,
        readFunction: (r) async {
          final dg = await r.readEfDG14();
          mrtdData.dg14 = dg;
          return dg;
        },
      ),
      DataGroupConfig(
        tag: EfDG16.TAG,
        name: "DG16",
        progressIncrement: 0.05,
        readFunction: (r) async {
          final dg = await r.readEfDG16();
          mrtdData.dg16 = dg;
          return dg;
        },
      ),
    ];

    nfcProvider.setIosAlertMessage("Reading Data Groups");

    final Map<String, String> dataGroups = {};
    double currentProgress = 0.2;

    for (final config in dataGroupConfigs) {
      if (mrtdData.com!.dgTags.contains(config.tag)) {
        try {
          final dgData = await config.readFunction(reader);
          final hexData = dgData.toBytes().hex();
          if (hexData.isNotEmpty) {
            dataGroups[config.name] = hexData;
          }
        } catch (e) {
          log.warning("Failed to read ${config.name}: $e");
        }
      }

      currentProgress += config.progressIncrement;
      updateStatus(progress: currentProgress.clamp(0.0, 0.9));
    }

    final shouldAttemptAa = sessionId != null &&
        nonce != null &&
        mrtdData.com!.dgTags.contains(EfDG15.TAG);

    if (shouldAttemptAa) {
      updateStatus(
        message: "Performing security verification...",
        state: NFCReadingState.authenticating,
        progress: 0.9,
      );

      try {
        mrtdData.dg15 = await reader.readEfDG15();
        if (mrtdData.dg15 != null) {
          final hexData = mrtdData.dg15!.toBytes().hex();
          if (hexData.isNotEmpty) {
            dataGroups["DG15"] = hexData;
          }
        }

        nfcProvider.setIosAlertMessage("Doing AA ...");
        mrtdData.aaSig = await document.activeAuthenticate(nonce);
      } catch (e) {
        log.warning("Failed to read DG15 or perform AA: $e");
      }
    }

    nfcProvider.setIosAlertMessage("Reading EF.SOD ...");
    mrtdData.sod = await reader.readEfSOD();

    final efSodHex = mrtdData.sod?.toBytes().hex() ?? '';
    log.info("EF.SOD: $efSodHex");

    updateStatus(
      message: "${documentType.displayName} reading completed successfully!",
      state: NFCReadingState.success,
      progress: 1.0,
    );

    return DataResult(
      dataGroups: dataGroups,
      efSod: efSodHex,
      nonce: nonce,
      sessionId: sessionId,
      aaSignature: mrtdData.aaSig,
    );
  } catch (e) {
    log.severe(
      "Error reading ${documentType.displayNameLowerCase} data: $e",
    );
    updateStatus(
      message: "Failed to read passport data",
      state: NFCReadingState.error,
    );
    rethrow;
  }
}

Future<void> performDocumentReading({
  required Document document,
  required NfcProvider nfcProvider,
  required AccessKey accessKey,
  required bool isPace,
  required DocumentType documentType,
  required Logger log,
  required StatusUpdater updateStatus,
  String? sessionId,
  Uint8List? nonce,
  void Function(MrtdData, DataResult)? onDataRead,
}) async {
  nfcProvider.setIosAlertMessage("Trying to read EF.CardAccess ...");
  final mrtdData = MrtdData();

  try {
    mrtdData.cardAccess = await document.readEfCardAccess();
  } on DocumentError {
    // Handle card access read error
  }

  nfcProvider.setIosAlertMessage("Trying to read EF.CardSecurity ...");
  try {
    mrtdData.cardSecurity = await document.readEfCardSecurity();
  } on DocumentError {
    // Handle card security read error
  }

  nfcProvider.setIosAlertMessage("Initiating session with PACE...");
  mrtdData.isPACE = isPace;
  mrtdData.isDBA = accessKey.PACE_REF_KEY_TAG == 0x01;

  updateStatus(
    message:
        "Authenticating with ${documentType.displayNameLowerCase}...",
    state: NFCReadingState.authenticating,
  );

  if (isPace) {
    await document.startSessionPACE(accessKey, mrtdData.cardAccess!);
  } else {
    await document.startSession(accessKey as DBAKey);
  }

  final dataResult = await readDataGroups(
    document: document,
    mrtdData: mrtdData,
    documentType: documentType,
    nfcProvider: nfcProvider,
    log: log,
    sessionId: sessionId,
    nonce: nonce,
    updateStatus: updateStatus,
  );

  onDataRead?.call(mrtdData, dataResult);
}
