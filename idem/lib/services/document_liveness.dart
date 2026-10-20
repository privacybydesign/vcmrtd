import 'dart:math' as math;
import 'dart:typed_data';

// None of these were measured on a device yet: collect the signals of real
// documents and screens before letting them decide anything.

const signatureColumns = 16;
const signatureRows = 10;

const _maxPreviewFrames = 90;
const _minFrames = 3;

/// Cells this dark or this bright say nothing about colour.
const _minCellBrightness = 25;
const _maxCellBrightness = 235;

const _shiftCells = 3;

/// On a Galaxy, with the torch on, a real Dutch ID card's glare grew 0.22 to
/// 0.43 and its brightness 1.11 to 1.23 times; a Dutch passport's photo page,
/// less glossy, glared only 0.07 to 0.10 but still brightened 1.04 times.
/// The same documents on a phone screen glared 0.02 to 0.09 and brightened
/// 0.84 to 1.08 times. One phone, one room, four photos each.
const _minDocumentGlare = 0.15;
const _minDocumentResponse = 1.0;

/// The document in one preview frame: its brightness and colour (YCbCr) in
/// [signatureColumns] x [signatureRows] cells, row by row.
class FrameSignature {
  const FrameSignature({required this.luma, required this.cb, required this.cr});

  final Float32List luma;
  final Float32List cb;
  final Float32List cr;
}

/// When a frame was taken: in the normal preview, or with the exposure
/// locked before and after the torch went on.
enum LightPhase { preview, unlit, lit }

/// How the document behaved over the preview frames: a real document
/// reflects light and its hologram changes colour as it tilts; a screen
/// gives off its own light and shows a picture that doesn't.
class DocumentLiveness {
  final _preview = <FrameSignature>[];
  final _unlit = <FrameSignature>[];
  final _lit = <FrameSignature>[];

  /// Frames the camera delivered, and how many the slower checks got to.
  var _received = 0;
  var _qualityChecked = 0;
  var _portraitChecked = 0;

  void received() => _received++;
  void qualityChecked() => _qualityChecked++;
  void portraitChecked() => _portraitChecked++;

  /// The sensor's exposure time (ns) and ISO per torch phase, as the camera
  /// reports them: whether the exposure lock held.
  final _exposures = {LightPhase.unlit: <(int, double)>[], LightPhase.lit: <(int, double)>[]};

  void exposure(LightPhase phase, {int? time, double? iso}) {
    if (time != null && iso != null) _exposures[phase]?.add((time, iso));
  }

  void add(FrameSignature signature, LightPhase phase) {
    switch (phase) {
      case LightPhase.preview:
        _preview.add(signature);
        if (_preview.length > _maxPreviewFrames) _preview.removeAt(0);
      case LightPhase.unlit:
        _unlit.add(signature);
      case LightPhase.lit:
        _lit.add(signature);
    }
  }

  void reset() {
    _preview.clear();
    _unlit.clear();
    _lit.clear();
    _received = 0;
    _qualityChecked = 0;
    _portraitChecked = 0;
    for (final exposures in _exposures.values) {
      exposures.clear();
    }
  }

  LivenessSignals get signals {
    final unlit = _averageExposure(_exposures[LightPhase.unlit]!);
    final lit = _averageExposure(_exposures[LightPhase.lit]!);
    final response = _unlit.isEmpty || _lit.isEmpty ? null : _flashResponse(_unlit, _lit);
    return LivenessSignals(
      frames: _preview.length,
      motion: _preview.length < _minFrames ? null : _motion(_preview),
      colourShift: _preview.length < _minFrames ? null : _colourShift(_preview),
      checks: (received: _received, quality: _qualityChecked, portrait: _portraitChecked),
      flashFrames: (_unlit.length, _lit.length),
      flashResponse: response == null ? null : response * _exposureChange(unlit, lit),
      flashGlare: _unlit.isEmpty || _lit.isEmpty ? null : _glareShare(_lit) - _glareShare(_unlit),
      flashColour: _unlit.isEmpty || _lit.isEmpty ? null : _flashColour(_unlit, _lit),
      exposures: (unlit: unlit, lit: lit),
    );
  }
}

class LivenessSignals {
  const LivenessSignals({
    required this.frames,
    required this.motion,
    required this.colourShift,
    required this.checks,
    required this.flashFrames,
    required this.flashResponse,
    required this.flashGlare,
    required this.flashColour,
    required this.exposures,
  });

  /// Preview frames kept, the last [_maxPreviewFrames].
  final int frames;

  /// The average brightness change of a cell between frames: whether the
  /// document moved at all, without which [colourShift] says nothing.
  final double? motion;

  /// How far the cells that changed colour most moved in colour (Cb/Cr),
  /// after the camera's white balance is taken out: a hologram tilting.
  final double? colourShift;

  /// Frames the camera delivered (every one fingerprinted), and how many the
  /// quality and portrait checks got to.
  final ({int received, int quality, int portrait}) checks;

  /// Frames before and with the torch on.
  final (int, int) flashFrames;

  /// How much brighter the document got with the torch on, at the exposure
  /// before it: a document reflects the light, a screen hardly does.
  final double? flashResponse;

  /// How much more of the document the torch's reflection turned nearly
  /// white: the glare that's seen on a document more than on a screen.
  final double? flashGlare;

  /// The torch neither made the document glare nor brighten: a screen, not a
  /// document. Null when the torch test didn't run.
  /// How far the cells that changed colour most moved in colour (Cb/Cr)
  /// when the torch went on, the white balance taken out: a hologram lit up.
  final double? flashColour;

  /// Average exposure time (ms) and ISO before and with the torch on; equal
  /// when the exposure lock held.
  final ({_Exposure? unlit, _Exposure? lit}) exposures;

  bool? get screenLike {
    final glare = flashGlare;
    final response = flashResponse;
    if (glare == null || response == null) return null;
    return glare < _minDocumentGlare && response < _minDocumentResponse;
  }

  @override
  String toString() {
    String format(double? value, int digits) => value?.toStringAsFixed(digits) ?? '-';
    return [
      'received=${checks.received} qualityChecked=${checks.quality} portraitChecked=${checks.portrait}',
      'frames=$frames',
      'motion=${format(motion, 2)}',
      'colourShift=${format(colourShift, 2)}',
      'flashFrames=${flashFrames.$1}/${flashFrames.$2}',
      'flashResponse=${format(flashResponse, 3)}',
      'flashGlare=${format(flashGlare, 3)}',
      'flashColour=${format(flashColour, 2)}',
      'exposure=${_formatExposure(exposures.unlit)}->${_formatExposure(exposures.lit)}',
    ].join(' ');
  }
}

typedef _Exposure = ({double milliseconds, double iso});

_Exposure? _averageExposure(List<(int, double)> exposures) {
  if (exposures.isEmpty) return null;
  var time = 0;
  var iso = 0.0;
  for (final (t, i) in exposures) {
    time += t;
    iso += i;
  }
  return (milliseconds: time / exposures.length / 1e6, iso: iso / exposures.length);
}

/// How much less light the camera let in with the torch on: iOS's exposure
/// lock (one auto exposure, then locked) can still turn the exposure down
/// for the torch, hiding how much brighter the document got.
double _exposureChange(_Exposure? unlit, _Exposure? lit) {
  if (unlit == null || lit == null) return 1;
  final before = unlit.milliseconds * unlit.iso;
  final after = lit.milliseconds * lit.iso;
  return before > 0 && after > 0 ? before / after : 1;
}

String _formatExposure(_Exposure? exposure) =>
    exposure == null ? '-' : '${exposure.milliseconds.toStringAsFixed(2)}ms/ISO${exposure.iso.round()}';

double _flashColour(List<FrameSignature> unlit, List<FrameSignature> lit) {
  final before = _averageSignature(unlit);
  final after = _averageSignature(lit);
  final usable = [for (var c = 0; c < before.luma.length; c++) _usable(before.luma[c]) && _usable(after.luma[c])];
  // The torch's colour shifts every cell alike through the white balance.
  final beforeCb = _balanced(before.cb, before.luma);
  final beforeCr = _balanced(before.cr, before.luma);
  final afterCb = _balanced(after.cb, after.luma);
  final afterCr = _balanced(after.cr, after.luma);
  final changes = [
    for (var c = 0; c < usable.length; c++)
      if (usable[c]) math.sqrt(math.pow(afterCb[c] - beforeCb[c], 2) + math.pow(afterCr[c] - beforeCr[c], 2)),
  ]..sort((a, b) => b.compareTo(a));
  if (changes.isEmpty) return 0;
  final top = changes.take(_shiftCells);
  return top.reduce((a, b) => a + b) / top.length;
}

FrameSignature _averageSignature(List<FrameSignature> frames) {
  final cells = frames.first.luma.length;
  final luma = Float32List(cells);
  final cb = Float32List(cells);
  final cr = Float32List(cells);
  for (final frame in frames) {
    for (var c = 0; c < cells; c++) {
      luma[c] += frame.luma[c] / frames.length;
      cb[c] += frame.cb[c] / frames.length;
      cr[c] += frame.cr[c] / frames.length;
    }
  }
  return FrameSignature(luma: luma, cb: cb, cr: cr);
}

double _glareShare(List<FrameSignature> frames) {
  var glaring = 0;
  for (final frame in frames) {
    glaring += frame.luma.where((brightness) => brightness > _maxCellBrightness).length;
  }
  return glaring / (frames.length * frames.first.luma.length);
}

bool _usable(double brightness) => brightness >= _minCellBrightness && brightness <= _maxCellBrightness;

double _motion(List<FrameSignature> frames) {
  var total = 0.0;
  for (var f = 1; f < frames.length; f++) {
    var change = 0.0;
    for (var c = 0; c < frames[f].luma.length; c++) {
      change += (frames[f].luma[c] - frames[f - 1].luma[c]).abs();
    }
    total += change / frames[f].luma.length;
  }
  return total / (frames.length - 1);
}

double _colourShift(List<FrameSignature> frames) {
  final cells = frames.first.luma.length;
  // The camera's white balance shifts every cell alike.
  final balanced = [for (final frame in frames) (_balanced(frame.cb, frame.luma), _balanced(frame.cr, frame.luma))];
  final shifts = <double>[];
  for (var c = 0; c < cells; c++) {
    if (!frames.every((frame) => _usable(frame.luma[c]))) continue;
    var meanCb = 0.0;
    var meanCr = 0.0;
    for (final (cb, cr) in balanced) {
      meanCb += cb[c];
      meanCr += cr[c];
    }
    meanCb /= frames.length;
    meanCr /= frames.length;
    var furthest = 0.0;
    for (final (cb, cr) in balanced) {
      furthest = math.max(furthest, math.sqrt(math.pow(cb[c] - meanCb, 2) + math.pow(cr[c] - meanCr, 2)));
    }
    shifts.add(furthest);
  }
  if (shifts.isEmpty) return 0;
  shifts.sort((a, b) => b.compareTo(a));
  final top = shifts.take(_shiftCells);
  return top.reduce((a, b) => a + b) / top.length;
}

Float32List _balanced(Float32List chroma, Float32List luma) {
  final usable = [
    for (var c = 0; c < chroma.length; c++)
      if (_usable(luma[c])) chroma[c],
  ]..sort();
  final median = usable.isEmpty ? 128.0 : usable[usable.length ~/ 2];
  return Float32List.fromList([for (final value in chroma) value - median]);
}

double _flashResponse(List<FrameSignature> unlit, List<FrameSignature> lit) {
  Float32List average(List<FrameSignature> frames) {
    final sum = Float32List(frames.first.luma.length);
    for (final frame in frames) {
      for (var c = 0; c < sum.length; c++) {
        sum[c] += frame.luma[c] / frames.length;
      }
    }
    return sum;
  }

  final before = average(unlit);
  final after = average(lit);
  final ratios = [
    // The torch's own reflection clips: those cells say nothing.
    for (var c = 0; c < before.length; c++)
      if (before[c] >= _minCellBrightness && after[c] <= _maxCellBrightness) after[c] / before[c],
  ]..sort();
  return ratios.isEmpty ? 0 : ratios[ratios.length ~/ 2];
}
