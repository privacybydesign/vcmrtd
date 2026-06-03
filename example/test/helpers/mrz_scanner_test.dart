import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vcmrtd/vcmrtd.dart';
import 'package:vcmrtdapp/helpers/mrz_scanner.dart';

// Helper to build an MRZScannerState for testing the parsing logic.
// We wrap in a real widget tree because MRZScanner is a ConsumerStatefulWidget.
MRZScannerState _buildState(WidgetTester tester) {
  return tester.state<MRZScannerState>(find.byType(MRZScanner));
}

Widget _scaffold({required DocumentType documentType, void Function(dynamic, List<String>)? onSuccess}) {
  return ProviderScope(
    child: MaterialApp(
      home: Scaffold(
        body: MRZScanner(documentType: documentType, onSuccess: onSuccess ?? (_, __) {}),
      ),
    ),
  );
}

void main() {
  group('MRZScannerState._parseScannedText', () {
    testWidgets('returns null for empty lines', (tester) async {
      await tester.pumpWidget(_scaffold(documentType: DocumentType.passport));
      await tester.pump();
      final state = _buildState(tester);
      expect(state.debugParseScannedText([]), isNull);
    });

    testWidgets('returns null for invalid passport MRZ lines', (tester) async {
      await tester.pumpWidget(_scaffold(documentType: DocumentType.passport));
      await tester.pump();
      final state = _buildState(tester);
      expect(state.debugParseScannedText(['INVALID_LINE']), isNull);
    });

    testWidgets('returns non-null for valid passport MRZ lines', (tester) async {
      await tester.pumpWidget(_scaffold(documentType: DocumentType.passport));
      await tester.pump();
      final state = _buildState(tester);
      // Standard ICAO TD3 passport MRZ (two 44-char lines).
      const line1 = 'P<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<';
      const line2 = 'L898902C36UTO7408122F1204159ZE184226B<<<<<10';
      final result = state.debugParseScannedText([line1, line2]);
      expect(result, isNotNull);
    });

    testWidgets('returns null for wrong document type lines', (tester) async {
      await tester.pumpWidget(_scaffold(documentType: DocumentType.passport));
      await tester.pump();
      final state = _buildState(tester);
      // These are garbage lines for a passport parser.
      expect(state.debugParseScannedText(['AAAAAA', 'BBBBBB']), isNull);
    });
  });

  group('MRZScannerState._tryParseAndNotify', () {
    testWidgets('returns false for invalid lines', (tester) async {
      await tester.pumpWidget(_scaffold(documentType: DocumentType.passport));
      await tester.pump();
      final state = _buildState(tester);
      expect(state.debugTryParseAndNotify(['NOT_VALID']), isFalse);
    });

    testWidgets('returns true and calls onSuccess for valid passport lines', (tester) async {
      dynamic captured;
      await tester.pumpWidget(
        _scaffold(documentType: DocumentType.passport, onSuccess: (result, _) => captured = result),
      );
      await tester.pump();
      final state = _buildState(tester);
      const line1 = 'P<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<';
      const line2 = 'L898902C36UTO7408122F1204159ZE184226B<<<<<10';
      final ok = state.debugTryParseAndNotify([line1, line2]);
      expect(ok, isTrue);
      expect(captured, isNotNull);
    });
  });
}
