import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import '../custom/custom_logger_extension.dart';
import '../controllers/mrz_controller.dart';
import '../helpers/mrz_scanner.dart';

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  final MRZController controller = MRZController();
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Builder(builder: (context) {
        return MRZScanner(
          controller: controller,
          onSuccess: (mrzResult, lines) async {
            'MRZ Scanned'.logSuccess();

            ///[lines] is a list of String that contains the scanned MRZ (separated by \n)
            final mrzText = lines.join('\n');
            await showDialog(
              barrierDismissible: false,
              barrierLabel: 'Data',
              context: context,
              builder: (context) => Dialog(
                insetPadding: const EdgeInsets.symmetric(horizontal: 10),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      //Parsed MRZ data
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Name : ${mrzResult.givenNames}'),
                            Text('Surname : ${mrzResult.surnames}'),
                            Text(
                                'Gender : ${mrzResult.sex.name.toUpperCase()}'),
                            Text('CountryCode : ${mrzResult.countryCode}'),
                            Text('Date of Birth : ${mrzResult.birthDate}'),
                            Text('Expiry Date : ${mrzResult.expiryDate}'),
                            Text('DocNum : ${mrzResult.documentNumber}'),
                          ],
                        ),
                      ),

                      //RAW MRZ data
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          'MRZ : $mrzText',
                          style: const TextStyle(
                              color: Colors.indigo, fontSize: 12),
                        ),
                      ),

                      CupertinoButton(
                        onPressed: () {
                          Navigator.pop(context);
                          controller.currentState?.resetScanning();
                        },
                        child: Container(
                            height: 40,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              color: const Color.fromARGB(255, 55, 209, 112),
                            ),
                            child: const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Center(
                                  child: Text(
                                'Tap to Reset Scanning',
                                style: TextStyle(
                                    color: Color.fromARGB(255, 0, 0, 0)),
                              )),
                            )),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
