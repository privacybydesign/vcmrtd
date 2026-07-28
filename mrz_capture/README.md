# mrz_capture

Reads the Machine Readable Zone of a passport, identity card or driving licence with the
device camera, and falls back to typed entry when scanning will not work.

This was the scanning experience of the `vcmrtd` example application. It lives here so it can
be consumed by any Flutter application, and so the same behaviour can be ported to the other
SDK targets.

## What is in here

- `MRZScanner` — the camera preview, the framing overlay, frame dispatch to an OCR engine, ICAO
  check digit validation with a correction retry, and the parsed result.
- `MRZCameraView` and `MRZCameraOverlay` — the viewfinder and the document frame, usable on
  their own.
- `MRZHelper` — MRZ line normalisation, TD1/TD2/TD3 detection and the field type and check digit
  corrections applied to a misread.
- `ManualEntryScreen` — the manual entry fallback, producing the same result type as a scan.
- `ScannedMRZ` and its subclasses — the result: document number, country code, and the dates or
  driving licence fields the chip needs.

## Usage

```dart
MRZScanner(
  documentType: DocumentType.passport,
  engine: OcrEngine.googleMlKit,
  routeObserver: myRouteObserver,
  onSuccess: (mrz, lines) => print(mrz.documentNumber),
)
```

The module holds no navigation and no state management of its own. The caller decides which
engine to use, hands over its own `RouteObserver` so the camera can be released while another
route is on top, and receives results through callbacks.

## OCR engines

Two engines are selectable through `OcrEngine`:

- `googleMlKit` — Google ML Kit Text Recognition. The default, and the path iOS always takes.
- `tesseract4android` — Tesseract4Android, the free software engine kept for F-Droid
  interoperability. Android only; on iOS the scanner falls back to ML Kit.

The Tesseract engine and the OpenCV-based MRZ zone detector that feeds it are the Android
platform code of this package, so no host application has to register them.

## Licence

GPL-3.0, as the rest of this repository. See [LICENSE](LICENSE).
