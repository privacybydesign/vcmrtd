// Route parameters for the manual entry screen. The screen itself is part of
// the mrz_capture module; only its place in this application's navigation is
// application code.

import 'package:vcmrtd/vcmrtd.dart';

class ManualEntryRouteParams {
  final DocumentType documentType;

  ManualEntryRouteParams({required this.documentType});

  static ManualEntryRouteParams fromQueryParams(Map<String, String> params) {
    return ManualEntryRouteParams(documentType: stringToDocumentType(params['document_type']!));
  }

  Map<String, String> toQueryParams() {
    return {'document_type': documentTypeToString(documentType)};
  }
}
