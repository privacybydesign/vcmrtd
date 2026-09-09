/// Face verification via the vendor Iris SDK.
///
/// Alternate engine to `face_verification` — same capability, different
/// (vendor-owned) pipeline. The two packages are independent; pick one per
/// call site.
library;

export 'src/iris_face_verifier.dart';
export 'src/iris_verification_result.dart';
