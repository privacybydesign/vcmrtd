import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:idem/main.dart';
import 'package:idem/widgets/pages/document_selection_screen.dart';
import 'package:wakelock_plus_platform_interface/wakelock_plus_platform_interface.dart';

const _deepLinkChannel = MethodChannel('proofing_deeplink');

class _FakeWakelock extends WakelockPlusPlatformInterface {
  bool on = false;

  @override
  Future<void> toggle({required bool enable}) async => on = enable;

  @override
  Future<bool> get enabled async => on;
}

void main() {
  testWidgets('the screen stays on while a scanning screen is on top', (tester) async {
    final wakelock = _FakeWakelock();
    WakelockPlusPlatformInterface.instance = wakelock;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      _deepLinkChannel,
      (call) async => null,
    );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        _deepLinkChannel,
        null,
      ),
    );

    await tester.pumpWidget(ProviderScope(child: VcMrtdApp()));
    await tester.pumpAndSettle();
    expect(wakelock.on, isFalse);

    final router = GoRouter.of(tester.element(find.byType(DocumentTypeSelectionScreen)));
    router.push('/qr_scanner');
    await tester.pump();
    expect(wakelock.on, isTrue);

    router.pop();
    await tester.pumpAndSettle();
    expect(wakelock.on, isFalse);
  });
}
