import 'package:flutter_test/flutter_test.dart';
import 'package:vcmrtd/vcmrtd.dart';
import 'package:vcmrtdapp/widgets/pages/scanner_wrapper.dart';

void main() {
  group('MrzReaderRouteParams', () {
    test('toQueryParams and fromQueryParams roundtrip for passport', () {
      final params = MrzReaderRouteParams(documentType: DocumentType.passport);
      final map = params.toQueryParams();
      final recovered = MrzReaderRouteParams.fromQueryParams(map);
      expect(recovered.documentType, DocumentType.passport);
    });

    test('toQueryParams and fromQueryParams roundtrip for driving licence', () {
      final params = MrzReaderRouteParams(documentType: DocumentType.drivingLicence);
      final map = params.toQueryParams();
      final recovered = MrzReaderRouteParams.fromQueryParams(map);
      expect(recovered.documentType, DocumentType.drivingLicence);
    });

    test('toQueryParams and fromQueryParams roundtrip for identity card', () {
      final params = MrzReaderRouteParams(documentType: DocumentType.identityCard);
      final map = params.toQueryParams();
      final recovered = MrzReaderRouteParams.fromQueryParams(map);
      expect(recovered.documentType, DocumentType.identityCard);
    });

    test('toQueryParams produces a document_type key', () {
      final params = MrzReaderRouteParams(documentType: DocumentType.passport);
      expect(params.toQueryParams(), contains('document_type'));
    });
  });
}
