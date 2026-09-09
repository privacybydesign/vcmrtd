// Small illustrative widgets shared by the NFC guidance and reading screens.

import 'package:flutter/material.dart';
import 'package:vcmrtd/vcmrtd.dart';

/// A simple phone outline, used to illustrate where to place the document.
Widget buildPhoneIllustration() {
  return Container(
    width: 80, // Portrait shape (narrower than height)
    height: 160,
    decoration: BoxDecoration(
      border: Border.all(color: const Color.fromARGB(255, 0, 0, 0), width: 3),
      borderRadius: BorderRadius.circular(20),
      color: Colors.white,
    ),
    child: Column(
      children: [
        // Notch (optional, to suggest speaker/camera area)
        Container(
          width: 40,
          height: 6,
          margin: const EdgeInsets.only(top: 8),
          decoration: BoxDecoration(color: const Color.fromARGB(255, 0, 0, 0), borderRadius: BorderRadius.circular(3)),
        ),
        const Spacer(),
        // You can add a blank screen or content here if desired
        const SizedBox(height: 8),
      ],
    ),
  );
}

/// The illustration for the given [documentType]: a passport for
/// [DocumentType.passport], otherwise a card-shaped illustration (identity
/// card / driving licence).
Widget buildDocumentIllustration(DocumentType documentType) {
  return documentType == DocumentType.passport ? buildPassportIllustration() : buildDrivingLicenceIllustration();
}

Widget buildPassportIllustration() {
  return const RotatedBox(
    quarterTurns: 3,
    child: SizedBox(
      width: 160,
      height: 200, // increased height to accommodate opened cover
      child: Column(
        children: [
          // Top half – passport cover flipped open
          SizedBox(
            height: 90,
            width: double.infinity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0xFF424242),
                borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                border: Border.fromBorderSide(BorderSide(color: Color(0xFF424242), width: 2)),
              ),
              child: Center(
                child: RotatedBox(
                  quarterTurns: 2, // upside down to simulate flipping
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'PASSPORT',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      Text('Kingdom of Example', style: TextStyle(fontSize: 10, color: Colors.white70)),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Bottom half – inner page with photo + info
          SizedBox(
            height: 100,
            width: double.infinity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0xFFBDBDBD),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(8)),
                border: Border.fromBorderSide(BorderSide(color: Color(0xFF424242), width: 2)),
              ),
              child: Row(
                children: [
                  // Photo placeholder
                  SizedBox(
                    width: 70,
                    child: Center(
                      child: CircleAvatar(
                        radius: 24,
                        backgroundColor: Color(0xFFE0E0E0), // Colors.grey.shade300
                        child: Icon(Icons.person, size: 28, color: Color(0xFF616161)), // Colors.grey.shade700
                      ),
                    ),
                  ),
                  // Info text
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Name: John Doe', style: TextStyle(fontSize: 10, color: Color(0xFF333333))),
                        Text('Nationality: NL', style: TextStyle(fontSize: 10, color: Color(0xFF333333))),
                        Text('DOB: 01-01-1990', style: TextStyle(fontSize: 10, color: Color(0xFF333333))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

const BorderColor = Color(0xFFB48DA3);

Widget buildDrivingLicenceIllustration() {
  return Container(
    width: 155,
    height: 90,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFFFFE0E6), Color(0xFFFFC1CC)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      border: Border.all(color: BorderColor, width: 1.2),
      borderRadius: BorderRadius.circular(8),
      boxShadow: [BoxShadow(color: Colors.grey.withValues(alpha: 0.15), blurRadius: 3, offset: const Offset(2, 2))],
    ),
    child: Padding(
      padding: const EdgeInsets.all(6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(width: 5),
              const Flexible(
                child: Text(
                  'DRIVING LICENCE',
                  style: TextStyle(
                    color: Color(0xFF0046AD),
                    fontWeight: FontWeight.bold,
                    fontSize: 9,
                    letterSpacing: 0.4,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Spacer(),
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: Colors.grey[400]!),
                ),
                child: Icon(Icons.person, size: 10, color: Colors.grey[600]),
              ),
            ],
          ),

          const SizedBox(height: 4),

          // Middle section – main photo placeholder
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 38,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: Colors.grey[400]!),
                ),
                child: Icon(Icons.person, size: 20, color: Colors.grey[600]),
              ),
            ),
          ),

          // MRZ line at the bottom (only text, no bar)
          const Center(
            child: Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'D1NLD2X150949621115MZ26KC47X2W',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  fontSize: 6,
                  color: Colors.black,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
