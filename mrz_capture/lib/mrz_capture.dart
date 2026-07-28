/// MRZ capture for machine readable travel documents.
///
/// [MRZScanner] is the entry point: it drives the camera, runs the selected
/// [OcrEngine] over each frame, validates the ICAO check digits and reports a
/// [ScannedMRZ]. [ManualEntryScreen] is the fallback for documents that will
/// not scan.
///
/// The module owns no navigation and no state management. Callers pass in the
/// engine they want, their own [RouteObserver] so the camera can be released
/// while another route is on top, and callbacks for the results.
library;

export 'src/camera_overlay.dart' show MRZCameraOverlay;
export 'src/camera_viewfinder.dart' show MRZCameraView, MRZCameraViewState, OcrFrame;
export 'src/manual_entry_screen.dart' show ManualEntryScreen;
export 'src/mrz_controller.dart' show MRZController;
export 'src/mrz_helper.dart' show MRZHelper;
export 'src/mrz_scanner.dart' show MRZScanner, MRZScannerState, MrzScannedCallback;
export 'src/ocr_engine.dart' show OcrEngine;
export 'src/scanned_mrz.dart' show ScannedMRZ, ScannedPassportMRZ, ScannedIdCardMRZ, ScannedDriverLicenseMRZ;
