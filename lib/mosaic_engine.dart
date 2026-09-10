import 'dart:typed_data';
import 'dart:ui' as ui;

/// Handles turning a decoded [ui.Image] into an NxN grid of averaged flat
/// colors, matching the behavior of the original web version:
///  - the image is center-cropped to a square based on its shorter side
///  - `zoom` > 1 crops tighter (zooming in); `zoom` < 1 reveals more of the
///    frame than the image actually has, so the extra area is padded with
///    [padColor] (a simple letterbox) rather than distorting anything
///  - each of the N x N cells' color is the average of the pixels inside it
class MosaicEngine {
  MosaicEngine._();

  /// Number of cells per side. Fixed at 27 to match the original design.
  static const int gridSize = 27;

  /// Side length of one "ninth" (the 3×3 grouping of 9×9 blocks).
  static const int ninthSize = 9;

  /// Returns up to [count] dominant colors in [cellColors], ranked by how
  /// many cells fall into each quantized bucket. Bucket averages are used
  /// so the swatches match the mosaic rather than the coarse quantizer.
  ///
  /// Background is excluded: near-white flats, plus the most common color
  /// along the mosaic perimeter (typical photo backdrop / letterbox).
  static List<ui.Color> dominantColors(
    List<List<ui.Color>> cellColors, {
    int count = 3,
    int quantizeStep = 24,
  }) {
    final n = cellColors.length;
    if (n == 0) return const [];

    final bgKey = _perimeterBackgroundKey(cellColors, quantizeStep);
    (int r, int g, int b)? bgAvg;
    if (bgKey != null) {
      bgAvg = _bucketAverage(
        cellColors,
        quantizeStep: quantizeStep,
        onlyKey: bgKey,
        perimeterOnly: true,
      );
    }

    final buckets = <int, (int r, int g, int b, int n)>{};
    for (final row in cellColors) {
      for (final c in row) {
        final r = (c.r * 255.0).round() & 0xFF;
        final g = (c.g * 255.0).round() & 0xFF;
        final b = (c.b * 255.0).round() & 0xFF;
        if (_isNearWhite(r, g, b)) continue;
        if (bgAvg != null && _nearRgb(r, g, b, bgAvg.$1, bgAvg.$2, bgAvg.$3)) {
          continue;
        }
        final key = _quantizeKey(r, g, b, quantizeStep);
        if (bgKey != null && key == bgKey) continue;
        final prev = buckets[key];
        if (prev == null) {
          buckets[key] = (r, g, b, 1);
        } else {
          buckets[key] = (prev.$1 + r, prev.$2 + g, prev.$3 + b, prev.$4 + 1);
        }
      }
    }

    final ranked = buckets.values.toList()
      ..sort((a, b) => b.$4.compareTo(a.$4));

    return ranked
        .map((e) => ui.Color.fromARGB(255, e.$1 ~/ e.$4, e.$2 ~/ e.$4, e.$3 ~/ e.$4))
        .where((c) {
          final r = (c.r * 255.0).round() & 0xFF;
          final g = (c.g * 255.0).round() & 0xFF;
          final b = (c.b * 255.0).round() & 0xFF;
          if (_isNearWhite(r, g, b)) return false;
          if (bgAvg != null && _nearRgb(r, g, b, bgAvg.$1, bgAvg.$2, bgAvg.$3)) {
            return false;
          }
          return true;
        })
        .take(count)
        .toList();
  }

  static int _quantizeKey(int r, int g, int b, int step) {
    final qr = (r ~/ step) * step;
    final qg = (g ~/ step) * step;
    final qb = (b ~/ step) * step;
    return (qr << 16) | (qg << 8) | qb;
  }

  /// Most common quantized color on the outer ring of cells — usually the
  /// photo backdrop or zoom pad.
  static int? _perimeterBackgroundKey(
    List<List<ui.Color>> cellColors,
    int quantizeStep,
  ) {
    final n = cellColors.length;
    if (n == 0) return null;

    final counts = <int, int>{};
    void tally(ui.Color c) {
      final r = (c.r * 255.0).round() & 0xFF;
      final g = (c.g * 255.0).round() & 0xFF;
      final b = (c.b * 255.0).round() & 0xFF;
      final key = _quantizeKey(r, g, b, quantizeStep);
      counts[key] = (counts[key] ?? 0) + 1;
    }

    for (var x = 0; x < n; x++) {
      tally(cellColors[0][x]);
      if (n > 1) tally(cellColors[n - 1][x]);
    }
    for (var y = 1; y < n - 1; y++) {
      tally(cellColors[y][0]);
      tally(cellColors[y][n - 1]);
    }

    if (counts.isEmpty) return null;
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  static (int r, int g, int b)? _bucketAverage(
    List<List<ui.Color>> cellColors, {
    required int quantizeStep,
    required int onlyKey,
    bool perimeterOnly = false,
  }) {
    final n = cellColors.length;
    var sr = 0, sg = 0, sb = 0, count = 0;

    void consider(ui.Color c) {
      final r = (c.r * 255.0).round() & 0xFF;
      final g = (c.g * 255.0).round() & 0xFF;
      final b = (c.b * 255.0).round() & 0xFF;
      if (_quantizeKey(r, g, b, quantizeStep) != onlyKey) return;
      sr += r;
      sg += g;
      sb += b;
      count++;
    }

    if (perimeterOnly) {
      for (var x = 0; x < n; x++) {
        consider(cellColors[0][x]);
        if (n > 1) consider(cellColors[n - 1][x]);
      }
      for (var y = 1; y < n - 1; y++) {
        consider(cellColors[y][0]);
        consider(cellColors[y][n - 1]);
      }
    } else {
      for (final row in cellColors) {
        for (final c in row) {
          consider(c);
        }
      }
    }

    if (count == 0) return null;
    return (sr ~/ count, sg ~/ count, sb ~/ count);
  }

  /// True when [r,g,b] is close enough to [br,bg,bb] to treat as the same
  /// backdrop (covers slight gradients / compression noise).
  static bool _nearRgb(int r, int g, int b, int br, int bg, int bb, {int maxDist = 42}) {
    final dr = r - br;
    final dg = g - bg;
    final db = b - bb;
    return dr * dr + dg * dg + db * db <= maxDist * maxDist;
  }

  /// True for white / off-white (high value, low chroma) — typically background.
  static bool _isNearWhite(int r, int g, int b) {
    final minC = r < g ? (r < b ? r : b) : (g < b ? g : b);
    final maxC = r > g ? (r > b ? r : b) : (g > b ? g : b);
    return maxC >= 230 && (maxC - minC) <= 45;
  }

  /// Internal sampling resolution before averaging. 270 keeps an exact
  /// 10px-per-cell ratio (270 / 27 = 10), avoiding fractional cell bounds.
  static const int sampleSize = 270;

  static Future<List<List<ui.Color>>> computeCellColors({
    required ui.Image image,
    required double zoom,
    required ui.Color padColor,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(
      recorder,
      ui.Rect.fromLTWH(0, 0, sampleSize.toDouble(), sampleSize.toDouble()),
    );

    // Pad background first, in case zooming out reveals area beyond the
    // image's native bounds.
    final padPaint = ui.Paint()..color = padColor;
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, sampleSize.toDouble(), sampleSize.toDouble()),
      padPaint,
    );

    final imgW = image.width.toDouble();
    final imgH = image.height.toDouble();
    final baseSide = imgW < imgH ? imgW : imgH;
    final cropSide = baseSide / zoom;
    final sx = (imgW - cropSide) / 2;
    final sy = (imgH - cropSide) / 2;
    final paint = ui.Paint()..filterQuality = ui.FilterQuality.medium;

    if (zoom >= 1) {
      // Straightforward tighter crop, fully within the image bounds.
      canvas.drawImageRect(
        image,
        ui.Rect.fromLTWH(sx, sy, cropSide, cropSide),
        ui.Rect.fromLTWH(0, 0, sampleSize.toDouble(), sampleSize.toDouble()),
        paint,
      );
    } else {
      // Draw the whole image centered within the larger virtual crop
      // square; anything outside the image's own bounds stays padded.
      final scale = sampleSize / cropSide;
      final drawW = imgW * scale;
      final drawH = imgH * scale;
      final drawX = (sampleSize - drawW) / 2;
      final drawY = (sampleSize - drawH) / 2;
      canvas.drawImageRect(
        image,
        ui.Rect.fromLTWH(0, 0, imgW, imgH),
        ui.Rect.fromLTWH(drawX, drawY, drawW, drawH),
        paint,
      );
    }

    final picture = recorder.endRecording();
    final sampled = await picture.toImage(sampleSize, sampleSize);
    final byteData = await sampled.toByteData(format: ui.ImageByteFormat.rawRgba);
    sampled.dispose();
    if (byteData == null) {
      throw StateError('Failed to read pixel data for mosaic sampling.');
    }
    final pixels = byteData.buffer.asUint8List();

    const cell = sampleSize / gridSize; // exactly 10.0

    final result = List.generate(gridSize, (_) => List<ui.Color>.filled(gridSize, const ui.Color(0xFF000000)));

    for (var gy = 0; gy < gridSize; gy++) {
      for (var gx = 0; gx < gridSize; gx++) {
        int r = 0, g = 0, b = 0, count = 0;
        final x0 = (gx * cell).floor();
        final x1 = ((gx + 1) * cell).floor();
        final y0 = (gy * cell).floor();
        final y1 = ((gy + 1) * cell).floor();
        for (var y = y0; y < y1; y++) {
          for (var x = x0; x < x1; x++) {
            final idx = (y * sampleSize + x) * 4;
            r += pixels[idx];
            g += pixels[idx + 1];
            b += pixels[idx + 2];
            count++;
          }
        }
        result[gy][gx] = ui.Color.fromARGB(255, r ~/ count, g ~/ count, b ~/ count);
      }
    }
    return result;
  }

  /// Renders the given cell-color grid to PNG bytes at [cellPixelSize] px
  /// per cell, with the same regular + bold-every-9 grid lines used
  /// on-screen. Used for the share/export action.
  static Future<Uint8List> renderToPng({
    required List<List<ui.Color>> cellColors,
    required bool showLines,
    double cellPixelSize = 30,
  }) async {
    final total = gridSize * cellPixelSize;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder, ui.Rect.fromLTWH(0, 0, total, total));

    for (var gy = 0; gy < gridSize; gy++) {
      for (var gx = 0; gx < gridSize; gx++) {
        final paint = ui.Paint()..color = cellColors[gy][gx];
        final x0 = (gx * cellPixelSize).roundToDouble();
        final x1 = ((gx + 1) * cellPixelSize).roundToDouble();
        final y0 = (gy * cellPixelSize).roundToDouble();
        final y1 = ((gy + 1) * cellPixelSize).roundToDouble();
        canvas.drawRect(ui.Rect.fromLTRB(x0, y0, x1, y1), paint);
      }
    }

    if (showLines) {
      final thin = ui.Paint()
        ..color = const ui.Color(0x52000000)
        ..strokeWidth = 1.5;
      final bold = ui.Paint()
        ..color = const ui.Color(0x8C000000)
        ..strokeWidth = 3.5;
      for (var i = 0; i <= gridSize; i++) {
        final p = (i * cellPixelSize).roundToDouble();
        final paint = (i % 9 == 0) ? bold : thin;
        canvas.drawLine(ui.Offset(p, 0), ui.Offset(p, total), paint);
        canvas.drawLine(ui.Offset(0, p), ui.Offset(total, p), paint);
      }
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(total.round(), total.round());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (byteData == null) {
      throw StateError('Failed to encode mosaic PNG.');
    }
    return byteData.buffer.asUint8List();
  }
}
