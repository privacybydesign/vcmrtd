// Created by Crt Vavros, copyright © 2022 ZeroPass. All rights reserved.
// MRTD data list widget for displaying passport data

import 'package:flutter/material.dart';
import 'package:vcmrtd/extensions.dart';
import 'package:vcmrtd/vcmrtd.dart';
import 'package:vcmrtdapp/widgets/displays/passport_image_widget.dart';
import '../../utils/formatters.dart';
import 'access_protocol_widget.dart';
import 'mrtd_data_widget.dart';

/// Widget to display list of MRTD data
class MrtdDataListWidget extends StatelessWidget {
  final MrtdData? mrtdData;
  final DocumentType documentType;
  const MrtdDataListWidget({super.key, this.mrtdData, required this.documentType});

  List<Widget> _buildDataWidgets() {
    List<Widget> list = [];
    if (mrtdData == null) return list;

    // Access protocol information
    if (mrtdData!.isPACE != null && mrtdData!.isDBA != null) {
      list.add(
        AccessProtocolWidget(
          header: "Access protocol",
          collapsedText: '',
          isDBA: mrtdData!.isDBA!,
          isPACE: mrtdData!.isPACE!,
        ),
      );
    }

    // EF.CardAccess
    if (mrtdData!.cardAccess != null) {
      list.add(
        MrtdDataWidget(header: 'EF.CardAccess', collapsedText: '', dataText: mrtdData!.cardAccess!.toBytes().hex()),
      );
    }

    // EF.CardSecurity
    if (mrtdData!.cardSecurity != null) {
      list.add(
        MrtdDataWidget(header: 'EF.CardSecurity', collapsedText: '', dataText: mrtdData!.cardSecurity!.toBytes().hex()),
      );
    }

    // EF.SOD
    if (mrtdData!.sod != null) {
      list.add(MrtdDataWidget(header: 'EF.SOD', collapsedText: '', dataText: mrtdData!.sod!.toBytes().hex()));
    }

    // EF.COM
    if (mrtdData!.com != null) {
      list.add(MrtdDataWidget(header: 'EF.COM', collapsedText: '', dataText: formatEfCom(mrtdData!.com!, documentType)));
    }

    // EF.DG1 (MRZ)
    if (mrtdData!.dg1 != null) {
      list.add(
        MrtdDataWidget(header: 'EF.DG1', collapsedText: '', dataText: formatMRZ(mrtdData!.dg1!.passportData!.mrz)),
      );
    }

    if (mrtdData!.dg2 != null) {
      list.add(
        PassportImageWidget(
          header: 'EF.DG2',
          imageType: mrtdData!.dg2!.imageType,
          imageData: mrtdData!.dg2!.imageData!,
        ),
      );
    }

    // Data Groups 2-16
    final dataGroups = {
      // 'EF.DG2': mrtdData!.dg2?.toBytes().hex(),
      'EF.DG3': mrtdData!.dg3?.toBytes().hex(),
      'EF.DG4': mrtdData!.dg4?.toBytes().hex(),
      'EF.DG5': mrtdData!.dg5?.toBytes().hex(),
      'EF.DG6': mrtdData!.dg6?.toBytes().hex(),
      'EF.DG7': mrtdData!.dg7?.toBytes().hex(),
      'EF.DG8': mrtdData!.dg8?.toBytes().hex(),
      'EF.DG9': mrtdData!.dg9?.toBytes().hex(),
      'EF.DG10': mrtdData!.dg10?.toBytes().hex(),
      'EF.DG11': mrtdData!.dg11?.toBytes().hex(),
      'EF.DG12': mrtdData!.dg12?.toBytes().hex(),
      'EF.DG13': mrtdData!.dg13?.toBytes().hex(),
      'EF.DG14': mrtdData!.dg14?.toBytes().hex(),
      'EF.DG15': mrtdData!.dg15?.toBytes().hex(),
      'EF.DG16': mrtdData!.dg16?.toBytes().hex(),
    };

    for (final entry in dataGroups.entries) {
      if (entry.value != null) {
        list.add(MrtdDataWidget(header: entry.key, collapsedText: '', dataText: entry.value!));
      }
    }

    // Active Authentication signature
    if (mrtdData!.aaSig != null) {
      list.add(
        MrtdDataWidget(header: 'Active Authentication signature', collapsedText: '', dataText: mrtdData!.aaSig!.hex()),
      );
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(left: 16.0, top: 8.0, bottom: 8.0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: _buildDataWidgets()),
          ),
        ],
      ),
    );
  }
}
