import 'dart:math' as math;
import 'dart:typed_data';

// None of these were measured on a device yet: collect the signals of real
// documents and screens before letting them decide anything.

const signatureColumns = 16;
const signatureRows = 10;

const _maxPreviewFrames = 90;

/// More than a torch test takes: it waits for a few frames in each light.
const _maxTorchFrames = 30;
const _minFrames = 3;

/// Cells this dark or this bright say nothing about colour.
const _minCellBrightness = 25;
const _maxCellBrightness = 235;

const _shiftCells = 3;

/// The last preview frames [_flicker] compares: enough for its median, few
/// enough to compare when the picture is taken.
const _flickerFrames = 30;

/// Frequencies [_bandPeak] looks among, in stripes over the document: from a
/// few broad ones to stripes a few samples apart.
const _minStripes = 3;
const _stripeSamples = 4;

/// [_bandPeak] takes out changes broader than this share of the document.
const _bandSmoothing = 16;

/// On a Galaxy, with the torch on, a real Dutch ID card's glare grew 0.22 to
/// 0.43 and its brightness 1.11 to 1.23 times; a Dutch passport's photo page,
/// less glossy, glared only 0.07 to 0.10 but still brightened 1.04 times.
/// The same documents on a phone screen glared 0.02 to 0.09 and brightened
/// 0.84 to 1.08 times. One phone, one room, four photos each.
const minDocumentGlare = 0.15;
const minDocumentResponse = 1.0;

/// The document in one preview frame: its brightness and colour (YCbCr) in
/// [signatureColumns] x [signatureRows] cells, row by row.
class FrameSignature {
  const FrameSignature({required this.luma, required this.cb, required this.cr, this.bands});

  final Float32List luma;
  final Float32List cb;
  final Float32List cr;
  final SensorBands? bands;
}

/// The document's brightness along the sensor's rows and along its columns.
typedef SensorBands = ({Float32List rows, Float32List columns});

/// The document in grey, row by row.
typedef DocumentView = ({Uint8List pixels, int width, int height});

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

  /// The last frame before the torch went on and the first with it: the
  /// closest together, so the document moved least between them.
  DocumentView? _unlitView;
  DocumentView? _litView;

  /// Whether a frame in [phase] still needs its [view].
  bool needsView(LightPhase phase) => switch (phase) {
    LightPhase.unlit => true,
    LightPhase.lit => _litView == null,
    LightPhase.preview => false,
  };

  void view(DocumentView view, LightPhase phase) {
    switch (phase) {
      case LightPhase.unlit:
        _unlitView = view;
      case LightPhase.lit:
        _litView ??= view;
      case LightPhase.preview:
        break;
    }
  }

  void add(FrameSignature signature, LightPhase phase) {
    switch (phase) {
      case LightPhase.preview:
        _preview.add(signature);
        if (_preview.length > _maxPreviewFrames) _preview.removeAt(0);
      case LightPhase.unlit:
        // The last ones, the closest to the torch going on.
        _unlit.add(signature);
        if (_unlit.length > _maxTorchFrames) _unlit.removeAt(0);
      case LightPhase.lit:
        if (_lit.length < _maxTorchFrames) _lit.add(signature);
    }
  }

  void reset() {
    _preview.clear();
    _unlit.clear();
    _lit.clear();
    _unlitView = null;
    _litView = null;
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
    final brightening = _unlit.isEmpty || _lit.isEmpty ? null : _flashResponse(_unlit, _lit);
    final exposure = brightening == null ? null : _exposureChange(unlit, lit);
    final unlitView = _unlitView;
    final litView = _litView;
    final views = unlitView == null || litView == null || unlitView.pixels.length != litView.pixels.length
        ? null
        : (unlit: unlitView, lit: litView);
    return LivenessSignals(
      frames: _preview.length,
      motion: _preview.length < _minFrames ? null : _motion(_preview),
      colourShift: _preview.length < _minFrames ? null : _colourShift(_preview),
      checks: (received: _received, quality: _qualityChecked, portrait: _portraitChecked),
      flashFrames: (_unlit.length, _lit.length),
      flashBrightening: brightening,
      flashExposure: exposure,
      flashResponse: brightening == null || exposure == null ? null : brightening * exposure,
      flashGlare: _unlit.isEmpty || _lit.isEmpty ? null : _glareShare(_lit) - _glareShare(_unlit),
      flashColour: _unlit.isEmpty || _lit.isEmpty ? null : _flashColour(_unlit, _lit),
      flicker: _flicker([_preview.sublist(math.max(0, _preview.length - _flickerFrames)), _unlit, _lit]),
      torchTracking: views == null ? null : _torchTracking(views.unlit, views.lit, _exposureChange(unlit, lit)),
      glareEdge: views == null ? null : _glareEdge(views.unlit, views.lit),
      inkLevel: unlitView == null ? null : _inkLevel(unlitView),
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
    required this.flashBrightening,
    required this.flashExposure,
    required this.flashResponse,
    required this.flashGlare,
    required this.flashColour,
    required this.flicker,
    required this.torchTracking,
    required this.glareEdge,
    required this.inkLevel,
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

  /// How much brighter the document got in the frames with the torch on.
  final double? flashBrightening;

  /// How much less light the camera let in with the torch on: 1 when the
  /// exposure lock held.
  final double? flashExposure;

  /// [flashBrightening] times [flashExposure]: how much brighter the document
  /// got at the exposure before the torch. A document reflects the light, a
  /// screen hardly does.
  final double? flashResponse;

  /// How much more of the document the torch's reflection turned nearly
  /// white: the glare that's seen on a document more than on a screen.
  final double? flashGlare;

  /// The torch neither made the document glare nor brighten: a screen, not a
  /// document. Null when the torch test didn't run.
  /// How far the cells that changed colour most moved in colour (Cb/Cr)
  /// when the torch went on, the white balance taken out: a hologram lit up.
  final double? flashColour;

  /// How strongly the change between consecutive frames repeats in stripes
  /// across the sensor, against the rest of the change: a screen that dims
  /// by flickering (PWM) shows moving stripes, paper and plastic don't.
  /// Null with too few frames.
  final double? flicker;

  /// How much more the torch brightened the document's light parts than its
  /// dark ones, per part of the document: about the torch's share of the
  /// light on paper, whose print reflects it; about 0 on a screen, whose
  /// picture gives off its own light and whose glass reflects the torch as
  /// much over dark parts as over light ones.
  final double? torchTracking;

  /// How far the brightness falls just outside where the torch's reflection
  /// clipped: steep off a screen's mirror-like glass, gentle off laminate.
  /// Null when the torch clipped nowhere.
  final double? glareEdge;

  /// The document's darkest parts against its paper, without the torch: ink
  /// is darker than a screen's black.
  final double? inkLevel;

  /// Average exposure time (ms) and ISO before and with the torch on; equal
  /// when the exposure lock held.
  final ({_Exposure? unlit, _Exposure? lit}) exposures;

  bool? get screenLike {
    final glare = flashGlare;
    final response = flashResponse;
    if (glare == null || response == null) return null;
    return glare < minDocumentGlare && response < minDocumentResponse;
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
      'flashBrightening=${format(flashBrightening, 3)}',
      'flashExposure=${format(flashExposure, 3)}',
      'flashGlare=${format(flashGlare, 3)}',
      'flashColour=${format(flashColour, 2)}',
      'flicker=${format(flicker, 1)}',
      'torchTracking=${format(torchTracking, 3)}',
      'glareEdge=${format(glareEdge, 0)}',
      'inkLevel=${format(inkLevel, 3)}',
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

/// The median over consecutive frames of each phase of [_bandPeak], along
/// the rows or the columns, whichever is stronger.
double? _flicker(List<List<FrameSignature>> phases) {
  final peaks = <double>[];
  for (final frames in phases) {
    for (var f = 1; f < frames.length; f++) {
      final before = frames[f - 1].bands;
      final after = frames[f].bands;
      if (before == null || after == null) continue;
      peaks.add(math.max(_bandPeak(before.rows, after.rows), _bandPeak(before.columns, after.columns)));
    }
  }
  if (peaks.length < _minFrames) return null;
  peaks.sort();
  return peaks[peaks.length ~/ 2];
}

/// One period of a cosine and a sine in n samples, by n.
final _waves = <int, (Float64List, Float64List)>{};

/// The strongest frequency of the change from [before] to [after], against
/// the median one: about 7 for noise. The change is taken as a ratio, so the
/// document's own print, the same in both, drops out.
double _bandPeak(Float32List before, Float32List after) {
  final n = math.min(before.length, after.length);
  final highest = n ~/ _stripeSamples;
  if (highest <= _minStripes) return 0;
  final change = Float64List(n);
  for (var i = 0; i < n; i++) {
    change[i] = before[i] > 0 && after[i] > 0 ? math.log(after[i] / before[i]) : 0;
  }
  // The hand moving and the exposure settling change the document broadly.
  final reach = math.max(1, n ~/ _bandSmoothing ~/ 2);
  final detail = Float64List(n);
  for (var i = 0; i < n; i++) {
    final from = math.max(0, i - reach);
    final to = math.min(n, i + reach + 1);
    var sum = 0.0;
    for (var j = from; j < to; j++) {
      sum += change[j];
    }
    detail[i] = change[i] - sum / (to - from);
  }

  final (cos, sin) = _waves.putIfAbsent(n, () {
    final cos = Float64List(n);
    final sin = Float64List(n);
    for (var i = 0; i < n; i++) {
      cos[i] = math.cos(2 * math.pi * i / n);
      sin[i] = math.sin(2 * math.pi * i / n);
    }
    return (cos, sin);
  });
  final powers = <double>[];
  for (var k = _minStripes; k <= highest; k++) {
    var re = 0.0;
    var im = 0.0;
    for (var i = 0; i < n; i++) {
      final phase = k * i % n;
      re += detail[i] * cos[phase];
      im -= detail[i] * sin[phase];
    }
    powers.add(re * re + im * im);
  }
  final peak = powers.reduce(math.max);
  powers.sort();
  final median = powers[powers.length ~/ 2];
  return median == 0 ? 0 : peak / median;
}

/// [liveness]'s signals, for [compute]: they take a while to work out.
LivenessSignals livenessSignals(DocumentLiveness liveness) => liveness.signals;

const _trackingColumns = 6;
const _trackingRows = 4;
const _minTrackingPixels = 50;

/// Below this spread of brightness a part of the document is too plain to
/// tell the print's share of the torch's light from the glass's.
const _minTrackingSpread = 12;

/// The median over parts of the document of the slope of the torch's gain
/// against the brightness before it: within a part the torch lights alike,
/// so the slope is how the print shared out its light. [exposure] undoes
/// the camera letting in less light once the torch went on.
double? _torchTracking(DocumentView unlit, DocumentView lit, double exposure) {
  final (dx, dy) = _shift(unlit, lit);
  final slopes = <double>[];
  for (var row = 0; row < _trackingRows; row++) {
    for (var column = 0; column < _trackingColumns; column++) {
      var count = 0;
      var sumU = 0.0;
      var sumD = 0.0;
      var sumUU = 0.0;
      var sumUD = 0.0;
      for (var y = unlit.height * row ~/ _trackingRows; y < unlit.height * (row + 1) ~/ _trackingRows; y++) {
        for (
          var x = unlit.width * column ~/ _trackingColumns;
          x < unlit.width * (column + 1) ~/ _trackingColumns;
          x++
        ) {
          final litX = x + dx;
          final litY = y + dy;
          if (litX < 0 || litY < 0 || litX >= lit.width || litY >= lit.height) continue;
          final before = unlit.pixels[y * unlit.width + x];
          final after = lit.pixels[litY * lit.width + litX];
          if (!_usable(before.toDouble()) || after >= _clipped) continue;
          final gain = after * exposure - before;
          count++;
          sumU += before;
          sumD += gain;
          sumUU += before * before;
          sumUD += before * gain;
        }
      }
      if (count < _minTrackingPixels) continue;
      final variance = sumUU / count - (sumU / count) * (sumU / count);
      if (variance < _minTrackingSpread * _minTrackingSpread) continue;
      slopes.add((sumUD / count - sumU / count * sumD / count) / variance);
    }
  }
  if (slopes.isEmpty) return null;
  slopes.sort();
  return slopes[slopes.length ~/ 2];
}

/// Pixels the document may have moved between the frames [_shift] compares.
const _maxShift = 4;

/// Where [lit]'s pixels lie against [unlit]'s: the hand holding the phone
/// moves it a little between the frames. The shift whose pixels correlate
/// best, which the torch's gain and the glass's reflection don't change.
(int, int) _shift(DocumentView unlit, DocumentView lit) {
  var best = (0, 0);
  var bestCorrelation = double.negativeInfinity;
  for (var dy = -_maxShift; dy <= _maxShift; dy++) {
    for (var dx = -_maxShift; dx <= _maxShift; dx++) {
      var n = 0;
      var sumA = 0.0;
      var sumB = 0.0;
      var sumAA = 0.0;
      var sumBB = 0.0;
      var sumAB = 0.0;
      // Every other pixel is enough to line them up.
      for (var y = _maxShift; y < unlit.height - _maxShift; y += 2) {
        for (var x = _maxShift; x < unlit.width - _maxShift; x += 2) {
          final a = unlit.pixels[y * unlit.width + x].toDouble();
          final b = lit.pixels[(y + dy) * lit.width + x + dx].toDouble();
          n++;
          sumA += a;
          sumB += b;
          sumAA += a * a;
          sumBB += b * b;
          sumAB += a * b;
        }
      }
      if (n == 0) return best;
      final varianceA = sumAA / n - (sumA / n) * (sumA / n);
      final varianceB = sumBB / n - (sumB / n) * (sumB / n);
      if (varianceA <= 0 || varianceB <= 0) continue;
      final correlation = (sumAB / n - sumA / n * sumB / n) / math.sqrt(varianceA * varianceB);
      if (correlation > bestCorrelation) {
        bestCorrelation = correlation;
        best = (dx, dy);
      }
    }
  }
  return best;
}

const _clipped = 250;
const _minGlarePixels = 20;

/// Pixels outside a clipped one [_glareEdge] looks at.
const _glareReach = 3;

/// The median fall in brightness [_glareReach] pixels out from the edge of
/// where the torch made the document clip and it hadn't before.
double? _glareEdge(DocumentView unlit, DocumentView lit) {
  final w = lit.width;
  final h = lit.height;
  bool torchClipped(int x, int y) => lit.pixels[y * w + x] >= _clipped && unlit.pixels[y * w + x] < _clipped;
  if (lit.pixels.indexed.where((p) => p.$2 >= _clipped && unlit.pixels[p.$1] < _clipped).length < _minGlarePixels) {
    return null;
  }

  final falls = <int>[];
  for (var y = _glareReach; y < h - _glareReach; y++) {
    for (var x = _glareReach; x < w - _glareReach; x++) {
      if (!torchClipped(x, y)) continue;
      for (final (dx, dy) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
        if (torchClipped(x + dx, y + dy)) continue;
        falls.add(_clipped - lit.pixels[(y + dy * _glareReach) * w + x + dx * _glareReach]);
      }
    }
  }
  if (falls.isEmpty) return null;
  falls.sort();
  return falls[falls.length ~/ 2].toDouble();
}

const _inkPercentile = 0.02;
const _paperPercentile = 0.9;

double? _inkLevel(DocumentView view) {
  final sorted = [...view.pixels]..sort();
  if (sorted.isEmpty) return null;
  final paper = sorted[((sorted.length - 1) * _paperPercentile).round()];
  return paper == 0 ? null : sorted[((sorted.length - 1) * _inkPercentile).round()] / paper;
}
