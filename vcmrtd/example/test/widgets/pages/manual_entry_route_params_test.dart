import 'package:flutter_test/flutter_test.dart';
import 'package:vcmrtd/vcmrtd.dart';
import 'package:vcmrtdapp/widgets/pages/manual_entry_route_params.dart';

void main() {
  group('ManualEntryRouteParams', () {
    test('round-trips through query params', () {
      final params = ManualEntryRouteParams(documentType: DocumentType.drivingLicence);
      final query = params.toQueryParams();
      final restored = ManualEntryRouteParams.fromQueryParams(query);
      expect(restored.documentType, DocumentType.drivingLicence);
    });
  });
}
