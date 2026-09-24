import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mrz_capture/mrz_capture.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:idem/providers/proofing_session_provider.dart';
import 'package:idem/services/proofing_session_client.dart';
import 'package:idem/widgets/pages/document_capture_only_result_screen.dart';

ActiveProofingSession _fakeProofingSession() => ActiveProofingSession(
  ref: const ProofingSessionRef(apiBase: 'https://proof.example.com', token: 'tok-1'),
  info: ProofingSessionInfo(
    id: 'session-1',
    relyingParty: 'Acme Corp',
    requestedAttributes: const [],
    expiresAt: DateTime.now().add(const Duration(minutes: 5)),
    steps: const ['document_capture'],
  ),
  openedAt: DateTime.now(),
);

ScannedPassportMRZ _scannedPassport() => ScannedPassportMRZ(
  documentNumber: 'L898902C3',
  countryCode: 'UTO',
  dateOfBirth: DateTime(1974, 8, 12),
  dateOfExpiry: DateTime(2012, 4, 15),
);

void main() {
  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'Idem',
      packageName: 'foundation.privacybydesign.idem',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  testWidgets('auto-submits a partial document built from the scanned MRZ, with no photo/mrtdEvidence', (tester) async {
    Map<String, dynamic>? sentBody;
    final session = _fakeProofingSession();

    await http.runWithClient(
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        container.read(activeProofingSessionProvider.notifier).set(session);
        var backCount = 0;

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: DocumentCaptureOnlyResultScreen(
                session: session,
                scannedMrz: _scannedPassport(),
                onBackPressed: () => backCount++,
              ),
            ),
          ),
        );
        await tester.pump();

        expect(sentBody, isNotNull);
        final document = sentBody!['document'] as Map<String, dynamic>;
        expect(document['number'], 'L898902C3');
        expect(document['issuingState'], 'UTO');
        expect(document.containsKey('personalNumber'), isFalse);
        expect(document.containsKey('firstName'), isFalse);
        expect(sentBody!.containsKey('photo'), isFalse);
        expect(sentBody!.containsKey('mrtdEvidence'), isFalse);

        expect(find.text('Submitted'), findsOneWidget);
        expect(container.read(activeProofingSessionProvider), isNull);

        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        expect(backCount, 1);
      },
      () => MockClient((request) async {
        sentBody = json.decode(request.body) as Map<String, dynamic>;
        return http.Response('{}', 200);
      }),
    );
  });
}
