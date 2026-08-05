/// The OCR engines the scanner can read a frame with.
///
/// `googleMlKit` is the default and the only engine available on iOS.
/// `tesseract4android` is the free software engine, present for F-Droid
/// interoperability, and is Android-only: on iOS the scanner falls back to
/// `googleMlKit`.
enum OcrEngine { googleMlKit, tesseract4android }
