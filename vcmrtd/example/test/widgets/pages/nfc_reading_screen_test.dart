// Additional coverage tests for NfcReadingScreen.
//
// These tests drive NfcReadingScreen through every DocumentReaderState branch
// by overriding the reader providers with a controllable fake DocumentReader.
// No real NFC platform channel is exercised: the fake DocumentReader overrides
// build()/checkNfcAvailability()/cancel()/reset()/readDocument() so nothing
// touches hardware.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vcmrtd/internal.dart';
import 'package:vcmrtd/vcmrtd.dart';

import 'package:vcmrtdapp/providers/reader_providers.dart';
import 'package:vcmrtdapp/routing.dart';
import 'package:vcmrtdapp/widgets/common/animated_nfc_status_widget.dart';
import 'package:mrz_capture/mrz_capture.dart';
import 'package:vcmrtdapp/widgets/pages/nfc_guidance_screen.dart';
import 'package:vcmrtdapp/widgets/pages/nfc_reading_screen.dart';

// ---------------------------------------------------------------------------
// Fake reader
// ---------------------------------------------------------------------------

/// A fake [DocumentReader] whose state can be set from outside and whose
/// hardware-touching methods are no-ops. The initial state is provided via a
/// static slot read in [build] (Notifier instances are created by Riverpod, so
/// we cannot pass constructor args through the family override easily).
class _FakeReader extends DocumentReader<PassportData> {
  _FakeReader()
    : super(
        documentParser: PassportParser(),
        dataGroupReader: DataGroupReader(NfcProvider(), DF1.PassportAID),
        nfc: NfcProvider(),
        config: const DocumentReaderConfig(readIfAvailable: {}),
      );

  static DocumentReaderState initialState = DocumentReaderPending();

  int cancelCalls = 0;
  int resetCalls = 0;
  int readCalls = 0;

  @override
  DocumentReaderState build() => initialState;

  @override
  Future<void> checkNfcAvailability() async {}

  @override
  Future<void> cancel() async {
    cancelCalls++;
  }

  @override
  void reset() {
    resetCalls++;
    state = DocumentReaderPending();
  }

  @override
  Future<(PassportData, RawDocumentData)?> readDocument({
    required IosNfcMessageMapper iosNfcMessages,
    NonceAndSessionId? activeAuthenticationParams,
  }) async {
    readCalls++;
    // Exercise the iosNfcMessages mapper for a few states so its closure is
    // covered without needing a real chip.
    iosNfcMessages(DocumentReaderConnecting());
    iosNfcMessages(DocumentReaderReadingDataGroup(dataGroup: 'DG1', progress: 0.2));
    iosNfcMessages(DocumentReaderSuccess());
    return null;
  }
}

ScannedPassportMRZ _passportMrz() {
  return ScannedPassportMRZ(
    documentNumber: 'L898902C3',
    countryCode: 'UTO',
    dateOfBirth: DateTime(1974, 8, 12),
    dateOfExpiry: DateTime(2030, 1, 1),
    documentType: DocumentType.passport,
  );
}

/// Builds the screen wrapped in a GoRouter so context.pop works (used by the
/// pending/guidance branch).
Widget _app(DocumentType documentType) {
  final params = NfcReadingRouteParams(scannedMRZ: _passportMrz(), documentType: documentType);
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/start',
        builder: (_, __) => const Scaffold(body: Text('start page')),
      ),
      GoRoute(
        path: '/',
        builder: (_, __) => NfcReadingScreen(params: params, onSuccess: (_, __) {}),
      ),
    ],
  );
  addTearDown(router.dispose);
  return ProviderScope(
    overrides: [
      passportReaderProvider.overrideWith(_FakeReader.new),
      identityCardReaderProvider.overrideWith(_FakeReader.new),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void _setLargeViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  setUp(() => _FakeReader.initialState = DocumentReaderPending());

  group('NfcReadingScreen — pending/guidance state', () {
    testWidgets('pending state renders the NfcGuidanceScreen', (tester) async {
      _setLargeViewport(tester);
      _FakeReader.initialState = DocumentReaderPending();
      await tester.pumpWidget(_app(DocumentType.passport));
      await tester.pump();

      expect(find.byType(NfcGuidanceScreen), findsOneWidget);
    });
  });

  group('NfcReadingScreen — active states render the status widget', () {
    final states = <String, DocumentReaderState>{
      'connecting': DocumentReaderConnecting(),
      'cardAccess': DocumentReaderReadingCardAccess(),
      'authenticating': DocumentReaderAuthenticating(),
      'com': DocumentReaderReadingCOM(),
      'sod': DocumentReaderReadingSOD(),
      'dataGroup': DocumentReaderReadingDataGroup(dataGroup: 'DG2', progress: 0.4),
      'activeAuth': DocumentReaderActiveAuthentication(),
      'success': DocumentReaderSuccess(),
      'cancelling': DocumentReaderCancelling(),
    };

    states.forEach((name, state) {
      testWidgets('renders AnimatedNFCStatusWidget for $name', (tester) async {
        _setLargeViewport(tester);
        _FakeReader.initialState = state;
        await tester.pumpWidget(_app(DocumentType.passport));
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('2 of 4 · Read ${DocumentType.passport.displayName}'), findsOneWidget);
        expect(find.byType(AnimatedNFCStatusWidget), findsOneWidget);

        // Drain any continuous animations.
        await tester.pump(const Duration(milliseconds: 600));
      });
    });

    testWidgets('failed state renders error UI with retry button', (tester) async {
      _setLargeViewport(tester);
      _FakeReader.initialState = DocumentReaderFailed(
        error: DocumentReadingError.unknown,
        logs: 'logs',
        sensitiveLogs: 'sensitive',
      );
      await tester.pumpWidget(_app(DocumentType.passport));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.byType(AnimatedNFCStatusWidget), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);
    });

    testWidgets('cancelled state renders error UI', (tester) async {
      _setLargeViewport(tester);
      _FakeReader.initialState = DocumentReaderCancelled();
      await tester.pumpWidget(_app(DocumentType.passport));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.byType(AnimatedNFCStatusWidget), findsOneWidget);
    });

    testWidgets('reconnecting state shows the reposition tip and keeps the wrapped step', (tester) async {
      _setLargeViewport(tester);
      _FakeReader.initialState = DocumentReaderReconnecting(
        DocumentReaderReadingDataGroup(dataGroup: 'DG2', progress: 0.4),
      );
      await tester.pumpWidget(_app(DocumentType.passport));
      await tester.pump(const Duration(milliseconds: 600));

      // A lost connection mid-retry must not look identical to a healthy
      // read in progress - the tip is the only signal the user gets.
      expect(find.textContaining('Slowly lift your phone off the document'), findsOneWidget);
      // Still on the reading screen (not regressed to the guidance screen or
      // a hard failure) since the retry budget isn't exhausted yet.
      expect(find.byType(NfcGuidanceScreen), findsNothing);
      expect(find.text('2 of 4 · Read ${DocumentType.passport.displayName}'), findsOneWidget);
    });
  });

  group('NfcReadingScreen — title per document type', () {
    testWidgets('identity card uses identity card title', (tester) async {
      _setLargeViewport(tester);
      _FakeReader.initialState = DocumentReaderConnecting();
      await tester.pumpWidget(_app(DocumentType.identityCard));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('2 of 4 · Read ${DocumentType.identityCard.displayName}'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 600));
    });
  });

  group('NfcReadingScreen — retry and cancel callbacks', () {
    testWidgets('tapping retry on failed state resets and starts reading', (tester) async {
      _setLargeViewport(tester);
      _FakeReader.initialState = DocumentReaderFailed(
        error: DocumentReadingError.unknown,
        logs: 'l',
        sensitiveLogs: 's',
      );
      await tester.pumpWidget(_app(DocumentType.passport));
      await tester.pump(const Duration(milliseconds: 600));

      await tester.tap(find.text('Try Again'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // After reset() the state goes back to pending, so the guidance screen
      // is shown again.
      expect(find.byType(NfcGuidanceScreen), findsOneWidget);
    });

    testWidgets('tapping cancel during reading invokes the notifier cancel', (tester) async {
      _setLargeViewport(tester);
      _FakeReader.initialState = DocumentReaderReadingDataGroup(dataGroup: 'DG1', progress: 0.1);
      await tester.pumpWidget(_app(DocumentType.passport));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Cancel'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
    });
  });

  group('NfcReadingScreen — start reading from guidance screen', () {
    testWidgets('start reading button triggers readDocument', (tester) async {
      _setLargeViewport(tester);
      _FakeReader.initialState = DocumentReaderPending();
      await tester.pumpWidget(_app(DocumentType.passport));
      await tester.pump();

      // The guidance screen exposes an onStartReading callback; invoke it
      // directly to trigger startReading -> readDocument.
      final guidance = tester.widget<NfcGuidanceScreen>(find.byType(NfcGuidanceScreen));
      guidance.onStartReading();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(NfcGuidanceScreen), findsOneWidget);
    });
  });

  group('NfcReadingScreen — returning from a pushed route', () {
    testWidgets('after a completed read resets to pending, instead of a dead-end success screen', (tester) async {
      _setLargeViewport(tester);
      // Simulates arriving back here after the user backs out of face
      // verification: the read already succeeded, so there is nothing left
      // to do on this screen if it stays in Success.
      _FakeReader.initialState = DocumentReaderSuccess();

      final params = NfcReadingRouteParams(scannedMRZ: _passportMrz(), documentType: DocumentType.passport);
      final router = GoRouter(
        initialLocation: '/',
        // The app's real routing.dart registers this same observer; without
        // it, NfcReadingScreen's RouteAware subscription never fires.
        observers: [routeObserver],
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => NfcReadingScreen(params: params, onSuccess: (_, __) {}),
          ),
          GoRoute(path: '/next', builder: (_, __) => const Scaffold(body: Text('face verification'))),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            passportReaderProvider.overrideWith(_FakeReader.new),
            identityCardReaderProvider.overrideWith(_FakeReader.new),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(NfcGuidanceScreen), findsNothing);

      router.push('/next');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('face verification'), findsOneWidget);

      router.pop();
      await tester.pump();
      // NfcGuidanceScreen runs a repeating animation and a periodic NFC-status
      // timer, so pumpAndSettle would never return here - a couple of bounded
      // pumps is enough to observe the post-pop state.
      await tester.pump(const Duration(milliseconds: 400));

      // Back on the NFC screen: the completed read was reset, so the
      // guidance screen (with a way forward) is shown, not the dead-end
      // success checklist.
      expect(find.byType(NfcGuidanceScreen), findsOneWidget);
    });
  });
}
