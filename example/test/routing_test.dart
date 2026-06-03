import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vcmrtdapp/routing.dart';

void main() {
  group('routeObserver', () {
    test('is a RouteObserver instance', () {
      expect(routeObserver, isA<RouteObserver<ModalRoute<void>>>());
    });
  });

  group('createRouter', () {
    testWidgets('returns a GoRouter with /select_doc_type as initial route', (tester) async {
      final router = createRouter();
      expect(router, isA<GoRouter>());
      expect(router.routeInformationProvider.value.uri.path, '/select_doc_type');
    });
  });
}
