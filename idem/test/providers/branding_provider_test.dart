import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idem/providers/branding_provider.dart';
import 'package:idem/providers/proofing_session_provider.dart';
import 'package:idem/services/proofing_session_client.dart';
import 'package:idem/theme/app_theme.dart';

const _ref = ProofingSessionRef(apiBase: 'https://wallet.example', token: 'tok', deviceToken: 'dev');

ProofingSessionInfo _info({ProofingBranding? branding}) => ProofingSessionInfo(
  id: 'sess-1',
  relyingParty: 'CM.com B.V.',
  requestedAttributes: const ['dg1'],
  expiresAt: DateTime(2030),
  branding: branding,
);

/// Serves one logo and counts how often it was asked for.
class _LogoClient extends ProofingSessionClient {
  _LogoClient(this.logo);

  final Uint8List? logo;
  int fetches = 0;

  /// When set, fetches wait for it, so a test can end the session meanwhile.
  Completer<void>? gate;

  int failuresLeft = 0;

  @override
  Future<Uint8List?> fetchBrandingLogo(ProofingSessionRef ref) async {
    fetches++;
    await gate?.future;
    if (failuresLeft > 0) {
      failuresLeft--;
      throw Exception('offline');
    }
    return logo;
  }
}

/// Holds every logo fetch until a test releases it, in any order.
class _HeldLogoClient extends ProofingSessionClient {
  final fetches = <Completer<Uint8List?>>[];

  @override
  Future<Uint8List?> fetchBrandingLogo(ProofingSessionRef ref) {
    final fetch = Completer<Uint8List?>();
    fetches.add(fetch);
    return fetch.future;
  }
}

void main() {
  test('a session dresses the app in its branding until it is reset', () async {
    final client = _LogoClient(Uint8List.fromList([1, 2, 3]));
    final container = ProviderContainer(overrides: [proofingSessionClientProvider.overrideWithValue(client)]);
    addTearDown(container.dispose);
    final notifier = container.read(activeBrandingProvider.notifier);
    const branding = ProofingBranding(name: 'CM.com', primaryColor: '#036BD2', hasLogo: true);

    expect(container.read(activeBrandingProvider).name, AppBranding.idem.name);
    await notifier.useSession(_ref, _info(branding: branding));
    final active = container.read(activeBrandingProvider);
    expect(active.name, 'CM.com');
    expect(active.primary, const Color(0xFF036BD2));
    expect(active.logo, isA<MemoryImage>());

    // An unchanged view (the watcher's next update) keeps it, logo and all.
    await notifier.useSession(_ref, _info(branding: branding));
    expect(client.fetches, 1);

    notifier.reset();
    expect(container.read(activeBrandingProvider).name, AppBranding.idem.name);
  });

  test('a logo that failed to load is fetched again with the next view', () async {
    final client = _LogoClient(Uint8List.fromList([1, 2, 3]))..failuresLeft = 1;
    final container = ProviderContainer(overrides: [proofingSessionClientProvider.overrideWithValue(client)]);
    addTearDown(container.dispose);
    final notifier = container.read(activeBrandingProvider.notifier);
    const branding = ProofingBranding(name: 'CM.com', hasLogo: true);

    await notifier.useSession(_ref, _info(branding: branding));
    expect(container.read(activeBrandingProvider).name, 'CM.com');
    expect(container.read(activeBrandingProvider).logo, isNull);

    await notifier.useSession(_ref, _info(branding: branding));
    expect(client.fetches, 2);
    expect(container.read(activeBrandingProvider).logo, isA<MemoryImage>());

    await notifier.useSession(_ref, _info(branding: branding));
    expect(client.fetches, 2);
  });

  test('a session without branding gets the app\'s own look', () async {
    final container = ProviderContainer(
      overrides: [proofingSessionClientProvider.overrideWithValue(_LogoClient(null))],
    );
    addTearDown(container.dispose);
    final notifier = container.read(activeBrandingProvider.notifier);
    await notifier.useSession(
      _ref,
      _info(
        branding: const ProofingBranding(name: 'CM.com', primaryColor: '#036BD2'),
      ),
    );
    await notifier.useSession(_ref, _info());
    expect(container.read(activeBrandingProvider).name, AppBranding.idem.name);
  });

  test('a session that ends while its logo is loading leaves the app in its own look', () async {
    final client = _LogoClient(Uint8List.fromList([1, 2, 3]))..gate = Completer<void>();
    final container = ProviderContainer(overrides: [proofingSessionClientProvider.overrideWithValue(client)]);
    addTearDown(container.dispose);
    final notifier = container.read(activeBrandingProvider.notifier);

    final loading = notifier.useSession(_ref, _info(branding: const ProofingBranding(name: 'CM.com', hasLogo: true)));
    notifier.endSession(_ref);
    client.gate!.complete();
    await loading;
    expect(container.read(activeBrandingProvider).name, AppBranding.idem.name);
  });

  test('ending a session drops its branding, but not another session\'s', () async {
    final container = ProviderContainer(
      overrides: [proofingSessionClientProvider.overrideWithValue(_LogoClient(null))],
    );
    addTearDown(container.dispose);
    final notifier = container.read(activeBrandingProvider.notifier);
    await notifier.useSession(_ref, _info(branding: const ProofingBranding(name: 'CM.com')));

    notifier.endSession(
      const ProofingSessionRef(apiBase: 'https://wallet.example', token: 'other', deviceToken: 'dev'),
    );
    expect(container.read(activeBrandingProvider).name, 'CM.com');

    notifier.endSession(_ref);
    expect(container.read(activeBrandingProvider).name, AppBranding.idem.name);
  });

  group('a logo that arrives after the view changed doesn\'t win', () {
    const a = ProofingBranding(name: 'A', hasLogo: true);
    const b = ProofingBranding(name: 'B', hasLogo: true);

    test('a newer view', () async {
      final client = _HeldLogoClient();
      final container = ProviderContainer(overrides: [proofingSessionClientProvider.overrideWithValue(client)]);
      addTearDown(container.dispose);
      final notifier = container.read(activeBrandingProvider.notifier);

      final loadingA = notifier.useSession(_ref, _info(branding: a));
      final loadingB = notifier.useSession(_ref, _info(branding: b));
      client.fetches[1].complete(null);
      await loadingB;
      client.fetches[0].complete(null);
      await loadingA;
      expect(container.read(activeBrandingProvider).name, 'B');
    });

    test('back to the view already shown', () async {
      final client = _HeldLogoClient();
      final container = ProviderContainer(overrides: [proofingSessionClientProvider.overrideWithValue(client)]);
      addTearDown(container.dispose);
      final notifier = container.read(activeBrandingProvider.notifier);

      final loadingB = notifier.useSession(_ref, _info(branding: b));
      client.fetches[0].complete(null);
      await loadingB;
      final loadingA = notifier.useSession(_ref, _info(branding: a));
      await notifier.useSession(_ref, _info(branding: b));
      client.fetches[1].complete(null);
      await loadingA;
      expect(container.read(activeBrandingProvider).name, 'B');
    });
  });
}
